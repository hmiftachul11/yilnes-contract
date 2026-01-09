// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Interface for our updated Protocols
interface IRWAProtocol {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function claimYield() external; 
    function getBalance(address user) external view returns (uint256);
}

contract YilnesVault is Ownable {
    IERC20 public immutable asset; 
    
    struct ProtocolAllocation {
        address protocol;
        uint256 allocationBps; 
        bool isActive;
    }
    
    ProtocolAllocation[] public protocols;
    
    // User Tracking
    mapping(address => uint256) public userShares;
    mapping(address => uint256) public userPrincipal;
    uint256 public totalShares;
    
    // Insurance
    uint256 public insuranceReserve;
    uint256 public constant INSURANCE_FEE_BPS = 1000; // 10%
    
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 sharesBurned);
    event ClaimYield(address indexed user, uint256 payout, uint256 insuranceFee);
    event ProtocolAdded(address indexed protocol, uint256 allocation);
    
    constructor(address _asset) Ownable(msg.sender) {
        asset = IERC20(_asset);
    }
    
    // --- 1. DEPOSIT ---
    function deposit(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        
        // Calculate share price based on Allocatable Assets (Total - Reserve)
        uint256 allocatableAssets = totalAssets() - insuranceReserve;
        
        require(asset.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        uint256 shares;
        if (totalShares == 0 || allocatableAssets == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / allocatableAssets;
        }
        
        // Invest in underlying protocol
        if (protocols.length > 0) {
            address targetProtocol = protocols[0].protocol;
            asset.approve(targetProtocol, amount);
            IRWAProtocol(targetProtocol).deposit(amount);
        }
        
        userShares[msg.sender] += shares;
        userPrincipal[msg.sender] += amount;
        totalShares += shares;
        
        emit Deposit(msg.sender, amount, shares);
    }
    
    // --- 2. WITHDRAW (Principal Only) ---
    function withdraw(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        require(amount <= userPrincipal[msg.sender], "Exceeds principal. Use Claim for profits.");
        
        // Determine how many shares to burn to retrieve this principal amount
        uint256 allocatableAssets = totalAssets() - insuranceReserve;
        uint256 sharesToBurn = (amount * totalShares) / allocatableAssets;
        
        // Safety clamp for rounding errors
        if (sharesToBurn > userShares[msg.sender]) {
            sharesToBurn = userShares[msg.sender];
        }

        userPrincipal[msg.sender] -= amount;
        userShares[msg.sender] -= sharesToBurn;
        totalShares -= sharesToBurn;
        
        _withdrawFromProtocol(amount);
        
        emit Withdraw(msg.sender, amount, sharesToBurn);
    }

    // --- 3. CLAIM (Yield Only) ---
    function claimYield() external {
        uint256 currentVal = getUserBalance(msg.sender);
        uint256 principal = userPrincipal[msg.sender];
        
        require(currentVal > principal, "No yield to claim");
        
        uint256 grossProfit = currentVal - principal;
        
        // Take Insurance Fee
        uint256 fee = (grossProfit * INSURANCE_FEE_BPS) / 10000;
        uint256 netPayout = grossProfit - fee;
        
        insuranceReserve += fee;
        
        // Burn shares representing the GROSS profit
        uint256 allocatableAssets = totalAssets() - insuranceReserve;
        uint256 sharesToBurn = (grossProfit * totalShares) / allocatableAssets;
        
        if (sharesToBurn > userShares[msg.sender]) {
             sharesToBurn = userShares[msg.sender];
        }

        userShares[msg.sender] -= sharesToBurn;
        totalShares -= sharesToBurn;
        
        _withdrawFromProtocol(netPayout);
        
        emit ClaimYield(msg.sender, netPayout, fee);
    }

    // --- INTERNAL & VIEWS ---

    function _withdrawFromProtocol(uint256 amount) internal {
        // Try to pay from loose cash first
        uint256 looseCash = asset.balanceOf(address(this));
        
        if (looseCash < amount && protocols.length > 0) {
            // Need more cash? Ask the underlying protocol
            uint256 shortage = amount - looseCash;
            
            // Note: We try to withdraw PRINCIPAL first from underlying, 
            // but if that fails/isn't enough, we might need a 'claim' mechanism 
            // on the underlying. For this Mock, withdraw() handles getting funds.
            IRWAProtocol(protocols[0].protocol).withdraw(shortage);
        }
        
        // Double check balance after withdrawal attempt
        uint256 finalBalance = asset.balanceOf(address(this));
        
        // If we STILL don't have enough (maybe due to fees or liquidity), pay what we have
        // But for Infinite Liquidity Mock, this shouldn't happen.
        if (finalBalance < amount) amount = finalBalance;
        
        require(asset.transfer(msg.sender, amount), "Transfer Out Failed");
    }
    
    function totalAssets() public view returns (uint256) {
        uint256 assets = asset.balanceOf(address(this));
        for(uint i = 0; i < protocols.length; i++) {
            if (protocols[i].isActive) {
                assets += IRWAProtocol(protocols[i].protocol).getBalance(address(this));
            }
        }
        return assets;
    }
    
    function getUserBalance(address user) public view returns (uint256) {
        if (totalShares == 0) return 0;
        uint256 allocatableAssets = totalAssets() - insuranceReserve;
        return (userShares[user] * allocatableAssets) / totalShares;
    }
    
    function getUserYield(address user) external view returns (uint256) {
        uint256 currentVal = getUserBalance(user);
        uint256 principal = userPrincipal[user];
        if (currentVal > principal) return currentVal - principal;
        return 0;
    }

    function getInsuranceReserve() external view returns (uint256) {
        return insuranceReserve;
    }

    function getTVL() external view returns (uint256) { return totalAssets(); }
    function getCurrentAPY() external pure returns (uint256) { return 1200; } 
    
    function addProtocol(address _protocol, uint256 _allocation) external onlyOwner {
        protocols.push(ProtocolAllocation({protocol: _protocol, allocationBps: _allocation, isActive: true}));
        emit ProtocolAdded(_protocol, _allocation);
    }
}