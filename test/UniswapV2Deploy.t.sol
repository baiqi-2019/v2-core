// SPDX-License-Identifier: MIT
pragma solidity =0.5.16;

import "forge-std/Test.sol";
import "../src/UniswapV2Factory.sol";
import "../src/UniswapV2Pair.sol";
import "../src/interfaces/IUniswapV2Pair.sol";

// 创建简单的ERC20代币用于测试
contract TestERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);

    constructor(string memory _name, string memory _symbol, uint _totalSupply) public {
        name = _name;
        symbol = _symbol;
        _mint(msg.sender, _totalSupply);
    }

    function _mint(address to, uint value) internal {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external returns (bool) {
        if (allowance[from][msg.sender] != uint(-1)) {
            allowance[from][msg.sender] -= value;
        }
        _transfer(from, to, value);
        return true;
    }
}

/**
 * @title UniswapV2DeployTest
 * @dev 测试Uniswap V2部署并计算init_code_hash
 */
contract UniswapV2DeployTest is Test {
    UniswapV2Factory public factory;
    address public feeTo;
    address public feeToSetter;
    TestERC20 public tokenA;
    TestERC20 public tokenB;
    
    function setUp() public {
        // 设置角色地址
        feeTo = address(0x1);
        feeToSetter = address(this);
        
        // 部署工厂合约
        factory = new UniswapV2Factory(feeToSetter);
        
        // 部署测试代币
        tokenA = new TestERC20("Token A", "TKNA", 1e24);
        tokenB = new TestERC20("Token B", "TKNB", 1e24);
    }
    
    function testInitCodeHash() public {
        // 计算创建交易对的初始代码哈希
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 initCodeHash = keccak256(bytecode);
        
        // 输出init_code_hash，用于周边合约库
        console.logBytes32(initCodeHash);
        
        // 创建一个交易对
        address pair = factory.createPair(address(tokenA), address(tokenB));
        
        // 验证交易对地址是否正确
        address token0 = tokenA < tokenB ? address(tokenA) : address(tokenB);
        address token1 = tokenA < tokenB ? address(tokenB) : address(tokenA);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        address computedAddress = address(uint(keccak256(abi.encodePacked(
            hex'ff',
            address(factory),
            salt,
            initCodeHash
        ))));
        
        assertEq(pair, computedAddress, "Pair address computation is incorrect");
        
        // 验证交易对合约存储的代币地址是否正确
        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);
        assertEq(pairContract.token0(), token0, "Token0 address incorrect");
        assertEq(pairContract.token1(), token1, "Token1 address incorrect");
        
        // 测试设置协议费用
        factory.setFeeTo(feeTo);
        assertEq(factory.feeTo(), feeTo, "feeTo address incorrect");
    }
} 