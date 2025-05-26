pragma solidity =0.5.16;

/**
 * @title IUniswapV2ERC20
 * @dev Uniswap V2流动性代币的ERC20接口
 * 包含标准ERC20接口和扩展的permit功能
 */
interface IUniswapV2ERC20 {
    /**
     * @dev 当用户授权其他地址使用其代币时触发
     * @param owner 代币所有者地址
     * @param spender 被授权的地址
     * @param value 授权的代币数量
     */
    event Approval(address indexed owner, address indexed spender, uint value);
    
    /**
     * @dev 当代币从一个地址转移到另一个地址时触发
     * @param from 发送方地址
     * @param to 接收方地址
     * @param value 转账的代币数量
     */
    event Transfer(address indexed from, address indexed to, uint value);

    /**
     * @dev 获取代币名称
     * @return 代币名称
     */
    function name() external pure returns (string memory);
    
    /**
     * @dev 获取代币符号
     * @return 代币符号
     */
    function symbol() external pure returns (string memory);
    
    /**
     * @dev 获取代币小数位数
     * @return 代币小数位数
     */
    function decimals() external pure returns (uint8);
    
    /**
     * @dev 获取代币总供应量
     * @return 代币总供应量
     */
    function totalSupply() external view returns (uint);
    
    /**
     * @dev 获取指定地址的代币余额
     * @param owner 账户地址
     * @return 账户余额
     */
    function balanceOf(address owner) external view returns (uint);
    
    /**
     * @dev 获取授权额度
     * @param owner 代币所有者地址
     * @param spender 被授权的地址
     * @return 授权额度
     */
    function allowance(address owner, address spender) external view returns (uint);

    /**
     * @dev 授权spender使用调用者的代币
     * @param spender 被授权的地址
     * @param value 授权的代币数量
     * @return 是否成功
     */
    function approve(address spender, uint value) external returns (bool);
    
    /**
     * @dev 将调用者的代币转移给其他地址
     * @param to 接收方地址
     * @param value 转账的代币数量
     * @return 是否成功
     */
    function transfer(address to, uint value) external returns (bool);
    
    /**
     * @dev 被授权地址代表所有者转账
     * @param from 代币所有者地址
     * @param to 接收方地址
     * @param value 转账的代币数量
     * @return 是否成功
     */
    function transferFrom(address from, address to, uint value) external returns (bool);

    /**
     * @dev 获取域分隔符，用于EIP-712签名
     * @return 域分隔符
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    
    /**
     * @dev 获取permit函数的类型哈希
     * @return 类型哈希
     */
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    
    /**
     * @dev 获取账户的nonce值，用于防止重放攻击
     * @param owner 账户地址
     * @return nonce值
     */
    function nonces(address owner) external view returns (uint);

    /**
     * @dev 通过签名进行授权
     * @param owner 代币所有者
     * @param spender 被授权的地址
     * @param value 授权的代币数量
     * @param deadline 签名的有效期
     * @param v 签名的v值
     * @param r 签名的r值
     * @param s 签名的s值
     */
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
} 