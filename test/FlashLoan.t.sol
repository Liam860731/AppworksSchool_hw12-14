// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { FlashLoanSetUp, console2, CToken } from "./helper/FlashLoanSetUp.sol";
import { FlashLoanLiquidate } from "../src/FlashLoanLiquidate.sol";
import { IFlashLoanSimpleReceiver, IPoolAddressesProvider, IPool } from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import { ISwapRouter } from "v3-periphery/interfaces/ISwapRouter.sol";

contract FlashLoanTest is FlashLoanSetUp {    

    IPool public pool;
    FlashLoanLiquidate public flashLoanLiquidate;

    function setUp() public {
        initiallize();

        //部署清算合約，並給予合約初始金額，以便支付手續費
        flashLoanLiquidate = new FlashLoanLiquidate();
        deal(address(USDC), address(flashLoanLiquidate), 100* 10**USDC.decimals());

        //套利合約將全部allowance給予User2
        vm.startPrank(address(flashLoanLiquidate));
        USDC.approve(user2, type(uint256).max);
        vm.stopPrank();
    }

    function testLiquidate() public {
        //進行借款
        _borrow();

        //將 UNI 價格改為 $4 使 User1 產生 Shortfall，並讓 User2 透過 AAVE 的 Flash loan 來借錢清算 User1
        oracle.setUnderlyingPrice(CToken(address(cUNI)), 4 * 10**18);

        //Ｕser2 透過 AAVE 的 Flash loan 借1250顆USDC清算User1
        vm.startPrank(user2);
        flashLoanLiquidate.execute(user1, address(cUSDC), address(cUNI));
        USDC.transferFrom(address(flashLoanLiquidate), user2, USDC.balanceOf(address(flashLoanLiquidate)));

        //User2的USDC餘額減去初始金額100顆USDC後，大約賺63顆USDC
        assertEq(USDC.balanceOf(user2)-100*10**USDC.decimals(), 63638693);
        vm.stopPrank();
        
    }

    function _borrow() public{
        //提供USDC流動性
        vm.startPrank(addLiquidityUser);
        deal(address(USDC), addLiquidityUser, 2500* 10**USDC.decimals());
        USDC.approve(address(cUSDC), type(uint256).max);
        cUSDC.mint(2500* 10**USDC.decimals());
        vm.stopPrank();

        //User1 使用 1000 顆 UNI 作為抵押品借出 2500 顆 USDC
        vm.startPrank(user1);
        deal(address(UNI), user1, 1000 * 10**UNI.decimals());
        UNI.approve(address(cUNI), type(uint256).max);
        cUNI.mint(1000 * 10**UNI.decimals());
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cUNI);
        comptroller.enterMarkets(cTokens);
        cUSDC.borrow(2500 * 10**USDC.decimals());
        vm.stopPrank();
    }

}
