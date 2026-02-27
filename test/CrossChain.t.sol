// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";

import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

import {CCIPLocalSimulatorFork} from "lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";


contract CrossChainTest is Test {
    address constant owner = makeAddr("owner");
    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;

    Vault vault;

    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia");
        arbSepoliaFork = vm.createFork("arb-sepolia");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // 1. Depoly and configure on Sepolia
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(sepoliaToken));
        vm.stopPrank();

        // 2. Depoly and configure on Arbitrum Sepolia
        vm.selectFork(arbSepoliaFork);
        arbSepoliaToken = new RebaseToken();
        vm.startPrank(owner);
        vm.stopPrank();
    }


}
