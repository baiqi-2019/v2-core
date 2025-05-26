pragma solidity =0.5.16;

import './interfaces/IUniswapV2ERC20.sol';
import './libraries/SafeMath.sol';

/**
 * @title UniswapV2ERC20
 * @dev Uniswap V2流动性代币的ERC20实现
 * 该合约实现了标准ERC20接口，并添加了EIP-2612的permit功能
 * 用于表示Uniswap V2交易对中的流动性份额
 */
contract UniswapV2ERC20 is IUniswapV2ERC20 {
    using SafeMath for uint;

    // 代币名称
    string public constant name = 'Uniswap V2';
    // 代币符号
    string public constant symbol = 'UNI-V2';
    // 代币小数位数
    uint8 public constant decimals = 18;
    // 代币总供应量
    uint  public totalSupply;
    // 账户余额映射
    mapping(address => uint) public balanceOf;
    // 授权额度映射
    mapping(address => mapping(address => uint)) public allowance;

    // EIP-712域分隔符，用于签名验证
    bytes32 public DOMAIN_SEPARATOR;
    // EIP-2612 permit函数的类型哈希
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    // 账户nonce值映射，用于防止重放攻击
    mapping(address => uint) public nonces;

    // 事件定义
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    /**
     * @dev 构造函数，初始化EIP-712域分隔符
     */
    constructor() public {
        uint chainId;
        // 获取当前链ID
        assembly {
            chainId := chainid
        }
        // 计算域分隔符
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
    }

    /**
     * @dev 内部铸造函数，创建新代币并分配给指定地址
     * @param to 接收新代币的地址
     * @param value 铸造的代币数量
     */
    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    /**
     * @dev 内部销毁函数，从指定地址销毁代币
     * @param from 销毁代币的地址
     * @param value 销毁的代币数量
     */
    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    /**
     * @dev 内部授权函数，设置spender可以使用owner的代币额度
     * @param owner 代币所有者
     * @param spender 被授权的地址
     * @param value 授权的代币数量
     */
    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev 内部转账函数，将代币从一个地址转移到另一个地址
     * @param from 发送方地址
     * @param to 接收方地址
     * @param value 转账的代币数量
     */
    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    /**
     * @dev 外部授权函数，允许调用者授权其他地址使用自己的代币
     * @param spender 被授权的地址
     * @param value 授权的代币数量
     * @return 是否成功
     */
    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev 外部转账函数，允许调用者转账给其他地址
     * @param to 接收方地址
     * @param value 转账的代币数量
     * @return 是否成功
     */
    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev 外部授权转账函数，允许被授权地址代表所有者转账
     * @param from 代币所有者地址
     * @param to 接收方地址
     * @param value 转账的代币数量
     * @return 是否成功
     */
    function transferFrom(address from, address to, uint value) external returns (bool) {
        // 如果授权额度不是无限大，则减少授权额度
        if (allowance[from][msg.sender] != uint(-1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev 实现EIP-2612标准的permit函数，通过签名授权而不需要交易
     * @param owner 代币所有者
     * @param spender 被授权的地址
     * @param value 授权的代币数量
     * @param deadline 签名的有效期
     * @param v 签名的v值
     * @param r 签名的r值
     * @param s 签名的s值
     */
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        // 检查签名是否过期
        require(deadline >= block.timestamp, 'UniswapV2: EXPIRED');
        // 计算消息摘要
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        // 恢复签名者地址
        address recoveredAddress = ecrecover(digest, v, r, s);
        // 验证签名是否有效
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'UniswapV2: INVALID_SIGNATURE');
        // 执行授权
        _approve(owner, spender, value);
    }
} 