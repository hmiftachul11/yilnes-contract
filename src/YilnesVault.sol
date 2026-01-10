// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IRWAProtocol {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function claimYield() external; 
    function getBalance(address user) external view returns (uint256);
}

contract YilnesVault is Ownable, ReentrancyGuard {
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
    
    uint256 public insuranceReserve;
    uint256 public constant INSURANCE_FEE_BPS = 1000; // 10%
    
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 sharesBurned);
    event ClaimYield(address indexed user, uint256 payout, uint256 insuranceFee);
    event ProtocolAdded(address indexed protocol, uint256 allocation);
    event InsuranceFunded(address indexed source, uint256 amount);
    
    constructor(address _asset) Ownable(msg.sender) {
        asset = IERC20(_asset);
    }
    
    function depositInsuranceProfit(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(asset.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        insuranceReserve += amount;
        emit InsuranceFunded(msg.sender, amount);
    }
    
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Invalid amount");
        
        uint256 allocatableAssets = totalAssets() - insuranceReserve;
        require(asset.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
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
    
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Invalid amount");
        require(amount <= userPrincipal[msg.sender], "Use Claim for profits");
        
        uint256 allocatableAssets = totalAssets() - insuranceReserve;
        require(allocatableAssets > 0, "System empty");
        
        uint256 sharesToBurn = (amount * totalShares) / allocatableAssets;
        if (sharesToBurn > userShares[msg.sender]) {
            sharesToBurn = userShares[msg.sender];
        }

        userPrincipal[msg.sender] -= amount;
        userShares[msg.sender] -= sharesToBurn;
        totalShares -= sharesToBurn;
        
        _withdrawFromProtocol(amount, true);
        
        emit Withdraw(msg.sender, amount, sharesToBurn);
    }

    function claimYield() external nonReentrant {
        uint256 currentVal = getUserBalance(msg.sender);
        uint256 principal = userPrincipal[msg.sender];
        
        require(currentVal > principal, "No yield available");
        
        uint256 idealGrossProfit = currentVal - principal;
        
        if (protocols.length > 0) {
            try IRWAProtocol(protocols[0].protocol).claimYield() {} catch {}
        }
        
        uint256 availableCash = asset.balanceOf(address(this));
        
        uint256 actualGrossProfit = idealGrossProfit;
        if (availableCash < actualGrossProfit) {
            actualGrossProfit = availableCash;
        }

        require(actualGrossProfit > 0, "Yield not realized yet");

        uint256 fee = (actualGrossProfit * INSURANCE_FEE_BPS) / 10000;
        uint256 netPayout = actualGrossProfit - fee;
        
        insuranceReserve += fee;
        
        uint256 allocatableAssets = totalAssets() - insuranceReserve;
        uint256 sharesToBurn = (actualGrossProfit * totalShares) / allocatableAssets;
        
        if (sharesToBurn > userShares[msg.sender]) {
             sharesToBurn = userShares[msg.sender];
        }

        userShares[msg.sender] -= sharesToBurn;
        totalShares -= sharesToBurn;
        
        require(asset.transfer(msg.sender, netPayout), "Transfer Out Failed");
        
        emit ClaimYield(msg.sender, netPayout, fee);
    }


    function _withdrawFromProtocol(uint256 amount, bool allowPrincipal) internal {
        uint256 looseCash = asset.balanceOf(address(this));
        
        if (looseCash < amount && protocols.length > 0) {
            address strategy = protocols[0].protocol;
            
            try IRWAProtocol(strategy).claimYield() {} catch {}
            
            looseCash = asset.balanceOf(address(this));
            
            if (looseCash < amount && allowPrincipal) {
                uint256 shortage = amount - looseCash;
                IRWAProtocol(strategy).withdraw(shortage);
            }
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