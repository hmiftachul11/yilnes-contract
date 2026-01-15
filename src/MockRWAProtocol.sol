// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
// IMPORT UPDATE: Now points to the specific file
import "./MockUSDY.sol"; 

contract MockRWAProtocol is Ownable {
    MockUSDY public immutable usdy;
    
    string public name;
    uint256 public immutable APY_BPS; 
    
    // Yilnes Wrapper State
    uint256 public insuranceReserve;
    mapping(address => uint256) public userPrincipal; 
    mapping(address => uint256) public lastUpdate;
    mapping(address => uint256) public coverExpiry; 
    
    // Config
    uint256 public constant ANNUAL_PREMIUM_BPS = 250; // 2.5%
    
    event Deposit(address indexed user, uint256 invested, uint256 premium, bool insured);
    event Claim(address indexed user, uint256 amount);

    constructor(address _usdy, string memory _name, uint256 _apy) Ownable(msg.sender) {
        usdy = MockUSDY(_usdy);
        name = _name;
        APY_BPS = _apy;
    }

    // --- Upfront Premium Deposit ---
    function deposit(uint256 amount, uint256 coverDurationDays) external {
        require(amount > 0, "Amount > 0");
        require(usdy.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        // Auto-claim any previous pending yield before changing principal
        _claimInternal(msg.sender);

        uint256 invested = amount;
        uint256 premium = 0;
        
        if (coverDurationDays >= 28) {
            // Premium Logic: Principal * 2.5% * (Days / 365)
            premium = (amount * ANNUAL_PREMIUM_BPS * coverDurationDays) / (10000 * 365);
            require(premium < amount, "Cost too high");
            
            invested = amount - premium;
            insuranceReserve += premium;
            coverExpiry[msg.sender] = block.timestamp + (coverDurationDays * 1 days);
        } else {
            // Direct / Uninsured
            coverExpiry[msg.sender] = 0; 
        }
        
        userPrincipal[msg.sender] += invested;
        lastUpdate[msg.sender] = block.timestamp;
        
        emit Deposit(msg.sender, invested, premium, coverDurationDays >= 28);
    }

    function withdraw(uint256 amount) external {
        _claimInternal(msg.sender); // Claim yield first
        require(amount <= userPrincipal[msg.sender], "Over withdraw");
        
        userPrincipal[msg.sender] -= amount;
        require(usdy.transfer(msg.sender, amount), "Transfer failed");
    }

    function claim() external {
        _claimInternal(msg.sender);
    }

    function _claimInternal(address user) internal {
        uint256 yield = getPendingYield(user);
        if (yield > 0) {
            lastUpdate[user] = block.timestamp;
            // Check liquidity (Mock safety check)
            uint256 available = usdy.balanceOf(address(this));
            if(available >= yield) {
                usdy.transfer(user, yield);
                emit Claim(user, yield);
            }
        } else {
            lastUpdate[user] = block.timestamp;
        }
    }

    function getPendingYield(address user) public view returns (uint256) {
        if (userPrincipal[user] == 0) return 0;
        uint256 timeElapsed = block.timestamp - lastUpdate[user];
        return (userPrincipal[user] * APY_BPS * timeElapsed) / (10000 * 365 days);
    }
    
    function isCovered(address user) external view returns (bool) {
        return block.timestamp < coverExpiry[user];
    }
}

// Factory Contracts for Specific RWAs
contract MockOndo is MockRWAProtocol {
    constructor(address _usdy) MockRWAProtocol(_usdy, "Ondo USDY Strategy", 520) {} // 5.2%
}

contract MockMaple is MockRWAProtocol {
    constructor(address _usdy) MockRWAProtocol(_usdy, "Maple Direct", 850) {} // 8.5%
}

contract MockCentrifuge is MockRWAProtocol {
    constructor(address _usdy) MockRWAProtocol(_usdy, "Centrifuge Prime", 1200) {} // 12%
}

contract MockGoldfinch is MockRWAProtocol {
    constructor(address _usdy) MockRWAProtocol(_usdy, "Goldfinch Senior", 600) {} // 6%
}