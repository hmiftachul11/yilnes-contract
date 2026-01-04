// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMockUSDC is IERC20 {
    function mint(address to, uint256 amount) external;
}

abstract contract MockRWAProtocol is Ownable {
    IMockUSDC public immutable usdc;
    string public name;
    string public symbol;
    uint256 public immutable APY; 
    
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public lastUpdate;
    
    constructor(address _usdc, string memory _name, string memory _symbol, uint256 _apy) Ownable(msg.sender) {
        usdc = IMockUSDC(_usdc);
        name = _name;
        symbol = _symbol;
        APY = _apy;
    }

    function deposit(uint256 amount) external {
        _accrueInterest(msg.sender); 
        require(usdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        deposits[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external {
        _accrueInterest(msg.sender);
        require(deposits[msg.sender] >= amount, "Insufficient balance");
        
        deposits[msg.sender] -= amount;
        
        uint256 contractBalance = usdc.balanceOf(address(this));
        
        if (contractBalance < amount) {
            uint256 shortage = amount - contractBalance;
            usdc.mint(address(this), shortage);
        }
        
        require(usdc.transfer(msg.sender, amount), "Transfer failed");
    }

    function getBalance(address user) public view returns (uint256) {
        uint256 principal = deposits[user];
        if (principal == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - lastUpdate[user];
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