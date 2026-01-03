// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; // Added Security

interface IRWAProtocol {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getBalance(address user) external view returns (uint256);
}

contract YilnesVault is Ownable {
    IERC20 public immutable asset; // USDC
    
    struct ProtocolAllocation {
        address protocol;
        uint256 allocationBps; // 10000 = 100%
    }
    
    ProtocolAllocation[] public protocols;
    mapping(address => uint256) public userShares;
    uint256 public totalShares;
    
    constructor(address _asset) Ownable(msg.sender) {
        asset = IERC20(_asset);
    }
    
    // --- Core Logic ---

    function deposit(uint256 amount) external {
        require(amount > 0, "Zero amount");
        
        // 1. Calculate Shares BEFORE transferring funds in (Snapshot total assets)
        uint256 totalManagedAssets = totalAssets(); 
        uint256 shares;
        
        if (totalShares == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / totalManagedAssets;
        }
        
        // 2. Transfer Funds In
        require(asset.transferFrom(msg.sender, address(this), amount), "Transfer In Failed");
        
        // 3. Auto-Invest (Simple Strategy: Split evenly or dump into first protocol)
        if (protocols.length > 0) {
            // Simplified: Dump 100% into the first protocol for the demo
            address targetProtocol = protocols[0].protocol;
            asset.approve(targetProtocol, amount);
            IRWAProtocol(targetProtocol).deposit(amount);
        }
        
        // 4. Mint Shares
        userShares[msg.sender] += shares;
        totalShares += shares;
    }
    
    function withdraw(uint256 shares) external {
        require(shares > 0 && userShares[msg.sender] >= shares, "Invalid shares");
        
        // 1. Calculate Asset Value
        uint256 totalManagedAssets = totalAssets();
        uint256 amountOut = (shares * totalManagedAssets) / totalShares;
        
        // 2. Burn Shares
        userShares[msg.sender] -= shares;
        totalShares -= shares;
        
        // 3. Withdraw from Protocol if needed
        uint256 looseCash = asset.balanceOf(address(this));
        if (looseCash < amountOut && protocols.length > 0) {
            uint256 shortage = amountOut - looseCash;
            // Simplified: Withdraw from first protocol
            IRWAProtocol(protocols[0].protocol).withdraw(shortage);
        }
        
        // 4. Transfer to User
        require(asset.transfer(msg.sender, amountOut), "Transfer Out Failed");
    }
    
    // --- View Functions ---

    // Calculates real TVL by checking balance in Vault + balance in Protocols
    function totalAssets() public view returns (uint256) {
        uint256 assets = asset.balanceOf(address(this));
        
        for(uint i = 0; i < protocols.length; i++) {
            assets += IRWAProtocol(protocols[i].protocol).getBalance(address(this));
        }
        
        return assets;
    }
    
    function getUserBalance(address user) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (userShares[user] * totalAssets()) / totalShares;
    }

    function getTVL() external view returns (uint256) {
        return totalAssets();
    }

    function getCurrentAPY() external pure returns (uint256) {
        // Mock APY for demo - 12% = 1200 basis points
        return 1200;
    }

    function getUserYield(address user) external pure returns (uint256) {
        // Simplified yield calculation for demo
        // In reality, this would track historical yields
        user; // silence unused parameter warning
        return 0;
    }
    
    // --- Admin ---

    function addProtocol(address _protocol, uint256 _allocation) external onlyOwner {
        protocols.push(ProtocolAllocation(_protocol, _allocation));
    }
}