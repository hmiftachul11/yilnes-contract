// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract YilnesVault is Ownable, ReentrancyGuard {
    IERC20 public immutable asset; // This will be USDC
    
    uint256 public constant ANNUAL_PREMIUM_RATE_BPS = 250;
    uint256 public constant MAX_COVER_DAYS = 365;
    uint256 public constant MIN_COVER_DAYS = 28;
    
    uint256 public insuranceReserve;
    uint256 public totalInvested;    
    
    mapping(address => uint256) public userPrincipal;
    mapping(address => uint256) public userCoverExpiry;
    
    mapping(address => uint256) public lastClaimTime;
    
    event Deposit(address indexed user, uint256 principal, uint256 premiumPaid, uint256 coverDuration);
    event Withdraw(address indexed user, uint256 amount);
    event ClaimYield(address indexed user, uint256 amount);
    event ReserveFunded(uint256 amount);
    
    constructor(address _asset) Ownable(msg.sender) {
        asset = IERC20(_asset);
    }

    function deposit(uint256 amount, uint256 coverDurationDays) external nonReentrant {
        require(amount > 0, "Invalid amount");
        require(asset.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // If user already has principal, we ideally claim yield first, 
        // but for Hackathon simplicity we just reset the timer if they claim manually.
        if (userPrincipal[msg.sender] == 0) {
             lastClaimTime[msg.sender] = block.timestamp;
        }

        uint256 investedAmount = amount;
        uint256 premium = 0;

        if (coverDurationDays >= MIN_COVER_DAYS) {
            if (coverDurationDays > MAX_COVER_DAYS) coverDurationDays = MAX_COVER_DAYS;
            
            // Calculate Premium
            premium = (amount * ANNUAL_PREMIUM_RATE_BPS * coverDurationDays) / (10000 * 365);
            require(premium < amount, "Premium exceeds principal");
            
            investedAmount = amount - premium;
            insuranceReserve += premium;
            userCoverExpiry[msg.sender] = block.timestamp + (coverDurationDays * 1 days);
            
            emit ReserveFunded(premium);
        } else {
            userCoverExpiry[msg.sender] = 0; 
        }

        userPrincipal[msg.sender] += investedAmount;
        totalInvested += investedAmount;
        
        emit Deposit(msg.sender, investedAmount, premium, coverDurationDays);
    }
    
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Invalid amount");
        require(amount <= userPrincipal[msg.sender], "Exceeds principal");
        
        userPrincipal[msg.sender] -= amount;
        totalInvested -= amount;
        
        require(asset.transfer(msg.sender, amount), "Transfer Out Failed");
        
        emit Withdraw(msg.sender, amount);
    }

    function claimYield() external nonReentrant {
        uint256 yield = getUserPendingYield(msg.sender);
        require(yield > 0, "No yield available");
        
        uint256 balance = asset.balanceOf(address(this));
        
        // Mock Yield: We assume the contract has earned money elsewhere. 
        // If contract balance < yield, we only pay what we have.
        if(balance >= yield) {
            require(asset.transfer(msg.sender, yield), "Yield Transfer Failed");
            lastClaimTime[msg.sender] = block.timestamp;
            emit ClaimYield(msg.sender, yield);
        }
    }

    function isCovered(address user) external view returns (bool) {
        return userCoverExpiry[user] > block.timestamp;
    }
    
    function getUserPendingYield(address user) public view returns (uint256) {
        uint256 principal = userPrincipal[user];
        if (principal == 0) return 0;
        
        uint256 lastTime = lastClaimTime[user];
        if (lastTime == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - lastTime;
        
        // 12% APY (1200 BPS)
        return (principal * 1200 * timeElapsed) / (10000 * 365 days);
    }
    
    function getTVL() external view returns (uint256) { return totalInvested; }

    function getAPY() external pure returns (uint256) { return 1200; }
}