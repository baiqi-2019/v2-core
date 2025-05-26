pragma solidity =0.5.16;

/**
 * @title Math
 * @dev 提供数学运算函数
 * 目前只包含求平方根和最小值的函数
 */
library Math {
    /**
     * @dev 返回两个数中的较小值
     * @param x 第一个数
     * @param y 第二个数
     * @return z 较小值
     */
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    /**
     * @dev 计算一个数的平方根（巴比伦法）
     * 这是使用巴比伦迭代法的平方根计算实现
     * 结果向下取整到最接近的整数
     * @param y 要计算平方根的数
     * @return z 计算结果
     */
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            // 初始猜测值
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
} 