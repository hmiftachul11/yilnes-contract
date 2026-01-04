// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/interfaces/IERC20.sol";
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
    
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);
    event ClaimYield(address indexed user, uint256 amount);
    event ProtocolAdded(address indexed protocol, uint256 allocation);
    
    error InsufficientBalance();
    error InvalidAmount();
    error NoYieldToClaim();
    
    constructor(address _asset) Ownable(msg.sender) {
        asset = IERC20(_asset);
    }
    
    // --- Core Actions ---

    function deposit(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        
        uint256 totalManagedAssets = totalAssets(); 
        require(asset.transferFrom(msg.sender, address(this), amount), "Transfer Failed");
        
        uint256 shares;
        if (totalShares == 0 || totalManagedAssets == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / totalManagedAssets;
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
        
        uint256 totalManagedAssets = totalAssets();
        uint256 amountOut = (shares * totalManagedAssets) / totalShares;
        
        // Pro-rata reduction of principal
        uint256 principalToBurn = (shares * userPrincipal[msg.sender]) / userShares[msg.sender];
        if (principalToBurn > userPrincipal[msg.sender]) {
             userPrincipal[msg.sender] = 0; 
        } else {
             userPrincipal[msg.sender] -= principalToBurn;
        }

        userShares[msg.sender] -= shares;
        totalShares -= shares;
        
        _withdrawFromProtocol(amountOut);
        
        emit Withdraw(msg.sender, amountOut, shares);
    }

    /**
     * @notice Harvests only the profit, leaving principal staked
     */
    function claimYield() external {
        uint256 currentVal = getUserBalance(msg.sender);
        uint256 principal = userPrincipal[msg.sender];
        
        if (currentVal <= principal) revert NoYieldToClaim();
        
        uint256 yieldAmount = currentVal - principal;
        uint256 totalManagedAssets = totalAssets();
        
        // Calculate shares representing ONLY the yield
        // Formula: shares = (yieldAmount * totalShares) / totalManagedAssets
        uint256 sharesToBurn = (yieldAmount * totalShares) / totalManagedAssets;
        
        // Safety cap
        if (sharesToBurn > userShares[msg.sender]) {
            sharesToBurn = userShares[msg.sender];
        }

        // Burn shares, but DO NOT reduce principal (since principal remains)
        userShares[msg.sender] -= sharesToBurn;
        totalShares -= sharesToBurn;
        
        _withdrawFromProtocol(yieldAmount);
        
        emit ClaimYield(msg.sender, yieldAmount);
    }

    // Internal helper to handle liquidity retrieval safely
    function _withdrawFromProtocol(uint256 amount) internal {
        uint256 looseCash = asset.balanceOf(address(this));
        if (looseCash < amount && protocols.length > 0) {
            uint256 shortage = amount - looseCash;
            IRWAProtocol(protocols[0].protocol).withdraw(shortage);
        }
        
        // Safety Clamp: If protocol sent 1 wei less due to rounding, use actual balance
        uint256 finalBalance = asset.balanceOf(address(this));
        if (finalBalance < amount) {
            amount = finalBalance;
        }
        
        require(asset.transfer(msg.sender, amount), "Transfer Out Failed");
    }
    
    // --- Views ---
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
        return (userShares[user] * totalAssets()) / totalShares;
    }
    
    function getUserYield(address user) external view returns (uint256) {
        uint256 currentVal = getUserBalance(user);
        uint256 principal = userPrincipal[user];
        if (currentVal > principal) return currentVal - principal;
        return 0;
    }

    function getTVL() external view returns (uint256) { return totalAssets(); }
    function getCurrentAPY() external pure returns (uint256) { return 1200; }
    
    function addProtocol(address _protocol, uint256 _allocation) external onlyOwner {
        protocols.push(ProtocolAllocation({protocol: _protocol, allocationBps: _allocation, isActive: true}));
        emit ProtocolAdded(_protocol, _allocation);
    }
}