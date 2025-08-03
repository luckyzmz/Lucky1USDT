// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ODCToken is ERC20, Ownable {
    constructor() ERC20("OneDollarCrypto Token", "ODC") Ownable(msg.sender) {
        _mint(msg.sender, 100_000_000 * 10**18); // 100M total supply, 18 decimals
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

contract OneDollarCrypto {
    IERC20 public usdt;
    ODCToken public odc;
    address public winner;
    uint256 public totalShares;
    uint256 public sharePrice = 1 * 10**6; // 1 USDT (6 decimals)
    mapping(address => uint256) public shares;
    address[] public participants;

    constructor(address _usdt, address _odc) {
        usdt = IERC20(_usdt);
        odc = ODCToken(_odc);
    }

    function buyShare(uint256 _amount) external {
        require(_amount * sharePrice <= usdt.balanceOf(msg.sender), "Insufficient USDT");
        usdt.transferFrom(msg.sender, address(this), _amount * sharePrice);
        if (shares[msg.sender] == 0) {
            participants.push(msg.sender);
        }
        shares[msg.sender] += _amount;
        totalShares += _amount;
    }

    function distributeODC(address winner) external {
        require(totalShares > 0, "No shares sold");
        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i] != winner) {
                uint256 odcAmount = shares[participants[i]] * 10**18; // 1 USDT = 1 ODC
                odc.mint(participants[i], odcAmount);
            }
        }
    }
}