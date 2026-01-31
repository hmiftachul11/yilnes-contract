// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MockUSDC.sol"; 

contract MockRWAProtocol is Ownable {
    MockUSDC public immutable usdc;
    
    string public name;
    uint256 public immutable APY_BPS;
    
    uint256 public insuranceReserve;
    mapping(address => uint256) public userPrincipal; 
    mapping(address => uint256) public lastUpdate;
    mapping(address => uint256) public coverExpiry; 
    
    uint256 public constant ANNUAL_PREMIUM_BPS = 250;
    
    event Deposit(address indexed user, uint256 invested, uint256 premium, bool insured);
    event Claim(address indexed user, uint256 amount);

    constructor(address _usdc, string memory _name, uint256 _apy) Ownable(msg.sender) {
        usdc = MockUSDC(_usdc);
        name = _name;
        APY_BPS = _apy;
    }

    function deposit(uint256 amount, uint256 coverDurationDays) external {
        require(amount > 0, "Amount > 0");
        require(usdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        _claimInternal(msg.sender);

        uint256 invested = amount;
        uint256 premium = 0;
        
        if (coverDurationDays >= 28) {
            // Math works fine for 6 decimals as long as amount is scaled
            premium = (amount * ANNUAL_PREMIUM_BPS * coverDurationDays) / (10000 * 365);
            require(premium < amount, "Cost too high");
            
            invested = amount - premium;
            insuranceReserve += premium;
            coverExpiry[msg.sender] = block.timestamp + (coverDurationDays * 1 days);
        } else {
            coverExpiry[msg.sender] = 0; 
        }
        
        userPrincipal[msg.sender] += invested;
        lastUpdate[msg.sender] = block.timestamp;
        
        emit Deposit(msg.sender, invested, premium, coverDurationDays >= 28);
    }

    function withdraw(uint256 amount) external {
        _claimInternal(msg.sender);
        require(amount <= userPrincipal[msg.sender], "Over withdraw");
        
        userPrincipal[msg.sender] -= amount;
        require(usdc.transfer(msg.sender, amount), "Transfer failed");
    }

    function claim() external {
        _claimInternal(msg.sender);
    }

    function _claimInternal(address user) internal {
        uint256 yield = getPendingYield(user);
        if (yield > 0) {
            lastUpdate[user] = block.timestamp;
            uint256 available = usdc.balanceOf(address(this));
            // Only transfer if contract has funds (Mock Logic)
            if(available >= yield) {
                usdc.transfer(user, yield);
                emit Claim(user, yield);
            }
        } else {
            lastUpdate[user] = block.timestamp;
        }
    }

    function getPendingYield(address user) public view returns (uint256) {
        if (userPrincipal[user] == 0) return 0;
        uint256 timeElapsed = block.timestamp - lastUpdate[user];
        // Standard Simple Interest Formula
        return (userPrincipal[user] * APY_BPS * timeElapsed) / (10000 * 365 days);
    }
    
    function isCovered(address user) external view returns (bool) {
        return block.timestamp < coverExpiry[user];
    }
}

contract MockOndo is MockRWAProtocol {
    constructor(address _usdc) MockRWAProtocol(_usdc, "Ondo USDY Strategy", 520) {}
}

contract MockMaple is MockRWAProtocol {
    constructor(address _usdc) MockRWAProtocol(_usdc, "Maple Direct", 850) {}
}

contract MockCentrifuge is MockRWAProtocol {
    constructor(address _usdc) MockRWAProtocol(_usdc, "Centrifuge Prime", 1200) {}
}

contract MockGoldfinch is MockRWAProtocol {
    constructor(address _usdc) MockRWAProtocol(_usdc, "Goldfinch Senior", 600) {}
}