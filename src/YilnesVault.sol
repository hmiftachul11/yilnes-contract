// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IRWAProtocol {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
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
    mapping(address => uint256) public userShares;
    mapping(address => uint256) public userPrincipal;
    
    uint256 public totalShares;
    
    // --- INSURANCE STATE ---
    uint256 public insuranceReserve;
    uint256 public constant INSURANCE_FEE_BPS = 1000; // 10% of profits
    
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);
    event ClaimYield(address indexed user, uint256 payout, uint256 feePaid);
    event ProtocolAdded(address indexed protocol, uint256 allocation);
    
    error InsufficientBalance();
    error InvalidAmount();
    error NoYieldToClaim();
    
    constructor(address _asset) Ownable(msg.sender) {
        asset = IERC20(_asset);
    }
    
    function deposit(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        
        // Calculate assets available for shares (Total - Reserve)
        uint256 allocatableAssets = totalAssets() - insuranceReserve; 
        
        require(asset.transferFrom(msg.sender, address(this), amount), "Transfer Failed");
        
        uint256 shares;
        if (totalShares == 0 || allocatableAssets == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / allocatableAssets;
        }
        
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
    
    function withdraw(uint256 shares) external {
        if (shares == 0) revert InvalidAmount();
        if (userShares[msg.sender] < shares) revert InsufficientBalance();
        
        uint256 allocatableAssets = totalAssets() - insuranceReserve;
        uint256 grossAmount = (shares * allocatableAssets) / totalShares;
        
        // Pro-rata principal reduction
        uint256 principalToBurn = (shares * userPrincipal[msg.sender]) / userShares[msg.sender];
        
        // Fee Logic: Check if withdrawing profit
        uint256 payout = grossAmount;
        
        if (grossAmount > principalToBurn) {
            uint256 profit = grossAmount - principalToBurn;
            uint256 fee = (profit * INSURANCE_FEE_BPS) / 10000;
            payout = grossAmount - fee;
            insuranceReserve += fee; // Add to safety pool
        }

        if (principalToBurn > userPrincipal[msg.sender]) {
             userPrincipal[msg.sender] = 0; 
        } else {
             userPrincipal[msg.sender] -= principalToBurn;
        }

        userShares[msg.sender] -= shares;
        totalShares -= shares;
        
        _withdrawFromProtocol(payout);
        
        emit Withdraw(msg.sender, payout, shares);
    }

    function claimYield() external {
        uint256 currentVal = getUserBalance(msg.sender);
        uint256 principal = userPrincipal[msg.sender];
        
        if (currentVal <= principal) revert NoYieldToClaim();
        
        uint256 grossProfit = currentVal - principal;
        
        // --- INSURANCE FEE ---
        uint256 fee = (grossProfit * INSURANCE_FEE_BPS) / 10000;
        uint256 netPayout = grossProfit - fee;
        
        insuranceReserve += fee;
        
        // Burn shares equivalent to the GROSS profit withdrawn
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

    function _withdrawFromProtocol(uint256 amount) internal {
        uint256 looseCash = asset.balanceOf(address(this));
        if (looseCash < amount && protocols.length > 0) {
            uint256 shortage = amount - looseCash;
            IRWAProtocol(protocols[0].protocol).withdraw(shortage);
        }
        uint256 finalBalance = asset.balanceOf(address(this));
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
        // User only owns the Allocatable part, not the Reserve
        uint256 allocatableAssets = totalAssets() - insuranceReserve;
        return (userShares[user] * allocatableAssets) / totalShares;
    }
    
    function getUserYield(address user) external view returns (uint256) {
        uint256 currentVal = getUserBalance(user);
        uint256 principal = userPrincipal[user];
        if (currentVal > principal) return currentVal - principal;
        return 0;
    }

    // New View for UI
    function getInsuranceReserve() external view returns (uint256) {
        return insuranceReserve;
    }

    function getTVL() external view returns (uint256) { return totalAssets(); }
    function getCurrentAPY() external pure returns (uint256) { return 1200; } // 12% Base
    
    function addProtocol(address _protocol, uint256 _allocation) external onlyOwner {
        protocols.push(ProtocolAllocation({protocol: _protocol, allocationBps: _allocation, isActive: true}));
        emit ProtocolAdded(_protocol, _allocation);
    }
}