pragma solidity =0.5.16;

import './interfaces/IUniswapV2Factory.sol';
import './UniswapV2Pair.sol';

/**
 * @title UniswapV2Factory
 * @dev Uniswap V2工厂合约，负责创建和管理交易对
 * 这是Uniswap V2协议的中心合约，用于部署新的交易对合约和管理协议费用
 */
contract UniswapV2Factory is IUniswapV2Factory {
    // 协议费用接收地址，如果为零地址则不收取协议费用
    address public feeTo;
    // 有权修改feeTo地址的账户
    address public feeToSetter;

    // 双重映射，用于存储代币对到交易对合约的映射关系: token0 => token1 => pairAddress
    mapping(address => mapping(address => address)) public getPair;
    // 存储所有已创建的交易对地址
    address[] public allPairs;

    // 交易对创建事件
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    /**
     * @dev 构造函数，设置费用设置者地址
     * @param _feeToSetter 有权设置协议费用接收地址的账户
     */
    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    /**
     * @dev 返回已创建的交易对总数
     * @return 交易对数量
     */
    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    /**
     * @dev 创建一个新的交易对
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     * @return pair 新创建的交易对合约地址
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // 确保两个代币地址不相同
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        // 按照地址大小排序代币，确保相同的代币对总是相同顺序
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        // 确保token0不是零地址
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        // 确保该交易对不存在
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // 单次检查就足够了
        // 获取交易对合约的创建字节码
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        // 使用token0和token1创建唯一的salt值
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        // 使用assembly和CREATE2创建交易对合约，保证地址确定性
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        // 初始化交易对
        IUniswapV2Pair(pair).initialize(token0, token1);
        // 双向存储交易对映射，便于查找
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // 同时填充反向映射
        // 将新交易对添加到数组中
        allPairs.push(pair);
        // 触发交易对创建事件
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /**
     * @dev 设置协议费用接收地址
     * @param _feeTo 新的费用接收地址，设为零地址表示不收取协议费用
     */
    function setFeeTo(address _feeTo) external {
        // 只有feeToSetter可以调用此函数
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    /**
     * @dev 设置新的费用设置者地址
     * @param _feeToSetter 新的费用设置者地址
     */
    function setFeeToSetter(address _feeToSetter) external {
        // 只有当前feeToSetter可以调用此函数
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
} 