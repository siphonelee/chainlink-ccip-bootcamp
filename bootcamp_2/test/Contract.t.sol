// test/demo.t.sol

pragma solidity ^0.8.19;

import {Test, console, Vm} from "forge-std/Test.sol";
import {BurnMintERC677} from "@chainlink/contracts-ccip/src/v0.8/shared/token/ERC677/BurnMintERC677.sol";
import {MockCCIPRouter} from "@chainlink/contracts-ccip/src/v0.8/ccip/test/mocks/MockRouter.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {TransferUSDC} from "../src/TransferUSDC.sol";
import {CrossChainReceiver} from "../src/CrossChainReceiver.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {CCIPLocalSimulator, IRouterClient, LinkToken, BurnMintERC677Helper} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";

contract Demo is Test {
    TransferUSDC public transfer;
    CrossChainReceiver public receiver;

    CCIPLocalSimulator public ccipLocalSimulator;
    BurnMintERC677Helper public ccipBnMToken;   
    uint64 public destinationChainSelector;

    /// @dev Sets up the testing environment by deploying necessary contracts and configuring their states.
    function setUp() public {        
        ccipLocalSimulator = new CCIPLocalSimulator();
        (uint64 chainSelector, 
            IRouterClient sourceRouter, 
            IRouterClient destinationRouter,
            , 
            LinkToken link,
            BurnMintERC677Helper ccipBnM,) = ccipLocalSimulator.configuration();

        destinationChainSelector = chainSelector;
        ccipBnMToken = ccipBnM;

        transfer = new TransferUSDC(address(sourceRouter), address(link), address(ccipBnMToken));
        transfer.allowlistDestinationChain(chainSelector, true);

        receiver = new CrossChainReceiver(address(destinationRouter));
        receiver.allowlistSourceChain(chainSelector, true);
        receiver.allowlistSender(address(transfer), true);
    }

    function test() public {
        ccipLocalSimulator.requestLinkFromFaucet(address(transfer), 5 ether);
        ccipBnMToken.drip(address(transfer));

        vm.recordLogs();  // Starts recording logs to capture events.
        transfer.transferUsdc(destinationChainSelector, address(receiver), 100, 5000000);

        // Fetches recorded logs to check for specific events and their outcomes.
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 msgExecutedSignature = keccak256(
            "MsgExecuted(bool,bytes,uint256)"
        );

        uint256 gasUsed = 0;
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == msgExecutedSignature) {
                (, , gasUsed) = abi.decode(
                    logs[i].data,
                    (bool, bytes, uint256)
                );
                console.log("Gas used (estimation): %d", gasUsed);
            }
        }

        console.log("Suggested gasLimit setting: %d", gasUsed + gasUsed/10);
    }
}