// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/interfaces/IERC20.sol";

/**
 * @title MockOndoProtocol
 * @dev Mock implementation of Ondo Finance OUSG protocol
 */
contract MockOndoProtocol {
    IERC20 public immutable usdc;
    string public name = "Ondo US Dollar Yield";
    string public symbol = "OUSY";
    uint256 public constant APY = 500; // 5% APY
    
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public depositTime;
    
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    
    constructor(address _usdc) {
        usdc = IERC20(_usdc);
    }
    
    function deposit(uint256 amount) external {
        require(usdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        deposits[msg.sender] += amount;
        depositTime[msg.sender] = block.timestamp;
        emit Deposit(msg.sender, amount);
    }
    
    function withdraw(uint256 amount) external {
        require(deposits[msg.sender] >= amount, "Insufficient balance");
        deposits[msg.sender] -= amount;
        require(usdc.transfer(msg.sender, amount), "Transfer failed");
        emit Withdraw(msg.sender, amount);
    }
    
    function getBalance(address user) external view returns (uint256) {
        return deposits[user];
    }
}

/**
 * @title MockMapleProtocol  
 * @dev Mock implementation of Maple Finance protocol
 */
contract MockMapleProtocol {
    IERC20 public immutable usdc;
    string public name = "Maple Credit Pool";
    string public symbol = "MCP";
    uint256 public constant APY = 800; // 8% APY
    
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public depositTime;
    
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    
    constructor(address _usdc) {
        usdc = IERC20(_usdc);
    }
    
    function deposit(uint256 amount) external {
        require(usdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        deposits[msg.sender] += amount;
        depositTime[msg.sender] = block.timestamp;
        emit Deposit(msg.sender, amount);
    }
    
    function withdraw(uint256 amount) external {
        require(deposits[msg.sender] >= amount, "Insufficient balance");
        deposits[msg.sender] -= amount;
        require(usdc.transfer(msg.sender, amount), "Transfer failed");
        emit Withdraw(msg.sender, amount);
    }
    
    function getBalance(address user) external view returns (uint256) {
        return deposits[user];
    }
}

/**
 * @title MockCentrifugeProtocol
 * @dev Mock implementation of Centrifuge protocol
 */
contract MockCentrifugeProtocol {
    IERC20 public immutable usdc;
    string public name = "Centrifuge Real Estate Pool";
    string public symbol = "CREP";
    uint256 public constant APY = 1200; // 12% APY
    
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public depositTime;
    
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    
    constructor(address _usdc) {
        usdc = IERC20(_usdc);
    }
    
    function deposit(uint256 amount) external {
        require(usdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        deposits[msg.sender] += amount;
        depositTime[msg.sender] = block.timestamp;
        emit Deposit(msg.sender, amount);
    }
    
    function withdraw(uint256 amount) external {
        require(deposits[msg.sender] >= amount, "Insufficient balance");
        deposits[msg.sender] -= amount;
        require(usdc.transfer(msg.sender, amount), "Transfer failed");
        emit Withdraw(msg.sender, amount);
    }
    
    function getBalance(address user) external view returns (uint256) {
        return deposits[user];
    }
}

/**
 * @title MockGoldfinchProtocol
 * @dev Mock implementation of Goldfinch protocol
 */
contract MockGoldfinchProtocol {
    IERC20 public immutable usdc;
    string public name = "Goldfinch Senior Pool";
    string public symbol = "GSP";
    uint256 public constant APY = 600; // 6% APY
    
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public depositTime;
    
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    
    constructor(address _usdc) {
        usdc = IERC20(_usdc);
    }
    
    function deposit(uint256 amount) external {
        require(usdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        deposits[msg.sender] += amount;
        depositTime[msg.sender] = block.timestamp;
        emit Deposit(msg.sender, amount);
    }
    
    function withdraw(uint256 amount) external {
        require(deposits[msg.sender] >= amount, "Insufficient balance");
        deposits[msg.sender] -= amount;
        require(usdc.transfer(msg.sender, amount), "Transfer failed");
        emit Withdraw(msg.sender, amount);
    }
    
    function getBalance(address user) external view returns (uint256) {
        return deposits[user];
    }
}