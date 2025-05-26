pragma solidity =0.5.16;

import './interfaces/IUniswapV2Pair.sol';
import './UniswapV2ERC20.sol';
import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './interfaces/IERC20.sol';
import './interfaces/IUniswapV2Factory.sol';
import './interfaces/IUniswapV2Callee.sol';

/**
 * @title UniswapV2Pair
 * @dev Uniswap V2交易对合约，实现了自动做市商(AMM)功能
 * 该合约管理两种ERC20代币之间的交易对，提供流动性添加/移除，交易和价格预言机功能
 */
contract UniswapV2Pair is IUniswapV2Pair, UniswapV2ERC20 {
    using SafeMath  for uint;
    using UQ112x112 for uint224;

    // 最小流动性数量，永久锁定在合约中，防止第一个流动性提供者操纵价格
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    // ERC20 transfer方法的函数选择器
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    // 工厂合约地址
    address public factory;
    // 交易对中的第一个代币地址
    address public token0;
    // 交易对中的第二个代币地址
    address public token1;

    // 以下三个变量共享同一个存储槽以节省gas
    // token0的储备量
    uint112 private reserve0;
    // token1的储备量
    uint112 private reserve1;
    // 最后一次更新的区块时间戳
    uint32  private blockTimestampLast;

    // token0的累计价格，用于时间加权平均价格(TWAP)计算
    uint public price0CumulativeLast;
    // token1的累计价格，用于时间加权平均价格(TWAP)计算
    uint public price1CumulativeLast;
    // 上次流动性事件后的reserve0 * reserve1值，用于计算协议费用
    uint public kLast;

    // 重入锁
    uint private unlocked = 1;
    // 防止重入攻击的修饰符
    modifier lock() {
        require(unlocked == 1, 'UniswapV2: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    /**
     * @dev 获取当前交易对的储备量和最后更新时间戳
     * @return _reserve0 token0的储备量
     * @return _reserve1 token1的储备量
     * @return _blockTimestampLast 最后一次更新的区块时间戳
     */
    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * @dev 安全转账函数，确保转账成功
     * @param token 代币地址
     * @param to 接收地址
     * @param value 转账金额
     */
    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV2: TRANSFER_FAILED');
    }

    // 事件定义
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    /**
     * @dev 构造函数，将工厂合约设置为部署者
     */
    constructor() public {
        factory = msg.sender;
    }

    /**
     * @dev 初始化交易对，只能由工厂合约调用一次
     * @param _token0 第一个代币地址
     * @param _token1 第二个代币地址
     */
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN'); // 充分的检查
        token0 = _token0;
        token1 = _token1;
    }

    /**
     * @dev 更新储备量和价格累计器
     * @param balance0 token0的当前余额
     * @param balance1 token1的当前余额
     * @param _reserve0 token0的旧储备量
     * @param _reserve1 token1的旧储备量
     */
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        // 确保余额不会溢出uint112
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'UniswapV2: OVERFLOW');
        // 获取当前区块时间戳，截断为32位
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        // 计算时间流逝，溢出是期望的行为
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        // 如果时间已流逝且储备量不为零，更新价格累计器
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // 更新token0的累计价格: price0 = reserve1/reserve0
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            // 更新token1的累计价格: price1 = reserve0/reserve1
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        // 更新储备量
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    /**
     * @dev 如果协议费用开启，铸造等价于K值增长1/6的流动性代币作为费用
     * @param _reserve0 token0的旧储备量
     * @param _reserve1 token1的旧储备量
     * @return feeOn 是否收取协议费用
     */
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        // 从工厂合约获取费用接收地址
        address feeTo = IUniswapV2Factory(factory).feeTo();
        // 如果feeTo不为零地址，则开启费用收取
        feeOn = feeTo != address(0);
        // 保存上次K值以节省gas
        uint _kLast = kLast;
        // 如果费用开启
        if (feeOn) {
            if (_kLast != 0) {
                // 计算当前K值的平方根: √(reserve0 * reserve1)
                uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
                // 计算上次K值的平方根
                uint rootKLast = Math.sqrt(_kLast);
                // 如果K值增长了（意味着收取了交易费用）
                if (rootK > rootKLast) {
                    // 计算应铸造的流动性代币数量: totalSupply * (rootK - rootKLast) / (rootK * 5 + rootKLast)
                    // 这大约等于交易费用的1/6
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(5).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    // 如果流动性大于0，铸造给费用接收者
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            // 如果费用关闭但kLast不为0，将kLast重置为0
            kLast = 0;
        }
    }

    /**
     * @dev 添加流动性，铸造流动性代币
     * 这是一个低级函数，应该从执行重要安全检查的合约调用
     * @param to 接收流动性代币的地址
     * @return liquidity 铸造的流动性代币数量
     */
    function mint(address to) external lock returns (uint liquidity) {
        // 获取当前储备量，节省gas
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        // 获取当前合约中的代币余额
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        // 计算存入的代币数量
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        // 检查并可能收取协议费用
        bool feeOn = _mintFee(_reserve0, _reserve1);
        // 保存总供应量以节省gas，必须在这里定义，因为_mintFee可能更新totalSupply
        uint _totalSupply = totalSupply;
        // 如果是首次添加流动性
        if (_totalSupply == 0) {
            // 流动性 = √(amount0 * amount1) - MINIMUM_LIQUIDITY
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            // 永久锁定最小流动性
           _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            // 否则，流动性 = min(amount0 * _totalSupply / _reserve0, amount1 * _totalSupply / _reserve1)
            // 确保按比例添加流动性
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        // 确保铸造的流动性大于0
        require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
        // 铸造流动性代币给接收者
        _mint(to, liquidity);

        // 更新储备量
        _update(balance0, balance1, _reserve0, _reserve1);
        // 如果费用开启，更新kLast
        if (feeOn) kLast = uint(reserve0).mul(reserve1);
        emit Mint(msg.sender, amount0, amount1);
    }

    /**
     * @dev 移除流动性，销毁流动性代币
     * 这是一个低级函数，应该从执行重要安全检查的合约调用
     * @param to 接收底层代币的地址
     * @return amount0 返回的token0数量
     * @return amount1 返回的token1数量
     */
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        // 获取当前储备量，节省gas
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        // 保存token地址以节省gas
        address _token0 = token0;
        address _token1 = token1;
        // 获取当前合约中的代币余额
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        // 获取要销毁的流动性代币数量
        uint liquidity = balanceOf[address(this)];

        // 检查并可能收取协议费用
        bool feeOn = _mintFee(_reserve0, _reserve1);
        // 保存总供应量以节省gas，必须在这里定义，因为_mintFee可能更新totalSupply
        uint _totalSupply = totalSupply;
        // 按比例计算返回的代币数量：liquidity / totalSupply * balance
        amount0 = liquidity.mul(balance0) / _totalSupply;
        amount1 = liquidity.mul(balance1) / _totalSupply;
        // 确保返回的代币数量大于0
        require(amount0 > 0 && amount1 > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED');
        // 销毁流动性代币
        _burn(address(this), liquidity);
        // 将代币转给接收者
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        // 更新当前余额
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        // 更新储备量
        _update(balance0, balance1, _reserve0, _reserve1);
        // 如果费用开启，更新kLast
        if (feeOn) kLast = uint(reserve0).mul(reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /**
     * @dev 交换代币
     * 这是一个低级函数，应该从执行重要安全检查的合约调用
     * @param amount0Out 输出的token0数量
     * @param amount1Out 输出的token1数量
     * @param to 接收代币的地址
     * @param data 回调数据
     */
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        // 确保至少有一个输出量大于0
        require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        // 获取当前储备量
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        // 确保输出量小于储备量
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        { // 作用域避免堆栈太深错误
        address _token0 = token0;
        address _token1 = token1;
        // 确保接收地址不是代币地址，防止攻击
        require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');
        // 乐观地转账代币（先转后检查）
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
        // 如果有回调数据，调用接收者的uniswapV2Call函数
        if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        // 获取交易后的余额
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        }
        // 计算输入量
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        // 确保有输入
        require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
        { // 作用域避免堆栈太深错误
        // 计算调整后的余额，考虑0.3%的手续费
        uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
        uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
        // 确保K值不减少，交易必须遵循恒定乘积公式: (x' - 0.003*dx)(y' - 0.003*dy) >= x*y
        require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), 'UniswapV2: K');
        }

        // 更新储备量
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /**
     * @dev 将余额与储备量的差额转出
     * 用于处理向合约直接发送代币的情况
     * @param to 接收多余代币的地址
     */
    function skim(address to) external lock {
        address _token0 = token0; // 节省gas
        address _token1 = token1; // 节省gas
        // 将多余的代币转给接收者
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    /**
     * @dev 强制使储备量与余额匹配
     * 用于同步储备量和实际余额
     */
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
} 