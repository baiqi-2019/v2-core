pragma solidity =0.5.16;

/**
 * @title IERC20
 * @dev ERC20代币标准接口
 * 参考: https://eips.ethereum.org/EIPS/eip-20
 */
interface IERC20 {
    /**
     * @dev 当代币从一个地址转移到另一个地址时触发
     * @param from 发送方地址
     * @param to 接收方地址
     * @param value 转账的代币数量
     */
    event Transfer(address indexed from, address indexed to, uint value);
    
    /**
     * @dev 当用户授权其他地址使用其代币时触发
     * @param owner 代币所有者地址
     * @param spender 被授权的地址
     * @param value 授权的代币数量
     */
    event Approval(address indexed owner, address indexed spender, uint value);

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
     * @dev 将调用者的代币转移给其他地址
     * @param to 接收方地址
     * @param value 转账的代币数量
     * @return 是否成功
     */
    function transfer(address to, uint value) external returns (bool);
    
    /**
     * @dev 授权spender使用调用者的代币
     * @param spender 被授权的地址
     * @param value 授权的代币数量
     * @return 是否成功
     */
    function approve(address spender, uint value) external returns (bool);
    
    /**
     * @dev 被授权地址代表所有者转账
     * @param from 代币所有者地址
     * @param to 接收方地址
     * @param value 转账的代币数量
     * @return 是否成功
     */
    function transferFrom(address from, address to, uint value) external returns (bool);
} 