// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import { Test, console2 } from "forge-std/Test.sol";
import { CErc20Delegator } from "compound-protocol/CErc20Delegator.sol";
import { Comptroller } from "compound-protocol/Comptroller.sol";
import { WhitePaperInterestRateModel } from "compound-protocol/WhitePaperInterestRateModel.sol";
import { CErc20Delegate } from "compound-protocol/CErc20Delegate.sol";
import { SimplePriceOracle } from "compound-protocol/SimplePriceOracle.sol";
import { Unitroller } from "compound-protocol/Unitroller.sol";
import { CToken } from "compound-protocol/CToken.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IPoolAddressesProvider, IPool } from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";

contract FlashLoanSetUp is Test {
    CErc20Delegator public cErc20Delegator1;
    CErc20Delegator public cErc20Delegator2;
    CErc20Delegator public cUSDC;
    CErc20Delegator public cUNI;
    CErc20Delegate public implementation;
    Comptroller public comptroller;
    WhitePaperInterestRateModel public interestRateModel;
    ERC20 public USDC = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ERC20 public UNI = ERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    IPoolAddressesProvider public POOL_ADDRESSES_PROVIDER = IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
    address public admin;
    address public user1;
    address public user2;
    address public addLiquidityUser;

    Unitroller public unitroller;  
    SimplePriceOracle public oracle;

    function initiallize() internal {
        vm.createSelectFork("https://mainnet.infura.io/v3/944d422c26d44000988fc92104bf51b8");
        vm.rollFork(17_465_000);

        admin = makeAddr("Admin");
        user1 = makeAddr("User1");
        user2 = makeAddr("User2");
        addLiquidityUser = makeAddr("AddLiquidityUser");

        vm.startPrank(admin);
        comptroller = new Comptroller();
        interestRateModel = new WhitePaperInterestRateModel(0,0);
        implementation = new CErc20Delegate();
        oracle = new SimplePriceOracle();
        unitroller = new Unitroller();

        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);
        comptroller._setPriceOracle(oracle);

        cErc20Delegator1 = new CErc20Delegator(
                address(USDC),
                comptroller,
                interestRateModel,
                1*10**18,
                "Compound USDC Token",
                "cUSDC",
                18,
                payable(msg.sender),
                address(implementation),
                new bytes(0)
        );

        cErc20Delegator2 = new CErc20Delegator(
                address(UNI),
                comptroller,
                interestRateModel,
                1*10**18,
                "Compound Uniswap Token",
                "cUNI",
                18,
                payable(msg.sender),
                address(implementation),
                new bytes(0)
        );

        cUSDC = CErc20Delegator(cErc20Delegator1);
        cUNI = CErc20Delegator(cErc20Delegator2);

        comptroller._supportMarket(CToken(address(cUSDC)));
        comptroller._supportMarket(CToken(address(cUNI)));

        //Close factor 設定為 50%
        comptroller._setCloseFactor(5 * 1e17);

        //在 Oracle 中設定 USDC 的價格為 $1，UNI 的價格為 $5
        oracle.setUnderlyingPrice(CToken(address(cUSDC)), 1 * 1e30);
        oracle.setUnderlyingPrice(CToken(address(cUNI)), 5 * 1e18);

        //設定 UNI 的 collateral factor 為 50%
        comptroller._setCollateralFactor(CToken(address(cUNI)),  5 * 1e17);

        //Liquidation incentive 設為 8% (1.08 * 1e18)
        comptroller._setLiquidationIncentive(1.08 * 1e18);

        vm.stopPrank();
        
    }
}