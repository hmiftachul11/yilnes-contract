// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/MockUSDC.sol";
import "../src/YilnesVault.sol";
import "../src/MockRWAProtocols.sol";

contract YilnesVaultTest is Test {
    MockUSDC public usdc;
    YilnesVault public vault;
    MockOndoProtocol public ondo;
    
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    
    function setUp() public {
        // Deploy contracts
        usdc = new MockUSDC();
        vault = new YilnesVault(address(usdc));
        ondo = new MockOndoProtocol(address(usdc));
        
        // Setup test tokens
        usdc.mint(user1, 10000 * 10**6); // 10,000 USDC
        usdc.mint(user2, 5000 * 10**6);  // 5,000 USDC
        
        // Add protocol to vault
        vault.addProtocol(address(ondo), 10000); // 100% allocation
    }
    
    function testDeposit() public {
        uint256 depositAmount = 1000 * 10**6; // 1,000 USDC
        
        vm.startPrank(user1);
        
        // Approve and deposit
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        
        // Check balance
        assertEq(vault.getUserBalance(user1), depositAmount);
        assertEq(vault.getTVL(), depositAmount);
        
        vm.stopPrank();
    }
    
    function testWithdraw() public {
        uint256 depositAmount = 1000 * 10**6; // 1,000 USDC
        
        vm.startPrank(user1);
        
        // Deposit first
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        
        uint256 userShares = vault.userShares(user1);
        uint256 initialBalance = usdc.balanceOf(user1);
        
        // Withdraw half
        vault.withdraw(userShares / 2);
        
        // Check balances
        uint256 finalBalance = usdc.balanceOf(user1);
        assertEq(finalBalance - initialBalance, depositAmount / 2);
        
        vm.stopPrank();
    }
    
    function testFaucet() public {
        address newUser = makeAddr("newUser");
        
        // Skip time to avoid cooldown
        vm.warp(block.timestamp + 25 hours);
        
        uint256 initialBalance = usdc.balanceOf(newUser);
        
        vm.prank(newUser);
        usdc.faucet();
        
        uint256 finalBalance = usdc.balanceOf(newUser);
        assertEq(finalBalance - initialBalance, 1000 * 10**6); // 1000 USDC from faucet
    }
    
    function testMultipleDeposits() public {
        uint256 deposit1 = 500 * 10**6;  // 500 USDC
        uint256 deposit2 = 1000 * 10**6; // 1,000 USDC
        
        // User 1 deposits
        vm.startPrank(user1);
        usdc.approve(address(vault), deposit1);
        vault.deposit(deposit1);
        vm.stopPrank();
        
        // User 2 deposits
        vm.startPrank(user2);
        usdc.approve(address(vault), deposit2);
        vault.deposit(deposit2);
        vm.stopPrank();
        
        // Check total TVL
        assertEq(vault.getTVL(), deposit1 + deposit2);
        
        // Check individual balances
        assertEq(vault.getUserBalance(user1), deposit1);
        assertEq(vault.getUserBalance(user2), deposit2);
    }
    
    function testGetCurrentAPY() public {
        uint256 apy = vault.getCurrentAPY();
        assertEq(apy, 1200); // 12% APY
    }
    
    function test_RevertWhen_DepositZeroAmount() public {
        vm.expectRevert();
        vm.prank(user1);
        vault.deposit(0);
    }
    
    function test_RevertWhen_WithdrawMoreThanBalance() public {
        vm.startPrank(user1);
        usdc.approve(address(vault), 1000 * 10**6);
        vault.deposit(1000 * 10**6);
        
        uint256 userShares = vault.userShares(user1);
        
        vm.expectRevert();
        vault.withdraw(userShares + 1); // Try to withdraw more than owned
        vm.stopPrank();
    }
}