// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MockUSDC.sol";
import "../src/YilnesVault.sol";
import "../src/MockRWAProtocols.sol";

contract DeployScript is Script {
    function run() external {
        // Get deployment key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy MockUSDC
        console.log("Deploying MockUSDC...");
        MockUSDC usdc = new MockUSDC();
        console.log("MockUSDC deployed at:", address(usdc));
        
        // 2. Deploy YilnesVault
        console.log("Deploying YilnesVault...");
        YilnesVault vault = new YilnesVault(address(usdc));
        console.log("YilnesVault deployed at:", address(vault));
        
        // 3. Deploy Mock RWA Protocols
        console.log("Deploying Mock RWA Protocols...");
        
        MockOndoProtocol ondo = new MockOndoProtocol(address(usdc), address(vault));
        console.log("MockOndoProtocol deployed at:", address(ondo));
        
        MockMapleProtocol maple = new MockMapleProtocol(address(usdc), address(vault));
        console.log("MockMapleProtocol deployed at:", address(maple));
        
        MockCentrifugeProtocol centrifuge = new MockCentrifugeProtocol(address(usdc), address(vault));
        console.log("MockCentrifugeProtocol deployed at:", address(centrifuge));
        
        MockGoldfinchProtocol goldfinch = new MockGoldfinchProtocol(address(usdc), address(vault));
        console.log("MockGoldfinchProtocol deployed at:", address(goldfinch));
        
        // 4. Add protocols to vault
        console.log("Adding protocols to vault...");
        vault.addProtocol(address(ondo), 2500);      // 25%
        vault.addProtocol(address(maple), 2500);     // 25%
        vault.addProtocol(address(centrifuge), 2500); // 25%
        vault.addProtocol(address(goldfinch), 2500);  // 25%
        
        vm.stopBroadcast();
        
        // Print deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network: Mantle Sepolia Testnet (5003)");
        console.log("MockUSDC:", address(usdc));
        console.log("YilnesVault:", address(vault));
        console.log("MockOndoProtocol:", address(ondo));
        console.log("MockMapleProtocol:", address(maple));
        console.log("MockCentrifugeProtocol:", address(centrifuge));
        console.log("MockGoldfinchProtocol:", address(goldfinch));
        console.log("========================");
    }
}