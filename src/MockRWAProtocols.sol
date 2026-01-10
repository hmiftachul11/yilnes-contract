// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MockUSDC.sol"; 

interface IMintableUSDC {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function mint(address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IYilnesVault {
    function depositInsuranceProfit(uint256 amount) external;
}

abstract contract MockRWAProtocol is Ownable {
    IMintableUSDC public immutable usdc;
    address public immutable insuranceVault; 
    
    string public name;
    string public symbol;
    uint256 public immutable APY; 
    uint256 public constant INSURANCE_FEE_BPS = 1000; // 10%
    
    mapping(address => uint256) public userPrincipal; 
    mapping(address => uint256) public accruedYield;  
    mapping(address => uint256) public lastUpdate;
    mapping(address => bool) public userInsuranceMode; 
    
    event Deposit(address indexed user, uint256 amount, bool insured);
    event WithdrawPrincipal(address indexed user, uint256 amount);
    event ClaimYield(address indexed user, uint256 netAmount, uint256 insuranceFee, bool insured);
    event AutoMintedLiquidity(uint256 amount);
    event InsuranceModeChanged(address indexed user, bool insured);
    event InsurancePaid(uint256 amount);

    constructor(address _usdc, address _insuranceVault, string memory _name, string memory _symbol, uint256 _apy) Ownable(msg.sender) {
        usdc = IMintableUSDC(_usdc);
        insuranceVault = _insuranceVault;
        name = _name;
        symbol = _symbol;
        APY = _apy;
    }

    function deposit(uint256 amount, bool useInsurance) external {
        _depositWithMode(amount, useInsurance);
    }
    
    function deposit(uint256 amount) external {
        _depositWithMode(amount, true); 
    }
    
    function _depositWithMode(uint256 amount, bool useInsurance) internal {
        require(amount > 0, "Amount must be > 0");
        _updateYield(msg.sender);
        
        require(usdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        userPrincipal[msg.sender] += amount;
        userInsuranceMode[msg.sender] = useInsurance;
        
        emit Deposit(msg.sender, amount, useInsurance);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        _updateYield(msg.sender);
        
        require(amount <= userPrincipal[msg.sender], "Exceeds principal");
        
        uint256 contractBalance = usdc.balanceOf(address(this));
        if (contractBalance < amount) {
            uint256 shortage = amount - contractBalance;
            usdc.mint(address(this), shortage);
            emit AutoMintedLiquidity(shortage);
        }
        
        userPrincipal[msg.sender] -= amount;
        require(usdc.transfer(msg.sender, amount), "Transfer failed");
        
        emit WithdrawPrincipal(msg.sender, amount);
    }

    function claimYield() external {
        _updateYield(msg.sender);
        
        uint256 grossYield = accruedYield[msg.sender];
        require(grossYield > 0, "No yield to claim");
        
        accruedYield[msg.sender] = 0;
        
        bool isInsured = userInsuranceMode[msg.sender];
        uint256 insuranceFee = 0;
        uint256 netPayout = grossYield;
        
        if (isInsured && insuranceVault != address(0)) {
            insuranceFee = (grossYield * INSURANCE_FEE_BPS) / 10000;
            netPayout = grossYield - insuranceFee;
        }
        
        uint256 contractBalance = usdc.balanceOf(address(this));
        if (contractBalance < grossYield) {
            uint256 shortage = grossYield - contractBalance;
            usdc.mint(address(this), shortage);
            emit AutoMintedLiquidity(shortage);
        }
        
        if (insuranceFee > 0) {
            usdc.approve(insuranceVault, insuranceFee);
            IYilnesVault(insuranceVault).depositInsuranceProfit(insuranceFee);
            emit InsurancePaid(insuranceFee);
        }
        
        require(usdc.transfer(msg.sender, netPayout), "Transfer failed");
        emit ClaimYield(msg.sender, netPayout, insuranceFee, isInsured);
    }
    
    function setInsuranceMode(bool useInsurance) external {
        require(userPrincipal[msg.sender] > 0, "No active position");
        userInsuranceMode[msg.sender] = useInsurance;
        emit InsuranceModeChanged(msg.sender, useInsurance);
    }

    function getBalance(address user) public view returns (uint256) {
        return userPrincipal[user] + getPendingYield(user);
    }
    
    function getPendingYield(address user) public view returns (uint256) {
        uint256 principal = userPrincipal[user];
        if (principal == 0 && accruedYield[user] == 0) return 0;
        
        uint256 timeElapsed = (lastUpdate[user] == 0) ? 0 : (block.timestamp - lastUpdate[user]);
        uint256 newInterest = (principal * APY * timeElapsed) / (10000 * 365 days);
        
        return accruedYield[user] + newInterest;
    }
    
    function getNetPendingYield(address user) public view returns (uint256) {
        uint256 grossYield = getPendingYield(user);
        if (grossYield == 0) return 0;
        
        if (userInsuranceMode[user] && insuranceVault != address(0)) {
            uint256 insuranceFee = (grossYield * INSURANCE_FEE_BPS) / 10000;
            return grossYield - insuranceFee;
        }
        return grossYield;
    }
    
    function isUserInsured(address user) external view returns (bool) {
        return userInsuranceMode[user];
    }
    
    function getExpectedInsuranceFee(address user) external view returns (uint256) {
        if (!userInsuranceMode[user] || insuranceVault == address(0)) return 0;
        uint256 grossYield = getPendingYield(user);
        return (grossYield * INSURANCE_FEE_BPS) / 10000;
    }

    function _updateYield(address user) internal {
        if (lastUpdate[user] == 0) {
            lastUpdate[user] = block.timestamp;
            return;
        }
        accruedYield[user] = getPendingYield(user);
        lastUpdate[user] = block.timestamp;
    }
}

contract MockOndoProtocol is MockRWAProtocol {
    constructor(address _usdc, address _vault) MockRWAProtocol(_usdc, _vault, "Ondo USD Yield", "OUSY", 500) {}
}

contract MockMapleProtocol is MockRWAProtocol {
    constructor(address _usdc, address _vault) MockRWAProtocol(_usdc, _vault, "Maple Credit", "MCP", 800) {}
}

contract MockCentrifugeProtocol is MockRWAProtocol {
    constructor(address _usdc, address _vault) MockRWAProtocol(_usdc, _vault, "Centrifuge Real Estate", "CREP", 1200) {}
}

contract MockGoldfinchProtocol is MockRWAProtocol {
    constructor(address _usdc, address _vault) MockRWAProtocol(_usdc, _vault, "Goldfinch Senior", "GSP", 600) {}
}