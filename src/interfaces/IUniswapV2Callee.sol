pragma solidity =0.5.16;

/**
 * @title IUniswapV2Callee
 * @dev 回调接口，用于闪电贷(Flash Swap)功能
 * 实现此接口的合约可以在交易中接收回调
 */
interface IUniswapV2Callee {
    /**
     * @dev 当合约从Uniswap V2交易对接收代币时的回调函数
     * @param sender 初始调用swap函数的地址
     * @param amount0 接收的token0数量
     * @param amount1 接收的token1数量
     * @param data 附加数据
     */
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
} 