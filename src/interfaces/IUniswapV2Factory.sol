pragma solidity =0.5.16;

/**
 * @title IUniswapV2Factory
 * @dev Uniswap V2工厂合约的接口定义
 * 声明了创建和管理交易对的方法
 */
interface IUniswapV2Factory {
    /**
     * @dev 创建交易对事件，当新的交易对被创建时触发
     * @param token0 排序后的第一个代币地址
     * @param token1 排序后的第二个代币地址
     * @param pair 创建的交易对地址
     * @param length 当前所有交易对的数量
     */
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    /**
     * @dev 获取协议费用接收地址
     * @return 当前费用接收地址，如果为零地址表示不收取协议费
     */
    function feeTo() external view returns (address);
    
    /**
     * @dev 获取费用设置者地址
     * @return 有权设置feeTo地址的账户
     */
    function feeToSetter() external view returns (address);

    /**
     * @dev 根据两个代币地址获取对应的交易对地址
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return 对应的交易对地址，如不存在则返回零地址
     */
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    
    /**
     * @dev 获取指定索引的交易对地址
     * @param index 索引值
     * @return 对应索引的交易对地址
     */
    function allPairs(uint) external view returns (address pair);
    
    /**
     * @dev 获取所有交易对的数量
     * @return 交易对总数
     */
    function allPairsLength() external view returns (uint);

    /**
     * @dev 创建一个新的交易对
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return pair 新创建的交易对地址
     */
    function createPair(address tokenA, address tokenB) external returns (address pair);

    /**
     * @dev 设置协议费用接收地址
     * @param _feeTo 新的费用接收地址
     */
    function setFeeTo(address _feeTo) external;
    
    /**
     * @dev 设置费用设置者地址
     * @param _feeToSetter 新的费用设置者地址
     */
    function setFeeToSetter(address _feeToSetter) external;
} 