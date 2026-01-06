// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockUSDC is ERC20, Ownable {
    // Faucet State
    mapping(address => uint256) public lastFaucetTime;
    uint256 public constant FAUCET_AMOUNT = 1000 * 10**6; 
    uint256 public constant FAUCET_COOLDOWN = 24 hours;
    
    event FaucetUsed(address indexed user, uint256 amount);
    event LiquidityMinted(address indexed to, uint256 amount);

    constructor() ERC20("Mock USD Coin", "USDC") Ownable(msg.sender) {
        // Mint 1 Million to deployer
        _mint(msg.sender, 1000000 * 10**decimals());
    }

    function decimals() public view virtual override returns (uint8) {
        return 6; 
    }

    // --- CRITICAL FIX: PUBLIC MINT ---
    // This MUST be external and unprotected for MockProtocols to work!
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
        emit LiquidityMinted(to, amount);
    }

    function faucet() external {
        require(
            block.timestamp >= lastFaucetTime[msg.sender] + FAUCET_COOLDOWN,
            "Faucet: cooldown active"
        );
        lastFaucetTime[msg.sender] = block.timestamp;
        _mint(msg.sender, FAUCET_AMOUNT);
        emit FaucetUsed(msg.sender, FAUCET_AMOUNT);
    }
}