// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockUSDC is ERC20, Ownable {
    // Faucet Configuration
    mapping(address => uint256) public lastFaucetTime;
    uint256 public constant FAUCET_AMOUNT = 1000 * 10**6; // 1000 USDC
    uint256 public constant FAUCET_COOLDOWN = 24 hours;
    
    // Events
    event FaucetUsed(address indexed user, uint256 amount);
    event LiquidityMinted(address indexed to, uint256 amount);

    constructor() ERC20("Mock USD Coin", "USDC") Ownable(msg.sender) {
        // Mint initial supply (1 Million) to the deployer
        _mint(msg.sender, 1000000 * 10**decimals());
    }

    /**
     * @dev Override decimals to return 6, matching real USDC.
     */
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    /**
     * @dev Public Faucet: Gives 1000 USDC every 24 hours.
     */
    function faucet() external {
        require(
            block.timestamp >= lastFaucetTime[msg.sender] + FAUCET_COOLDOWN,
            "Faucet: cooldown active (wait 24h)"
        );
        
        lastFaucetTime[msg.sender] = block.timestamp;
        _mint(msg.sender, FAUCET_AMOUNT);
        
        emit FaucetUsed(msg.sender, FAUCET_AMOUNT);
    }

    /**
     * @dev Public Mint: Allows ANYONE to mint tokens.
     * CRITICAL: This allows your MockRWAProtocol contracts to "print" liquidity 
     * when they need to pay yield that doesn't physically exist yet.
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
        emit LiquidityMinted(to, amount);
    }
}