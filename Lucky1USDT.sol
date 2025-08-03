// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Lucky1USDT is VRFConsumerBase, Ownable {
    // Token and DeFi interfaces
    IERC20 public usdt; // USDT token contract
    IERC20 public odc; // ODC token contract
    IUniswapV2Router02 public quickSwapRouter; // QuickSwap Router
    AggregatorV3Interface public priceFeed; // Chainlink Price Feed

    // Draw state
    address public targetToken; // Target cryptocurrency (e.g., SOL, ETH, BNB)
    string public targetSymbol; // Symbol of target cryptocurrency (e.g., "SOL")
    uint256 public totalShares; // Total shares for current draw
    uint256 public sharesSold; // Shares sold
    uint256 public constant SHARE_PRICE = 1e6; // 1 USDT (6 decimals)
    uint256 public constant FEE_PERCENTAGE = 5; // 5% platform fee
    address[] public participants; // List of participants
    mapping(address => uint256) public userShares; // Shares per user
    bool public drawActive; // Draw status
    address public winner; // Draw winner

    // Chainlink VRF
    bytes32 internal keyHash;
    uint256 internal vrfFee;
    uint256 public randomResult;

    // Events
    event DrawStarted(address targetToken, string targetSymbol, uint256 totalShares);
    event SharePurchased(address user, uint256 shares);
    event DrawEnded(address winner, uint256 amount);
    event ODCdistributed(address user, uint256 odcAmount);
    event Swapped(address token, uint256 usdtAmount, uint256 tokenAmount);

    constructor(
        address _usdt,
        address _odc,
        address _quickSwapRouter,
        address _priceFeed,
        address _vrfCoordinator,
        address _link,
        bytes32 _keyHash,
        uint256 _vrfFee
    ) VRFConsumerBase(_vrfCoordinator, _link) Ownable(msg.sender) {
        usdt = IERC20(_usdt);
        odc = IERC20(_odc);
        quickSwapRouter = IUniswapV2Router02(_quickSwapRouter);
        priceFeed = AggregatorV3Interface(_priceFeed);
        keyHash = _keyHash;
        vrfFee = _vrfFee;
        drawActive = false;
    }

    // Start a new draw for a mainstream cryptocurrency
    function startDraw(address _targetToken, string memory _targetSymbol, address _priceFeed) external onlyOwner {
        require(!drawActive, "Draw already active");
        targetToken = _targetToken;
        targetSymbol = _targetSymbol;
        priceFeed = AggregatorV3Interface(_priceFeed);
        (, int256 price,,,) = priceFeed.latestRoundData();
        require(price > 1e8, "Token price must be > 1 USDT"); // 1 USDT = 1e8 (8 decimals for price feed)
        totalShares = uint256(price) / 1e8; // Calculate shares (1 USDT = 1 share)
        sharesSold = 0;
        participants = new address[](0);
        drawActive = true;
        winner = address(0);
        emit DrawStarted(_targetToken, _targetSymbol, totalShares);
    }

    // Purchase shares with USDT
    function purchaseShares(uint256 _shares) external {
        require(drawActive, "No active draw");
        require(_shares > 0, "Must purchase at least 1 share");
        require(sharesSold + _shares <= totalShares, "Exceeds available shares");
        uint256 usdtAmount = _shares * SHARE_PRICE;
        require(usdt.transferFrom(msg.sender, address(this), usdtAmount), "USDT transfer failed");
        userShares[msg.sender] += _shares;
        sharesSold += _shares;
        participants.push(msg.sender);
        emit SharePurchased(msg.sender, _shares);
        if (sharesSold == totalShares) {
            requestRandomness(keyHash, vrfFee);
        }
    }

    // Chainlink VRF callback
    function fulfillRandomness(bytes32, uint256 randomness) internal override {
        randomResult = randomness;
        selectWinner();
    }

    // Select winner using VRF result
    function selectWinner() internal {
        require(drawActive, "No active draw");
        require(sharesSold == totalShares, "Draw not complete");
        uint256 winnerIndex = randomResult % participants.length;
        winner = participants[winnerIndex];
        distributePrize();
    }

    // Distribute prize and ODC
    function distributePrize() internal {
        drawActive = false;
        uint256 totalUsdt = totalShares * SHARE_PRICE;
        uint256 fee = (totalUsdt * FEE_PERCENTAGE) / 100;
        uint256 prizeUsdt = totalUsdt - fee;
        usdt.transfer(owner(), fee);

        // Swap USDT to target cryptocurrency via QuickSwap
        usdt.approve(address(quickSwapRouter), prizeUsdt);
        address[] memory path = new address[](2);
        path[0] = address(usdt);
        path[1] = targetToken;
        uint256[] memory amounts = quickSwapRouter.swapExactTokensForTokens(
            prizeUsdt,
            0,
            path,
            winner,
            block.timestamp + 300
        );
        emit Swapped(targetToken, prizeUsdt, amounts[1]);

        // Distribute ODC to non-winners
        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i] != winner) {
                uint256 odcAmount = userShares[participants[i]] * 1e18; // 1 USDT = 1 ODC (18 decimals)
                odc.transfer(participants[i], odcAmount);
                emit ODCdistributed(participants[i], odcAmount);
            }
            userShares[participants[i]] = 0;
        }
        emit DrawEnded(winner, amounts[1]);
    }

    // Get current draw status
    function getDrawStatus() external view returns (
        address _targetToken,
        string memory _targetSymbol,
        uint256 _totalShares,
        uint256 _sharesSold,
        bool _drawActive,
        address _winner
    ) {
        return (targetToken, targetSymbol, totalShares, sharesSold, drawActive, winner);
    }

    // Emergency stop
    function emergencyStop() external onlyOwner {
        drawActive = false;
    }

    // Withdraw LINK (for VRF)
    function withdrawLink() external onlyOwner {
        IERC20(link).transfer(owner(), IERC20(link).balanceOf(address(this)));
    }
}