// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IRouterClient} from "lib/chainlink-ccip/chains/evm/contracts/interfaces/IRouterClient.sol";
import {Client} from "lib/chainlink-ccip/chains/evm/contracts/libraries/Client.sol";
import {TokenPool, IERC20} from "lib/chainlink-ccip/chains/evm/contracts/pools/TokenPool.sol";



contract BridgeTokensScript is Script {
    function run(address receiverAddress, address linkTokenAddress, uint64 destinationChainSelector, address tokenToSendAddress, uint256 amountToSend, address routerAddress) public {
        vm.startBroadcast();

        
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: tokenToSendAddress, 
            amount: amountToSend 
        });

        // struct EVM2AnyMessage {
        //     bytes receiver; // abi.encode(receiver address) for dest EVM chains.
        //     bytes data; // Data payload.
        //     EVMTokenAmount[] tokenAmounts; // Token transfers.
        //     address feeToken; // Address of feeToken. address(0) means you will send msg.value.
        //     bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV2).
        // }
        // Note: The pool's lockOrBurn will handle encoding the user's interest rate in destPoolData,
        // which becomes sourcePoolData on the destination pool's releaseOrMint call.
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress),
            data: abi.encode("Test Cross Chain Message"), // This can be any data you want to send to the destination chain. The destination chain's pool can decode this data in its releaseOrMint function.
            tokenAmounts: tokenAmounts,
            feeToken: linkTokenAddress,
            extraArgs: Client._argsToBytes(Client.GenericExtraArgsV2({ gasLimit: 1000_000, allowOutOfOrderExecution: true }))
        });
        uint256 ccipFee = IRouterClient(routerAddress).getFee(destinationChainSelector, message);
        IERC20(linkTokenAddress).approve(routerAddress, ccipFee);
        IERC20(tokenToSendAddress).approve(routerAddress, amountToSend);
        IRouterClient(routerAddress).ccipSend(destinationChainSelector, message);

        vm.stopBroadcast();
    }
}