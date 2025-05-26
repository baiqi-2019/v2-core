pragma solidity =0.5.16;

import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IERC20.sol";
import "./libraries/UniswapV2Library.sol";

/**
 * @title UniswapV2Router
 * @dev Uniswap V2的路由合约，提供添加/移除流动性和交易功能
 * 这是一个简化版的Router，完整版还包括更多功能
 */
contract UniswapV2Router {
    address public factory;
    
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
        _;
    }

    constructor(address _factory) public {
        factory = _factory;
    }
    
    /**
     * @dev 添加流动性到交易对
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @param amountADesired 期望添加的tokenA数量
     * @param amountBDesired 期望添加的tokenB数量
     * @param amountAMin 最小接受的tokenA数量
     * @param amountBMin 最小接受的tokenB数量
     * @param to 接收流动性代币的地址
     * @param deadline 交易截止时间
     * @return amountA 实际添加的tokenA数量
     * @return amountB 实际添加的tokenB数量
     * @return liquidity 获得的流动性代币数量
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        // 创建交易对（如果不存在）
        address pair = IUniswapV2Factory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            pair = IUniswapV2Factory(factory).createPair(tokenA, tokenB);
        }
        
        // 获取当前储备量
        (uint reserveA, uint reserveB) = UniswapV2Library.getReserves(factory, tokenA, tokenB);
        
        // 计算最优添加数量
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = UniswapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = UniswapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
        
        // 将代币转入交易对合约
        _safeTransferFrom(tokenA, msg.sender, pair, amountA);
        _safeTransferFrom(tokenB, msg.sender, pair, amountB);
        
        // 添加流动性
        liquidity = IUniswapV2Pair(pair).mint(to);
    }
    
    /**
     * @dev 移除流动性
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @param liquidity 要移除的流动性代币数量
     * @param amountAMin 最小接受的tokenA数量
     * @param amountBMin 最小接受的tokenB数量
     * @param to 接收底层代币的地址
     * @param deadline 交易截止时间
     * @return amountA 获得的tokenA数量
     * @return amountB 获得的tokenB数量
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint amountA, uint amountB) {
        // 获取交易对地址
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        
        // 将流动性代币转给交易对合约
        IERC20(pair).transferFrom(msg.sender, pair, liquidity);
        
        // 移除流动性
        (amountA, amountB) = IUniswapV2Pair(pair).burn(to);
        
        // 确保获得的代币数量不低于最小要求
        (address token0,) = UniswapV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amountA, amountB) : (amountB, amountA);
        require(amountA >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
    }
    
    /**
     * @dev 执行代币交换
     * @param amountIn 输入代币数量
     * @param amountOutMin 最小接受的输出代币数量
     * @param path 交易路径，如[tokenA, tokenB]
     * @param to 接收输出代币的地址
     * @param deadline 交易截止时间
     * @return amounts 每一步交易的数量
     */
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        // 计算每一步交易的数量
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        
        // 将输入代币转给第一个交易对
        _safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        
        // 执行交换
        _swap(amounts, path, to);
    }
    
    /**
     * @dev 内部函数，执行交换逻辑
     * @param amounts 每一步交易的数量
     * @param path 交易路径
     * @param _to 最终接收代币的地址
     */
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    
    /**
     * @dev 安全转账，确保转账成功
     * @param token 代币地址
     * @param from 发送方地址
     * @param to 接收方地址
     * @param value 转账金额
     */
    function _safeTransferFrom(address token, address from, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(
            bytes4(keccak256(bytes('transferFrom(address,address,uint256)'))), from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV2Router: TRANSFER_FROM_FAILED');
    }
} 