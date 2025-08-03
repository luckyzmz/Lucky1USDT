代码说明

功能：

动态拆分份额：通过 Chainlink Price Feeds 获取目标币种（价格 > 1 USDT）的实时价格，计算份额（totalShares = floor(price / 1 USDT)）。
抽奖：用户支付 1 USDT 购买 1 份份额，记录在 userShares。抽奖结束时，使用 Chainlink VRF 随机选择赢家（fulfillRandomness）。
兑换与分发：通过 QuickSwap Router 将 USDT 兑换为目标币种，分发给赢家；非赢家获得 ODC（1 USDT = 1 ODC，18 decimals）。
费用：5% 平台费用，转移给合约拥有者。


依赖：

Chainlink：VRF（随机数，VRFConsumerBase）、Price Feeds（AggregatorV3Interface）。
QuickSwap：IUniswapV2Router02（Polygon 上 Uniswap V2 兼容）。
OpenZeppelin：IERC20（USDT、ODC）、Ownable（权限控制）。


安全：

仅限拥有者启动抽奖（onlyOwner）。
紧急停止（emergencyStop）。
LINK 代币可提取（withdrawLink）。


部署：

部署到 Polygon Mumbai 测试网（免费）或 Mainnet（Gas 费 ≈ 0.01 USDT）。
示例：
bashnpx hardhat run scripts/deploy.js --network mumbai

参数（需替换）：

_usdt：Polygon 上 USDT 合约地址。
_odc：ODC 代币合约地址。
_quickSwapRouter：Polygon QuickSwap Router 地址（0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff）。
_priceFeed：Chainlink Price Feed 地址（根据目标币种选择，如 ETH/USDT）。
_vrfCoordinator：Polygon VRF Coordinator（0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed）。
_link：Polygon LINK 地址（0x326C977E6efc84E512bB9C30f76E30c160eD06FB）。
_keyHash：VRF Key Hash（0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f）。
_vrfFee：VRF 费用（0.1 LINK）。
