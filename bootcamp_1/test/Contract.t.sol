// test/demo.t.sol

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CCIPLocalSimulator, IRouterClient, WETH9, LinkToken, BurnMintERC677Helper} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {CrossChainNameServiceRegister} from "../src/CrossChainNameServiceRegister.sol";
import {CrossChainNameServiceReceiver} from "../src/CrossChainNameServiceReceiver.sol";
import {CrossChainNameServiceLookup} from "../src/CrossChainNameServiceLookup.sol";

contract Demo is Test {
    CCIPLocalSimulator public ccipLocalSimulator;

    CrossChainNameServiceRegister public register;
    CrossChainNameServiceReceiver public receiver;
    CrossChainNameServiceLookup public registerLookup; 
    CrossChainNameServiceLookup public receiverLookup; 

    function setUp() public {
        ccipLocalSimulator = new CCIPLocalSimulator();

        (
            uint64 chainSelector,
            IRouterClient sourceRouter,
            IRouterClient destinationRouter,
            WETH9 wrappedNative,
            LinkToken linkToken,
            BurnMintERC677Helper ccipBnM,
            BurnMintERC677Helper ccipLnM
        ) = ccipLocalSimulator.configuration();

        registerLookup = new CrossChainNameServiceLookup();
 
        receiverLookup = new CrossChainNameServiceLookup();

        register = new CrossChainNameServiceRegister(address(sourceRouter), address(registerLookup));
        receiver = new CrossChainNameServiceReceiver(address(destinationRouter), address(receiverLookup), chainSelector);

        registerLookup.setCrossChainNameServiceAddress(address(register));
        receiverLookup.setCrossChainNameServiceAddress(address(receiver));

        uint256 gasLimit = 5 ether;
        ccipLocalSimulator.requestLinkFromFaucet(address(register), gasLimit);
        ccipBnM.drip(address(register));

        register.enableChain(chainSelector, address(receiver), gasLimit);
        // ccipLocalSimulator.requestLinkFromFaucet(receiver, amount);
    }

    function test() public {
        register.register("alice.ccns");

        address eoa = receiverLookup.lookup("alice.ccns");
        assertEq(eoa, address(this));
    }
}