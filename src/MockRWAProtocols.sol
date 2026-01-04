// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// --- 1. Define Interface for Mintable USDC ---
interface IMockUSDC is IERC20 {
    function mint(address to, uint256 amount) external;
}

// --- 2. Abstract Base Protocol (The Engine) ---
abstract contract MockRWAProtocol is Ownable {
    IMockUSDC public immutable usdc;
    string public name;
    string public symbol;
    uint256 public immutable APY; 
    
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public lastUpdate;
    
    // Events to help debug on frontend
    event InterestAccrued(address indexed user, uint256 interestEarned, uint256 newBalance);
    event AutoMintedLiquidity(uint256 amount);

    constructor(address _usdc, string memory _name, string memory _symbol, uint256 _apy) Ownable(msg.sender) {
        usdc = IMockUSDC(_usdc);
        name = _name;
        symbol = _symbol;
        APY = _apy;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        
        // 1. Update existing balance with interest before adding new funds
        _accrueInterest(msg.sender); 
        
        // 2. Transfer in USDC
        require(usdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        // 3. Update state
        deposits[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        
        // 1. Calculate and add interest up to this second
        _accrueInterest(msg.sender);
        
        require(deposits[msg.sender] >= amount, "Insufficient balance");
        
        // 2. Deduct from user balance
        deposits[msg.sender] -= amount;
        
        // 3. LIQUIDITY CHECK (The Fix)
        uint256 contractBalance = usdc.balanceOf(address(this));
        
        if (contractBalance < amount) {
            uint256 shortage = amount - contractBalance;
            // Print money to pay the interest/yield
            usdc.mint(address(this), shortage);
            emit AutoMintedLiquidity(shortage);
        }
        
        // 4. Transfer out
        require(usdc.transfer(msg.sender, amount), "Transfer failed");
    }

    // View function for UI to see "Live" balance growing
    function getBalance(address user) public view returns (uint256) {
        uint256 principal = deposits[user];
        if (principal == 0) return 0;
        
        // Don't calculate interest if this is the same block
        if (block.timestamp <= lastUpdate[user]) return principal;
        
        uint256 timeElapsed = block.timestamp - lastUpdate[user];
        
        // Simple Interest Formula: Principal * Rate * Time
        // Basis Points: 10000 = 100%
        uint256 interest = (principal * APY * timeElapsed) / (10000 * 365 days);
        
        return principal + interest;
    }

    // Internal helper to lock in the interest
    function _accrueInterest(address user) internal {
        // If it's a new user, just set the timestamp
        if (lastUpdate[user] == 0) {
            lastUpdate[user] = block.timestamp;
            return;
        }

        uint256 currentBalanceWithInterest = getBalance(user);
        
        // Only emit if balance actually changed
        if (currentBalanceWithInterest > deposits[user]) {
            emit InterestAccrued(user, currentBalanceWithInterest - deposits[user], currentBalanceWithInterest);
        }

        deposits[user] = currentBalanceWithInterest;
        lastUpdate[user] = block.timestamp;
    }
}

// --- 3. Concrete Implementations ---

contract MockOndoProtocol is MockRWAProtocol {
    constructor(address _usdc) MockRWAProtocol(_usdc, "Ondo USD Yield", "OUSY", 500) {} // 5% APY
}

contract MockMapleProtocol is MockRWAProtocol {
    constructor(address _usdc) MockRWAProtocol(_usdc, "Maple Credit", "MCP", 800) {} // 8% APY
}

contract MockCentrifugeProtocol is MockRWAProtocol {
    constructor(address _usdc) MockRWAProtocol(_usdc, "Centrifuge Real Estate", "CREP", 1200) {} // 12% APY
}

contract MockGoldfinchProtocol is MockRWAProtocol {
    constructor(address _usdc) MockRWAProtocol(_usdc, "Goldfinch Senior", "GSP", 600) {} // 6% APY
}