pragma solidity =0.5.16;

/**
 * @title UQ112x112
 * @dev 固定点Q112.112数学库
 * 用于高精度价格计算，使用224位表示一个数
 * 其中前112位是整数部分，后112位是小数部分
 */
library UQ112x112 {
    // Q112格式的1
    uint224 constant Q112 = 2**112;

    /**
     * @dev 将uint112编码为UQ112x112
     * @param y 要编码的uint112值
     * @return z 编码后的UQ112x112值
     */
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // 将y乘以2^112
    }

    /**
     * @dev UQ112x112除以uint112 -> UQ112x112
     * @param x 被除数，UQ112x112格式
     * @param y 除数，uint112格式
     * @return z 商，UQ112x112格式
     */
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
} 