// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/interfaces/IERC20.sol";
import "forge-std/interfaces/IERC4626.sol";

/**
 * @title YilnesVault
 * @dev Main vault contract for Yilnes RWA Yield Aggregator
 * @notice Aggregates yields from multiple RWA protocols on Mantle Network
 */
contract YilnesVault {
    IERC20 public immutable asset; // USDC
    
    struct ProtocolAllocation {
        address protocolAddress;
        uint256 allocation; // Percentage in basis points (10000 = 100%)
        bool isActive;
    }
    
    struct UserDeposit {
        uint256 amount;
        uint256 timestamp;
        uint256 shares;
    }
    
    // State variables
    mapping(address => UserDeposit[]) public userDeposits;
    mapping(address => uint256) public userShares;
    ProtocolAllocation[] public protocols;
    
    uint256 public totalAssets;
    uint256 public totalShares;
    
    // Events
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);
    event ProtocolAdded(address indexed protocol, uint256 allocation);
    event YieldHarvested(uint256 amount);
    
    // Errors
    error InsufficientBalance();
    error InvalidAmount();
    error ProtocolNotActive();
    
    modifier onlyPositiveAmount(uint256 amount) {
        if (amount == 0) revert InvalidAmount();
        _;
    }
    
    constructor(address _asset) {
        asset = IERC20(_asset);
    }
    
    /**
     * @notice Deposit USDC to earn RWA yields
     * @param amount Amount of USDC to deposit
     */
    function deposit(uint256 amount) external onlyPositiveAmount(amount) {
        require(asset.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        uint256 shares;
        if (totalShares == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / totalAssets;
        }
        
        userDeposits[msg.sender].push(UserDeposit({
            amount: amount,
            timestamp: block.timestamp,
            shares: shares
        }));
        
        userShares[msg.sender] += shares;
        totalAssets += amount;
        totalShares += shares;
        
        emit Deposit(msg.sender, amount, shares);
    }
    
    /**
     * @notice Withdraw USDC and earned yields
     * @param shares Amount of shares to redeem
     */
    function withdraw(uint256 shares) external onlyPositiveAmount(shares) {
        if (userShares[msg.sender] < shares) revert InsufficientBalance();
        
        uint256 withdrawAmount = (shares * totalAssets) / totalShares;
        
        userShares[msg.sender] -= shares;
        totalShares -= shares;
        totalAssets -= withdrawAmount;
        
        require(asset.transfer(msg.sender, withdrawAmount), "Transfer failed");
        
        emit Withdraw(msg.sender, withdrawAmount, shares);
    }
    
    /**
     * @notice Get user's total deposited amount
     */
    function getUserBalance(address user) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (userShares[user] * totalAssets) / totalShares;
    }
    
    /**
     * @notice Get user's yield earned
     */
    function getUserYield(address user) external view returns (uint256) {
        uint256 currentValue = this.getUserBalance(user);
        uint256 deposited = 0;
        
        UserDeposit[] memory deposits = userDeposits[user];
        for (uint i = 0; i < deposits.length; i++) {
            deposited += deposits[i].amount;
        }
        
        return currentValue > deposited ? currentValue - deposited : 0;
    }
    
    /**
     * @notice Add new RWA protocol for yield farming
     */
    function addProtocol(address protocolAddress, uint256 allocation) external {
        protocols.push(ProtocolAllocation({
            protocolAddress: protocolAddress,
            allocation: allocation,
            isActive: true
        }));
        
        emit ProtocolAdded(protocolAddress, allocation);
    }
    
    /**
     * @notice Get current APY (mock for demo)
     */
    function getCurrentAPY() external pure returns (uint256) {
        return 1200; // 12% APY in basis points
    }
    
    /**
     * @notice Get total value locked
     */
    function getTVL() external view returns (uint256) {
        return totalAssets;
    }
}