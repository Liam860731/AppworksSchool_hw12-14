// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console2 } from "forge-std/Test.sol";
import { CompoundScript, CToken } from "../script/Compound.s.sol";

contract CompoundTest is Test, CompoundScript {

    address public admin;
    address public user1;
    address public user2;
    address public addLiquidityUser;

    function setUp() public {
        admin = makeAddr("Admin");
        user1 = makeAddr("User1");
        user2 = makeAddr("User2");
        addLiquidityUser = makeAddr("AddLiquidityUser");
        vm.startPrank(admin);
        _setUp();
        oracle.setUnderlyingPrice(CToken(address(cTKNA)), 1 * 10**18);
        oracle.setUnderlyingPrice(CToken(address(cTKNB)), 100 * 10**18);
        comptroller._setCollateralFactor(CToken(address(cTKNB)),  5 * 10**17);
        comptroller._setCloseFactor(5 * 10**17);
        comptroller._setLiquidationIncentive(1.08 * 10**18);
        vm.stopPrank();
    }
    function test_mint_redeem() public {
        vm.startPrank(user1);

        deal(address(tokenA), user1, 100*10**tokenA.decimals());
        uint256 beforeMintAmount = tokenA.balanceOf(user1);
        tokenA.approve(address(cTKNA), 100*10**tokenA.decimals());
        cTKNA.mint(100*10**tokenA.decimals());
        cTKNA.redeem(100*10**tokenA.decimals());
        uint256 afterRedeemAmount = tokenA.balanceOf(user1);

        assertEq(beforeMintAmount, afterRedeemAmount);
        vm.stopPrank();
        
    }
    function test_borrow_repay() public {
        _borrowInternal();
        assertEq(tokenA.balanceOf(user1), 50 * 10**tokenA.decimals());

        vm.startPrank(user1);
        tokenA.approve(address(cTKNA), 50 * 10**tokenA.decimals());
        cTKNA.repayBorrow(50 * 10**tokenA.decimals());
        assertEq(tokenA.balanceOf(user1), 0);
        vm.stopPrank();
    }

    function test_liquidate_by_collateral_factor() public {
        _borrowInternal();
        deal(address(tokenA), user2, 100 * 10**tokenA.decimals());
        uint beforeTokenaBalacne = tokenA.balanceOf(user2);
        uint beforeCTokenbBalacne = cTKNB.balanceOf(user2);

        vm.prank(admin);
        comptroller._setCollateralFactor(CToken(address(cTKNB)), 4 * 10**17);

        vm.startPrank(user2);
        tokenA.approve(address(cTKNA), type(uint256).max);
        (,,uint shartfall ) = comptroller.getAccountLiquidity(user1);
        assertGt(shartfall, 0);
        uint256 borrowBalanceA = cTKNA.borrowBalanceCurrent(user1);
        cTKNA.liquidateBorrow(user1, borrowBalanceA / 2, cTKNB);
        uint afterTokenaBalacne = tokenA.balanceOf(user2);
        uint afterCTokenbBalacne = cTKNB.balanceOf(user2);
        assertGt(beforeTokenaBalacne, afterTokenaBalacne);
        assertLt(beforeCTokenbBalacne, afterCTokenbBalacne);
        vm.stopPrank();
    }

    function test_liquidate_by_tokenB_balance() public {
        _borrowInternal();
        deal(address(tokenA), user2, 100 * 10**tokenA.decimals());
        uint beforeTokenaBalacne = tokenA.balanceOf(user2);
        uint beforeCTokenbBalacne = cTKNB.balanceOf(user2);
        
        vm.prank(admin);
        oracle.setUnderlyingPrice(CToken(address(cTKNB)), 80 * 10**18);

        vm.startPrank(user2);
        tokenA.approve(address(cTKNA), type(uint256).max);
        (,,uint shartfall ) = comptroller.getAccountLiquidity(user1);
        assertGt(shartfall, 0);
        uint256 borrowBalanceA = cTKNA.borrowBalanceCurrent(user1);
        cTKNA.liquidateBorrow(user1, borrowBalanceA / 2, cTKNB);
        uint afterTokenaBalacne = tokenA.balanceOf(user2);
        uint afterCTokenbBalacne = cTKNB.balanceOf(user2);
        assertGt(beforeTokenaBalacne, afterTokenaBalacne);
        assertLt(beforeCTokenbBalacne, afterCTokenbBalacne);
        vm.stopPrank();
    }

    function _borrowInternal () internal {
        vm.startPrank(addLiquidityUser);
        deal(address(tokenA), addLiquidityUser, 50*10**tokenA.decimals());
        tokenA.approve(address(cTKNA), 50*10**tokenA.decimals());
        cTKNA.mint(50*10**tokenA.decimals());
        vm.stopPrank();

        vm.startPrank(user1);
        deal(address(tokenB), user1, 1 * 10**tokenB.decimals());
        tokenB.approve(address(cTKNB), 1 * 10**tokenB.decimals());
        cTKNB.mint(1 * 10**tokenB.decimals());

        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cTKNB);
        comptroller.enterMarkets(cTokens);
        cTKNA.borrow(50 * 10**tokenA.decimals());
        vm.stopPrank();
    }
}
