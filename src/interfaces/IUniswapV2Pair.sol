pragma solidity =0.5.16;

/**
 * @title IUniswapV2Pair
 * @dev Uniswap V2交易对合约的接口定义
 * 声明了交易对的功能，包括流动性管理、交易和价格获取
 */
interface IUniswapV2Pair {
    /**
     * @dev 当流动性提供者添加流动性时触发
     * @param sender 调用者地址
     * @param amount0 添加的token0数量
     * @param amount1 添加的token1数量
     */
    event Mint(address indexed sender, uint amount0, uint amount1);
    
    /**
     * @dev 当流动性提供者移除流动性时触发
     * @param sender 调用者地址
     * @param amount0 移除的token0数量
     * @param amount1 移除的token1数量
     * @param to 接收代币的地址
     */
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    
    /**
     * @dev 当交易发生时触发
     * @param sender 调用者地址
     * @param amount0In 输入的token0数量
     * @param amount1In 输入的token1数量
     * @param amount0Out 输出的token0数量
     * @param amount1Out 输出的token1数量
     * @param to 接收代币的地址
     */
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    
    /**
     * @dev 当储备量更新时触发
     * @param reserve0 更新后的token0储备量
     * @param reserve1 更新后的token1储备量
     */
    event Sync(uint112 reserve0, uint112 reserve1);

    /**
     * @dev 获取工厂合约地址
     * @return 工厂合约地址
     */
    function factory() external view returns (address);
    
    /**
     * @dev 获取排序后的第一个代币地址
     * @return token0地址
     */
    function token0() external view returns (address);
    
    /**
     * @dev 获取排序后的第二个代币地址
     * @return token1地址
     */
    function token1() external view returns (address);
    
    /**
     * @dev 获取当前储备量和时间戳
     * @return reserve0 token0的储备量
     * @return reserve1 token1的储备量
     * @return blockTimestampLast 最后更新的区块时间戳
     */
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    
    /**
     * @dev 获取token0的累计价格
     * @return token0的累计价格，用于TWAP计算
     */
    function price0CumulativeLast() external view returns (uint);
    
    /**
     * @dev 获取token1的累计价格
     * @return token1的累计价格，用于TWAP计算
     */
    function price1CumulativeLast() external view returns (uint);
    
    /**
     * @dev 获取K值，即reserve0 * reserve1
     * @return 上次流动性事件后的K值
     */
    function kLast() external view returns (uint);

    /**
     * @dev 添加流动性
     * @param to 接收流动性代币的地址
     * @return liquidity 铸造的流动性代币数量
     */
    function mint(address to) external returns (uint liquidity);
    
    /**
     * @dev 移除流动性
     * @param to 接收底层代币的地址
     * @return amount0 返回的token0数量
     * @return amount1 返回的token1数量
     */
    function burn(address to) external returns (uint amount0, uint amount1);
    
    /**
     * @dev 交换代币
     * @param amount0Out 输出的token0数量
     * @param amount1Out 输出的token1数量
     * @param to 接收代币的地址
     * @param data 回调数据
     */
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    
    /**
     * @dev 将余额与储备量的差额转出
     * @param to 接收多余代币的地址
     */
    function skim(address to) external;
    
    /**
     * @dev 强制使储备量与余额匹配
     */
    function sync() external;

    /**
     * @dev 初始化交易对
     * @param token0 第一个代币地址
     * @param token1 第二个代币地址
     */
    function initialize(address token0, address token1) external;
} 