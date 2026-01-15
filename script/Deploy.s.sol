// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
// IMPORT UPDATE: Now points to MockUSDY
import "../src/MockUSDY.sol"; 
import "../src/YilnesVault.sol";
import "../src/MockRWAProtocol.sol"; 

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy MockUSDY
        console.log("Deploying MockUSDY...");
        MockUSDY usdy = new MockUSDY();
        console.log("MockUSDY deployed at:", address(usdy));
        
        // 2. Deploy YilnesVault
        console.log("Deploying YilnesVault...");
        YilnesVault vault = new YilnesVault(address(usdy));
        console.log("YilnesVault deployed at:", address(vault));
        
        // 3. Deploy Mock RWA Protocols
        console.log("Deploying Mock RWA Protocols...");
        
        MockOndo ondo = new MockOndo(address(usdy));
        console.log("MockOndo deployed at:", address(ondo));
        
        MockMaple maple = new MockMaple(address(usdy));
        console.log("MockMaple deployed at:", address(maple));
        
        MockCentrifuge centrifuge = new MockCentrifuge(address(usdy));
        console.log("MockCentrifuge deployed at:", address(centrifuge));

        MockGoldfinch goldfinch = new MockGoldfinch(address(usdy));
        console.log("MockGoldfinch deployed at:", address(goldfinch));
        
        vm.stopBroadcast();
        
        // Print Summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("NEXT_PUBLIC_MOCK_USDY_ADDRESS=", address(usdy));
        console.log("NEXT_PUBLIC_YILNES_VAULT_ADDRESS=", address(vault));
        console.log("NEXT_PUBLIC_MOCK_ONDO_ADDRESS=", address(ondo));
        console.log("NEXT_PUBLIC_MOCK_MAPLE_ADDRESS=", address(maple));
        console.log("NEXT_PUBLIC_MOCK_CENTRIFUGE_ADDRESS=", address(centrifuge));
        console.log("NEXT_PUBLIC_MOCK_GOLDFINCH_ADDRESS=", address(goldfinch));
        console.log("========================");
    }
}