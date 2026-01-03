// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Abstract Base for Mocks to reduce code duplication
abstract contract MockRWAProtocol is Ownable {
    IERC20 public immutable usdc;
    string public name;
    string public symbol;
    uint256 public immutable APY; // Basis points (500 = 5%)
    
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public lastUpdate;
    
    constructor(address _usdc, string memory _name, string memory _symbol, uint256 _apy) Ownable(msg.sender) {
        usdc = IERC20(_usdc);
        name = _name;
        symbol = _symbol;
        APY = _apy;
    }

    function deposit(uint256 amount) external {
        _accrueInterest(msg.sender); // Update balance before deposit
        require(usdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        deposits[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external {
        _accrueInterest(msg.sender); // Update balance before withdraw
        require(deposits[msg.sender] >= amount, "Insufficient balance");
        
        deposits[msg.sender] -= amount;
        
        // In a real mock, we need to mint the extra yield USDC to pay the user.
        // For this hackathon, we assume the MockUSDC contract has given this contract enough allowance
        // OR we just transfer what we have. 
        // Simplification: We just transfer back. 
        // To simulate Yield properly, MockUSDC needs to be mintable by these contracts or pre-funded.
        
        require(usdc.transfer(msg.sender, amount), "Transfer failed");
    }

    function getBalance(address user) public view returns (uint256) {
        uint256 principal = deposits[user];
        if (principal == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - lastUpdate[user];
        // Simple Interest: Principal * APY * Time / (10000 * 365 days)
        uint256 interest = (principal * APY * timeElapsed) / (10000 * 365 days);
        return principal + interest;
    }

    function _accrueInterest(address user) internal {
        uint256 newBalance = getBalance(user);
        deposits[user] = newBalance;
        lastUpdate[user] = block.timestamp;
    }
}

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