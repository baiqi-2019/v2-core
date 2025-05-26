pragma solidity =0.5.16;

import "../../interfaces/IUniswapV2Pair.sol";

/**
 * @title UniswapV2Library
 * @dev 提供与Uniswap V2交互的辅助函数
 * 主要用于周边合约，用于计算交易对地址、计算最优交易路径等
 */
library UniswapV2Library {
    /**
     * @dev 按照地址大小排序两个代币
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return token0 排序后的第一个代币地址
     * @return token1 排序后的第二个代币地址
     */
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    /**
     * @dev 计算交易对的CREATE2地址，无需进行任何外部调用
     * @param factory 工厂合约地址
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return pair 交易对合约地址
     */
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        // 使用Uniswap V2官方提供的init_code_hash值
        // 根据不同网络可能需要调整此值
        // 主网值：0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f
        bytes32 init_code_hash = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                init_code_hash
            ))));
    }

    /**
     * @dev 获取交易对的储备量
     * @param factory 工厂合约地址
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return reserveA tokenA的储备量
     * @return reserveB tokenB的储备量
     */
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /**
     * @dev 计算添加流动性时需要的代币B数量
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @param amountADesired 期望添加的tokenA数量
     * @param amountBDesired 期望添加的tokenB数量
     * @param reserveA tokenA的储备量
     * @param reserveB tokenB的储备量
     * @return amountA 实际需要的tokenA数量
     * @return amountB 实际需要的tokenB数量
     */
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA * reserveB / reserveA;
    }

    /**
     * @dev 计算交易的输出量
     * @param amountIn 输入代币数量
     * @param reserveIn 输入代币的储备量
     * @param reserveOut 输出代币的储备量
     * @return amountOut 计算得到的输出代币数量
     */
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /**
     * @dev 计算交易的输入量
     * @param amountOut 期望输出代币数量
     * @param reserveIn 输入代币的储备量
     * @param reserveOut 输出代币的储备量
     * @return amountIn 需要的输入代币数量
     */
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn * amountOut * 1000;
        uint denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }
} 