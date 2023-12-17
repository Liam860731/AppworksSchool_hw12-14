// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { CToken } from "compound-protocol/CToken.sol";
import { CErc20}  from "compound-protocol/CErc20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IPoolAddressesProvider, IPool } from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import { ISwapRouter } from 'v3-periphery/interfaces/ISwapRouter.sol';

// TODO: Inherit IFlashLoanSimpleReceiver
contract FlashLoanLiquidate  {

    struct Callbackdata {
        address borrower;
        address cUSDC;
        address cUNI;
    }

    ERC20 public USDC = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ERC20 public UNI = ERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    address constant POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    IPool public pool;
    ISwapRouter public immutable swapRouter;

    constructor(){
        swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        pool = POOL();
    }

    function execute(address borrower, address cUSDC, address cUNI) external {

        Callbackdata memory data = Callbackdata(borrower, cUSDC, cUNI);
        //利用FlashLoan借1250顆USDC，清算User1
        pool.flashLoanSimple(
            address(this),
            address(USDC),
            1250 * 10**USDC.decimals(),
            abi.encode(data),
            0
        );

    }

    function executeOperation(address asset, uint256 amount, uint256 premium, address initiator,bytes calldata params) external returns (bool){
        //進行清算並redeem
        Callbackdata memory callbackData = abi.decode(params, (Callbackdata));
        CErc20 cUSDC = CErc20(callbackData.cUSDC);
        CErc20 cUNI = CErc20(callbackData.cUNI);
        USDC.approve(address(cUSDC), type(uint256).max);
        cUSDC.liquidateBorrow(callbackData.borrower, 1250 * 10**USDC.decimals()  , cUNI);
        cUNI.redeem(cUNI.balanceOf(address(this)));

        //將清算完得到的UNI轉成USDC(還給pool要用USDC)
        ISwapRouter.ExactInputSingleParams memory swapParams =
        ISwapRouter.ExactInputSingleParams({
            tokenIn: address(UNI),
            tokenOut: address(USDC),
            fee: 3000, // 0.3%
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: UNI.balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        UNI.approve(address(swapRouter), type(uint256).max);
        swapRouter.exactInputSingle(swapParams);

        //FlashLoan套利完要還回USDC給pool
        ERC20(USDC).approve(address(pool), type(uint256).max);
        return true;
    }

    function ADDRESSES_PROVIDER() public view returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER);
    }

    function POOL() public view returns (IPool) {
        return IPool(ADDRESSES_PROVIDER().getPool());
    }
}
