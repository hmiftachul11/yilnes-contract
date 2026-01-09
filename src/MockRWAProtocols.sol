// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MockUSDC.sol"; 

// Interface to call Mint
interface IMintableUSDC {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function mint(address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external returns (bool);
}

// Interface to call Vault
interface IYilnesVault {
    function depositInsuranceProfit(uint256 amount) external;
}

abstract contract MockRWAProtocol is Ownable {
    IMintableUSDC public immutable usdc;
    address public immutable insuranceVault; // [NEW] Link to Vault

    string public name;
    string public symbol;
    uint256 public immutable APY; 
    
    mapping(address => uint256) public userPrincipal;
    mapping(address => uint256) public accruedYield;
    mapping(address => uint256) public lastUpdate;
    
    event Deposit(address indexed user, uint256 amount);
    event WithdrawPrincipal(address indexed user, uint256 amount);
    event ClaimYield(address indexed user, uint256 amount);
    event AutoMintedLiquidity(uint256 amount);
    event InsurancePaid(uint256 amount);

    // [UPDATED] Constructor takes insuranceVault address
    constructor(address _usdc, address _insuranceVault, string memory _name, string memory _symbol, uint256 _apy) Ownable(msg.sender) {
        usdc = IMintableUSDC(_usdc);
        insuranceVault = _insuranceVault;
        name = _name;
        symbol = _symbol;
        APY = _apy;
    }

    // --- 1. DEPOSIT ---
    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        _updateYield(msg.sender); 
        
        require(usdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        userPrincipal[msg.sender] += amount;
        
        emit Deposit(msg.sender, amount);
    }

    // --- 2. WITHDRAW (Principal Only) ---
    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        _updateYield(msg.sender);
        
        require(amount <= userPrincipal[msg.sender], "Cannot withdraw more than principal. Use claimYield() for profits.");
        
        userPrincipal[msg.sender] -= amount;
        require(usdc.transfer(msg.sender, amount), "Transfer failed");
        
        emit WithdrawPrincipal(msg.sender, amount);
    }

    // --- 3. CLAIM (Yield Only) ---
    // [UPDATED] Pays 10% to Vault, 90% to User
    function claimYield() external {
        _updateYield(msg.sender);
        
        uint256 grossYield = accruedYield[msg.sender];
        require(grossYield > 0, "No yield to claim");
        
        // Reset accrued yield
        accruedYield[msg.sender] = 0;
        
        // 1. Calculate Fees
        uint256 insuranceFee = (grossYield * 1000) / 10000; // 10%
        uint256 netPayout = grossYield - insuranceFee;      // 90%

        // 2. Infinite Liquidity Check (Mint if needed)
        uint256 contractBalance = usdc.balanceOf(address(this));
        if (contractBalance < grossYield) {
            uint256 shortage = grossYield - contractBalance;
            usdc.mint(address(this), shortage);
            emit AutoMintedLiquidity(shortage);
        }
        
        // 3. Pay Insurance to Vault
        if (insuranceFee > 0 && insuranceVault != address(0)) {
            usdc.approve(insuranceVault, insuranceFee);
            IYilnesVault(insuranceVault).depositInsuranceProfit(insuranceFee);
            emit InsurancePaid(insuranceFee);
        }
        
        // 4. Pay Net Yield to User
        require(usdc.transfer(msg.sender, netPayout), "Transfer failed");
        emit ClaimYield(msg.sender, netPayout);
    }

    // --- VIEWS ---
    
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

    function _updateYield(address user) internal {
        if (lastUpdate[user] == 0) {
            lastUpdate[user] = block.timestamp;
            return;
        }
        accruedYield[user] = getPendingYield(user);
        lastUpdate[user] = block.timestamp;
    }
}

// --- CONCRETE PROTOCOLS ---
// IMPORTANT: You must deploy YilnesVault FIRST, then pass its address here.

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