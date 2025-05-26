# Uniswap V2 核心原理与源码分析

## 一、Uniswap V2 概述

Uniswap V2是一个去中心化交易协议，基于自动做市商(AMM)模型，运行在以太坊区块链上。它允许用户在没有中心化交易所的情况下直接交换ERC20代币。与中心化交易所使用订单簿不同，Uniswap使用了一个被称为"恒定乘积做市商"的数学公式来维持市场的流动性和价格发现。

### 主要特点与改进

Uniswap V2相比V1的主要改进包括：

1. **支持任意ERC20对ERC20交易**：V1仅支持ETH与ERC20之间的交易，V2支持任意两种ERC20代币间的直接交易
2. **价格预言机**：内建TWAP(时间加权平均价格)预言机功能
3. **闪电贷(Flash Swap)**：允许在单个交易中借用任意数量的代币，只要在交易结束时返还或支付手续费
4. **协议费用机制**：可选的协议费用，可以开启以支持协议的可持续发展
5. **技术优化**：更多的gas优化和安全性改进

## 二、核心合约解析

### 1. UniswapV2Factory

工厂合约是Uniswap V2的核心，负责创建和管理所有交易对：

```solidity
contract UniswapV2Factory {
    address public feeTo;           // 协议费用接收地址
    address public feeToSetter;     // 有权设置feeTo的地址
    
    // 存储所有交易对的映射和数组
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
}
```

核心功能：

- **createPair**：使用CREATE2创建新的交易对合约，确保地址确定性
- **setFeeTo**：设置协议费用接收地址
- **setFeeToSetter**：设置新的费用设置者

特别之处是使用CREATE2操作码，它允许预先计算合约地址，无需部署就能确定交易对地址。

### 2. UniswapV2Pair

交易对合约实现了AMM逻辑和代币交换功能：

```solidity
contract UniswapV2Pair {
    uint112 private reserve0;           // 代币0的储备量
    uint112 private reserve1;           // 代币1的储备量
    uint32  private blockTimestampLast; // 最后更新时间
    
    uint public price0CumulativeLast;   // 累计价格，用于TWAP
    uint public price1CumulativeLast;
    uint public kLast;                  // 上次reserve0*reserve1的值
}
```

核心功能：

- **mint**：添加流动性，铸造LP代币
- **burn**：移除流动性，销毁LP代币
- **swap**：交换代币
- **_update**：更新储备量和价格累加器
- **_mintFee**：计算并铸造协议费用

#### 恒定乘积公式

Uniswap V2的核心是恒定乘积公式：`x * y = k`，其中x和y是两种代币的储备量，k是常数。交易发生时，产品k必须保持不变（考虑手续费后）。

在swap函数中，有一个关键检查：

```solidity
uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
require(balance0Adjusted.mul(balance1Adjusted) >= uint(reserve0).mul(reserve1).mul(1000**2));
```

这确保了交易后考虑0.3%手续费的k值不会减少。

#### 价格累加器和TWAP

价格累加器用于实现时间加权平均价格（TWAP）预言机：

```solidity
price0CumulativeLast += uint(UQ112x112.encode(reserve1).uqdiv(reserve0)) * timeElapsed;
price1CumulativeLast += uint(UQ112x112.encode(reserve0).uqdiv(reserve1)) * timeElapsed;
```

外部合约可以通过比较两个时间点的累加器差值，计算这段时间内的平均价格，提供抗操纵的价格参考。

### 3. UniswapV2ERC20

实现LP代币的ERC20标准接口，额外提供EIP-2612的permit功能，允许用户通过签名授权而不是交易授权token：

```solidity
function permit(
    address owner, address spender, uint value, uint deadline, 
    uint8 v, bytes32 r, bytes32 s
) external {
    // 通过签名授权
}
```

## 三、协议费用机制

Uniswap V2引入了可选的协议费用机制。当开启时，每笔交易的1/6手续费（即总费用的0.05%）会分配给feeTo地址：

```solidity
function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
    address feeTo = IUniswapV2Factory(factory).feeTo();
    feeOn = feeTo != address(0);
    if (feeOn) {
        if (_kLast != 0) {
            uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
            uint rootKLast = Math.sqrt(_kLast);
            if (rootK > rootKLast) {
                uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                uint denominator = rootK.mul(5).add(rootKLast);
                uint liquidity = numerator / denominator;
                if (liquidity > 0) _mint(feeTo, liquidity);
            }
        }
    } else if (_kLast != 0) {
        kLast = 0;
    }
}
```

这个公式设计非常巧妙，能确保精确收取手续费的1/6，同时避免扰乱交易对的正常运行。

## 四、周边合约设计

### 1. UniswapV2Router

路由合约提供了用户友好的接口，处理添加/移除流动性和代币交换：

```solidity
function swapExactTokensForTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
) external returns (uint[] memory amounts)
```

路由合约不存储资金，只是促进资金在不同合约间的流动。

### 2. UniswapV2Library

提供与核心合约交互的纯函数：

```solidity
function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
    // 使用CREATE2计算交易对地址
}

function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
    // 计算交易输出量
}
```

特别是`pairFor`函数，它通过相同的CREATE2逻辑计算交易对地址，避免了额外的链上调用，节省gas。

## 五、技术创新与优化

### 1. CREATE2和确定性地址

使用CREATE2操作码生成确定性合约地址，可以在不部署的情况下预测合约地址：

```solidity
bytes32 salt = keccak256(abi.encodePacked(token0, token1));
pair = address(uint(keccak256(abi.encodePacked(
    hex'ff',
    factory,
    salt,
    keccak256(type(UniswapV2Pair).creationCode)
))));
```

这使得周边合约可以在不查询工厂合约的情况下直接计算交易对地址。

### 2. 单一存储槽优化

Uniswap V2巧妙地将三个变量打包在一个存储槽中：

```solidity
uint112 private reserve0;
uint112 private reserve1;
uint32  private blockTimestampLast;
```

这不仅节省了存储空间和gas，还允许原子地读取所有三个值，避免跨区块读取的不一致性。

### 3. UQ112x112固定点数学

为了高精度价格计算，Uniswap V2实现了自定义的Q112.112固定点数学库：

```solidity
library UQ112x112 {
    uint224 constant Q112 = 2**112;
    
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112;
    }
    
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}
```

这允许在没有浮点数的Solidity中进行高精度计算。

## 六、安全设计

### 1. 重入保护

所有修改状态的函数都使用lock修饰符防止重入攻击：

```solidity
uint private unlocked = 1;
modifier lock() {
    require(unlocked == 1, 'UniswapV2: LOCKED');
    unlocked = 0;
    _;
    unlocked = 1;
}
```

### 2. 先交付后检查模式

在swap函数中，Uniswap V2先转出代币，然后检查最终状态是否有效：

```solidity
// 先转账
if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(...);

// 后检查
require(balance0Adjusted.mul(balance1Adjusted) >= uint(reserve0).mul(reserve1).mul(1000**2));
```

这种模式支持了闪电贷功能，同时确保最终状态始终是安全的。

## 七、总结

Uniswap V2是去中心化金融(DeFi)领域的一个重要里程碑，它的设计精简而高效，代码质量极高。其核心创新包括：

1. **恒定乘积公式**：简单而强大的AMM模型
2. **价格预言机**：提供抗操纵的价格数据源
3. **闪电贷**：开创性的无抵押借贷功能
4. **协议费用**：可持续发展的经济模型
5. **技术优化**：高效的存储布局和地址计算

Uniswap V2的设计理念和技术创新极大地推动了去中心化交易所的发展，影响了整个DeFi生态系统，为后续的众多AMM项目提供了基础和灵感。 