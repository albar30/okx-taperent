// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/TapeRent.sol";
import "../contracts/MockCircuit.sol";

/// @notice Deploy TapeRent (and MockCircuit on testnet) to X Layer.
///         Usage (testnet Terigon, chain 1952):
///           export PRIVATE_KEY=<throwaway testnet deployer key>
///           forge script script/Deploy.s.sol --rpc-url xlayer_testnet --broadcast
///         Mainnet (chain 196) — ONLY after a separate preview + user approval:
///           forge script script/Deploy.s.sol --rpc-url xlayer --broadcast
///         The deployer becomes the contract owner (fee config) and the
///         initial feeRecipient. Change it afterwards with setFeeRecipient().
contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        TapeRent rent = new TapeRent(deployer);
        console.log("TapeRent deployed at:", address(rent));
        console.log("feeBps:", rent.feeBps());
        console.log("feeRecipient:", rent.feeRecipient());

        // X Layer testnet (1952) has NO TapeOut factory — deploy the mock so
        // the demo marketplace has circuits to list. Never deploy the mock
        // to mainnet; mainnet uses the real TapeOut circuits.
        if (block.chainid == 1952) {
            MockCircuit mock = new MockCircuit();
            console.log("MockCircuit (DEMO ONLY) deployed at:", address(mock));
        }

        vm.stopBroadcast();
    }
}
