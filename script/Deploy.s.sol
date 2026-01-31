// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {YilnesVault} from "../src/YilnesVault.sol";
import {MockOndo, MockMaple, MockCentrifuge, MockGoldfinch} from "../src/MockRWAProtocol.sol";

contract DeployScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy MockUSDC (6 Decimals)
        MockUSDC usdc = new MockUSDC();
        console2.log("MockUSDC deployed at:", address(usdc));

        // 2. Deploy YilnesVault
        YilnesVault vault = new YilnesVault(address(usdc));
        console2.log("YilnesVault deployed at:", address(vault));

        // 3. Deploy Mock Protocols
        MockOndo ondo = new MockOndo(address(usdc));
        console2.log("MockOndo deployed at:", address(ondo));

        MockMaple maple = new MockMaple(address(usdc));
        console2.log("MockMaple deployed at:", address(maple));

        MockCentrifuge centrifuge = new MockCentrifuge(address(usdc));
        console2.log("MockCentrifuge deployed at:", address(centrifuge));

        MockGoldfinch goldfinch = new MockGoldfinch(address(usdc));
        console2.log("MockGoldfinch deployed at:", address(goldfinch));

        vm.stopBroadcast();
    }
}