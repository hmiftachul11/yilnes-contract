// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev Interface for interacting with the Mock RWA Protocols
 */
interface IRWAProtocol {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getBalance(address user) external view returns (uint256);
}

/**
 * @title YilnesVault
 * @dev Main vault contract for Yilnes RWA Yield Aggregator
 * @notice Aggregates yields from multiple RWA protocols on Mantle Network
 */
contract YilnesVault is Ownable {
    IERC20 public immutable asset; // USDC
    
    struct ProtocolAllocation {
        address protocol;
        uint256 allocationBps; // 10000 = 100%
        bool isActive;
    }
    
    // Core State
    ProtocolAllocation[] public protocols;
    mapping(address => uint256) public userShares;
    mapping(address => uint256) public userPrincipal; // Tracks original investment for yield calc
    
    uint256 public totalShares;
    
    // Events
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);
    event ProtocolAdded(address indexed protocol, uint256 allocation);
    
    // Errors
    error InsufficientBalance();
    error InvalidAmount();
    error NoActiveProtocol();
    
    constructor(address _asset) Ownable(msg.sender) {
        asset = IERC20(_asset);
    }
    
    // ==========================================
    // Core User Actions
    // ==========================================

    /**
     * @notice Deposit USDC to earn RWA yields
     * @param amount Amount of USDC to deposit
     */
    function deposit(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        
        // 1. Snapshot Total Assets BEFORE deposit to calculate correct share price
        uint256 totalManagedAssets = totalAssets(); 
        
        // 2. Transfer Funds In
        require(asset.transferFrom(msg.sender, address(this), amount), "Transfer Failed");
        
        // 3. Calculate Shares
        uint256 shares;
        if (totalShares == 0 || totalManagedAssets == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / totalManagedAssets;
        }
        
        // 4. Auto-Invest into the first active protocol
        // (In a real production vault, this would be a weighted split)
        if (protocols.length > 0) {
            address targetProtocol = protocols[0].protocol;
            // Approve protocol to spend vault's USDC
            asset.approve(targetProtocol, amount);
            // Deposit into protocol
            IRWAProtocol(targetProtocol).deposit(amount);
        }
        
        // 5. Update State
        userShares[msg.sender] += shares;
        userPrincipal[msg.sender] += amount; // Track principal for yield display
        totalShares += shares;
        
        emit Deposit(msg.sender, amount, shares);
    }
    
    /**
     * @notice Withdraw USDC and earned yields
     * @param shares Amount of shares to redeem
     */
    function withdraw(uint256 shares) external {
        if (shares == 0) revert InvalidAmount();
        if (userShares[msg.sender] < shares) revert InsufficientBalance();
        
        // 1. Calculate Asset Value of shares
        uint256 totalManagedAssets = totalAssets();
        uint256 amountOut = (shares * totalManagedAssets) / totalShares;
        
        // 2. Update Principal Tracking (Pro-rata reduction)
        // If user withdraws 50% of their shares, we reduce their principal by 50%
        uint256 principalToBurn = (shares * userPrincipal[msg.sender]) / userShares[msg.sender];
        userPrincipal[msg.sender] -= principalToBurn;

        // 3. Burn Shares
        userShares[msg.sender] -= shares;
        totalShares -= shares;
        
        // 4. Check Liquidity & Withdraw from Protocol if needed
        uint256 looseCash = asset.balanceOf(address(this));
        if (looseCash < amountOut && protocols.length > 0) {
            uint256 shortage = amountOut - looseCash;
            // Pull funds from protocol
            IRWAProtocol(protocols[0].protocol).withdraw(shortage);
        }
        
        // 5. Transfer to User
        require(asset.transfer(msg.sender, amountOut), "Transfer Out Failed");
        
        emit Withdraw(msg.sender, amountOut, shares);
    }
    
    // ==========================================
    // View Functions (Dashboard Data)
    // ==========================================

    /**
     * @notice Calculates real TVL by checking Vault Balance + Protocol Balances
     */
    function totalAssets() public view returns (uint256) {
        uint256 assets = asset.balanceOf(address(this));
        
        // Sum up balances from all connected protocols
        for(uint i = 0; i < protocols.length; i++) {
            if (protocols[i].isActive) {
                assets += IRWAProtocol(protocols[i].protocol).getBalance(address(this));
            }
        }
        
        return assets;
    }
    
    /**
     * @notice Get user's current balance in USDC terms
     */
    function getUserBalance(address user) public view returns (uint256) {
        if (totalShares == 0) return 0;
        return (userShares[user] * totalAssets()) / totalShares;
    }
    
    /**
     * @notice Get user's earned yield (Current Value - Principal)
     */
    function getUserYield(address user) external view returns (uint256) {
        uint256 currentVal = getUserBalance(user);
        uint256 principal = userPrincipal[user];
        
        if (currentVal > principal) {
            return currentVal - principal;
        }
        return 0;
    }

    // Standard getter for UI compatibility
    function getTVL() external view returns (uint256) {
        return totalAssets();
    }

    // Mock APY for the dashboard (12%)
    function getCurrentAPY() external pure returns (uint256) {
        return 1200; 
    }
    
    // ==========================================
    // Admin Functions
    // ==========================================

    /**
     * @notice Add new RWA protocol to the aggregator
     */
    function addProtocol(address _protocol, uint256 _allocation) external onlyOwner {
        protocols.push(ProtocolAllocation({
            protocol: _protocol,
            allocationBps: _allocation,
            isActive: true
        }));
        
        emit ProtocolAdded(_protocol, _allocation);
    }
}