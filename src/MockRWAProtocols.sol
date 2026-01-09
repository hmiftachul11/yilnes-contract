// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MockUSDC.sol"; // Ensure this import path matches your folder structure

// Interface to call the Mint function
interface IMintableUSDC {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function mint(address to, uint256 amount) external;
}

abstract contract MockRWAProtocol is Ownable {
    IMintableUSDC public immutable usdc;
    string public name;
    string public symbol;
    uint256 public immutable APY; 
    
    // --- SEPARATED TRACKING ---
    mapping(address => uint256) public userPrincipal; // User's initial deposit
    mapping(address => uint256) public accruedYield;  // Yield earned but not claimed
    mapping(address => uint256) public lastUpdate;
    
    event Deposit(address indexed user, uint256 amount);
    event WithdrawPrincipal(address indexed user, uint256 amount);
    event ClaimYield(address indexed user, uint256 amount);
    event AutoMintedLiquidity(uint256 amount);

    constructor(address _usdc, string memory _name, string memory _symbol, uint256 _apy) Ownable(msg.sender) {
        usdc = IMintableUSDC(_usdc);
        name = _name;
        symbol = _symbol;
        APY = _apy;
    }

    // --- 1. DEPOSIT ---
    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        _updateYield(msg.sender); // Calculate yield before changing principal
        
        require(usdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        userPrincipal[msg.sender] += amount;
        
        emit Deposit(msg.sender, amount);
    }

    // --- 2. WITHDRAW (Strictly Principal) ---
    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        _updateYield(msg.sender);
        
        require(amount <= userPrincipal[msg.sender], "Cannot withdraw more than principal. Use claimYield() for profits.");
        
        userPrincipal[msg.sender] -= amount;
        require(usdc.transfer(msg.sender, amount), "Transfer failed");
        
        emit WithdrawPrincipal(msg.sender, amount);
    }

    // --- 3. CLAIM (Yield Only) ---
    function claimYield() external {
        _updateYield(msg.sender);
        
        uint256 yieldToClaim = accruedYield[msg.sender];
        require(yieldToClaim > 0, "No yield to claim");
        
        // Reset accrued yield BEFORE sending to prevent re-entrancy
        accruedYield[msg.sender] = 0;
        
        // INFINITE LIQUIDITY CHECK
        uint256 contractBalance = usdc.balanceOf(address(this));
        if (contractBalance < yieldToClaim) {
            uint256 shortage = yieldToClaim - contractBalance;
            // "Print" the yield
            usdc.mint(address(this), shortage);
            emit AutoMintedLiquidity(shortage);
        }
        
        require(usdc.transfer(msg.sender, yieldToClaim), "Transfer failed");
        emit ClaimYield(msg.sender, yieldToClaim);
    }

    // --- VIEWS ---
    
    // Total Value (Principal + Unclaimed Yield)
    function getBalance(address user) public view returns (uint256) {
        return userPrincipal[user] + getPendingYield(user);
    }
    
    // Just the pending yield
    function getPendingYield(address user) public view returns (uint256) {
        uint256 principal = userPrincipal[user];
        if (principal == 0 && accruedYield[user] == 0) return 0;
        
        // Calculate new interest since last interaction
        uint256 timeElapsed = (lastUpdate[user] == 0) ? 0 : (block.timestamp - lastUpdate[user]);
        uint256 newInterest = (principal * APY * timeElapsed) / (10000 * 365 days);
        
        return accruedYield[user] + newInterest;
    }

    // Internal helper to lock in interest
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

contract MockOndoProtocol is MockRWAProtocol {
    constructor(address _usdc) MockRWAProtocol(_usdc, "Ondo USD Yield", "OUSY", 500) {}
}

contract MockMapleProtocol is MockRWAProtocol {
    constructor(address _usdc) MockRWAProtocol(_usdc, "Maple Credit", "MCP", 800) {}
}

contract MockCentrifugeProtocol is MockRWAProtocol {
    constructor(address _usdc) MockRWAProtocol(_usdc, "Centrifuge Real Estate", "CREP", 1200) {}
}

contract MockGoldfinchProtocol is MockRWAProtocol {
    constructor(address _usdc) MockRWAProtocol(_usdc, "Goldfinch Senior", "GSP", 600) {}
}