// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockUSDY is ERC20, Ownable {
    mapping(address => uint256) public lastFaucetTime;
    uint256 public constant FAUCET_AMOUNT = 10000 * 10**18; // 10k USDY
    uint256 public constant FAUCET_COOLDOWN = 24 hours;
    
    event FaucetUsed(address indexed user, uint256 amount);

    constructor() ERC20("Ondo US Dollar Yield", "USDY") Ownable(msg.sender) {
        // Initial liquidity for testing
        _mint(msg.sender, 10000000 * 10**decimals());
    }

    function decimals() public view virtual override returns (uint8) {
        return 18; // USDY uses 18 decimals
    }

    function faucet() external {
        require(block.timestamp >= lastFaucetTime[msg.sender] + FAUCET_COOLDOWN, "Cooldown active");
        lastFaucetTime[msg.sender] = block.timestamp;
        _mint(msg.sender, FAUCET_AMOUNT);
        emit FaucetUsed(msg.sender, FAUCET_AMOUNT);
    }
}