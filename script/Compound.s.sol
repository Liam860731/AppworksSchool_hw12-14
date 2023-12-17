// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Script, console2 } from "forge-std/Script.sol";
import { CErc20Delegator } from "compound-protocol/CErc20Delegator.sol";
import { Comptroller } from "compound-protocol/Comptroller.sol";
import { WhitePaperInterestRateModel } from "compound-protocol/WhitePaperInterestRateModel.sol";
import { CErc20Delegate } from "compound-protocol/CErc20Delegate.sol";
import { SimplePriceOracle } from "compound-protocol/SimplePriceOracle.sol";
import { Unitroller } from "compound-protocol/Unitroller.sol";
import { CToken } from "compound-protocol/CToken.sol";
import { TokenA, TokenB } from "../src/Erc20Token.sol";

contract CompoundScript is Script {
    CErc20Delegator public cErc20Delegator1;
    CErc20Delegator public cErc20Delegator2;
    CErc20Delegator public cTKNA;
    CErc20Delegator public cTKNB;
    CErc20Delegate public implementation;
    Comptroller public comptroller;
    WhitePaperInterestRateModel public interestRateModel;
    TokenA public tokenA;
    TokenB public tokenB;
    Unitroller public unitroller;  
    SimplePriceOracle public oracle;

    function run() public {
        vm.startBroadcast();
        _setUp();
        vm.stopBroadcast();
    }

    function _setUp() internal {
        comptroller = new Comptroller();
        interestRateModel = new WhitePaperInterestRateModel(0,0);
        implementation = new CErc20Delegate();
        tokenA = new TokenA();
        tokenB = new TokenB();
        oracle = new SimplePriceOracle();
        unitroller = new Unitroller();

        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);
        comptroller._setPriceOracle(oracle);

        cErc20Delegator1 = new CErc20Delegator(
                address(tokenA),
                comptroller,
                interestRateModel,
                1*10**18,
                "Compound Token A",
                "cTKNA",
                18,
                payable(msg.sender),
                address(implementation),
                new bytes(0)
        );

        cErc20Delegator2 = new CErc20Delegator(
                address(tokenB),
                comptroller,
                interestRateModel,
                1*10**18,
                "Compound Token B",
                "cTKNB",
                18,
                payable(msg.sender),
                address(implementation),
                new bytes(0)
        );
        cTKNA = CErc20Delegator(cErc20Delegator1);
        cTKNB = CErc20Delegator(cErc20Delegator2);
        comptroller._supportMarket(CToken(address(cTKNA)));
        comptroller._supportMarket(CToken(address(cTKNB)));
        
    }
}
