pragma solidity =0.5.16;

/**
 * @title SafeMath
 * @dev 提供安全的数学运算，防止溢出
 * 这个库为Solidity中的算术操作添加了溢出检查
 */
library SafeMath {
    /**
     * @dev 返回两个无符号整数的加法结果，如果溢出则回滚
     * @param x 第一个加数
     * @param y 第二个加数
     * @return z 加法结果
     */
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'SafeMath: addition overflow');
    }

    /**
     * @dev 返回两个无符号整数的减法结果，如果下溢则回滚
     * @param x 被减数
     * @param y 减数
     * @return z 减法结果
     */
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'SafeMath: subtraction underflow');
    }

    /**
     * @dev 返回两个无符号整数的乘法结果，如果溢出则回滚
     * @param x 第一个乘数
     * @param y 第二个乘数
     * @return z 乘法结果
     */
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'SafeMath: multiplication overflow');
    }
} 