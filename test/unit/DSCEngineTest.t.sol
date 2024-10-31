//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    uint256 public constant ETH_AMOUNT = 15e18;
    uint256 public constant PRICE = 2000;
    address weth;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant AMOUNT_TO_MINT = 100 ether;
    uint256 public constant AMOUNT_TO_BURN = 10 ether;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    address public LIQUIDATOR = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (weth,, ethUsdPriceFeed, btcUsdPriceFeed,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);
    }

    ////////////////////////////
    /////Constructor Tests//////
    ////////////////////////////

    address[] public tokens;
    address[] public priceFeeds;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokens.push(weth);
        priceFeeds.push(ethUsdPriceFeed);
        priceFeeds.push(btcUsdPriceFeed);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeTheSameLength.selector);
        new DSCEngine(tokens, priceFeeds, address(dsc));
    }

    ////////////////////////////
    /////Price Feed Tests //////
    ////////////////////////////

    function testGetUsdValue() public view {
        uint256 expectedUsd = ETH_AMOUNT * PRICE;

        assert(engine.getUsdValue(weth, ETH_AMOUNT) == expectedUsd);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 expectedTokenAmount = ETH_AMOUNT / PRICE;
        assert(engine.getTokenAmountFromUsd(weth, ETH_AMOUNT) == expectedTokenAmount);
    }

    ////////////////////////////////////
    /////depositCollateral Tests ///////
    ////////////////////////////////////

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testRevertIfCollateralIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert();
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertWithUnapprovedCollateral() public {
        ERC20Mock mockToken = new ERC20Mock("TOK", "TOK", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);

        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        engine.depositCollateral(address(mockToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
        uint256 expectedTotalDscMinted = 0;

        assert(totalDscMinted == expectedTotalDscMinted);
        uint256 expectedDepositAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assert(AMOUNT_COLLATERAL == expectedDepositAmount);
    }

    function testFailDepositWithoutApproval() public {
        uint256 depositAmount = 1 ether;

        vm.startPrank(USER);
        // Do not approve the transfer

        vm.expectRevert("DSCEngine__TransferFailed");
        engine.depositCollateral(address(weth), depositAmount);
        vm.stopPrank();
    }

    // function testReentrancyProtection() public {
    //     uint256 depositAmount = 1 ether;
    //     ERC20Mock mockEth;

    //     // Attempt reentrant call by creating a malicious contract that re-enters the depositCollateral
    //     MaliciousContract maliciousContract = new MaliciousContract(engine, mockEth);
    //     mockEth.mint(address(maliciousContract), depositAmount);

    //     // Attempt reentrancy
    //     vm.expectRevert("ReentrancyGuard: reentrant call");
    //     maliciousContract.attack();
    // }

    ////////////////////////////////////
    /////redeemCollateral Tests ////////
    ////////////////////////////////////

    function testRedeemCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(address(weth), AMOUNT_COLLATERAL);

        console.log("AMOUNT_COLLATERAL:", AMOUNT_COLLATERAL);
        console.log(
            "engine.getCollateralDeposited(USER, address(weth)):",
            engine.getCollateralBalanceOfUser(USER, address(weth))
        );

        uint256 redeemAmount = AMOUNT_COLLATERAL / 2;
        console.log("redeemAmount:", redeemAmount);

        engine.redeemCollateral(address(weth), redeemAmount);

        uint256 userCollateral = engine.getCollateralBalanceOfUser(USER, address(weth));
        console.log("userCollateral:", userCollateral);

        assertEq(userCollateral, AMOUNT_COLLATERAL - redeemAmount);
    }

    //////////////////////////////////////////////////
    /////depositCollateralAndMindDsc Tests////////////
    //////////////////////////////////////////////////

    modifier depositedCollateralAndMintedDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        _;
    }

    function testCanMintWithDepositedCollateral() public depositedCollateralAndMintedDsc {
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, AMOUNT_TO_MINT);
    }

    function testRevertIfHealthFactorIsBroken() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(address(weth), AMOUNT_COLLATERAL);

        // Simulate a situation where the health factor is broken
        // For example, by minting a large amount of DSC
        vm.startPrank(address(deployer));
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__HealthFactorBroken.selector, uint256(0)));
        engine.mintDsc(1000000 ether);
    }

    /////////////////////////////
    //// Burn Tests //// ////////
    /////////////////////////////

    function testBurnDscSuccess() public depositedCollateralAndMintedDsc {
        vm.startPrank(USER);
        dsc.approve(address(engine), AMOUNT_TO_BURN);
        engine.burnDsc(AMOUNT_TO_BURN);
        vm.stopPrank();
        assertEq(dsc.balanceOf(USER), AMOUNT_TO_MINT - AMOUNT_TO_BURN);
        assertEq(dsc.totalSupply(), AMOUNT_TO_MINT - AMOUNT_TO_BURN);
    }

    function testBurnRevertOnZeroAmount() public depositedCollateralAndMintedDsc {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.burnDsc(0);
        vm.stopPrank();
    }

    //liquidation tests//

    function testLiquidate_WhenHealthFactorIsOk_Reverts() public {
        // Arrange
        uint256 startingHealthFactor = 1;
        vm.mockCall(
            address(engine),
            abi.encodeWithSelector(engine.getHealthFactor.selector, USER),
            abi.encode(startingHealthFactor)
        );

        // Act and Assert
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorIsOk.selector);
        engine.liquidate(LIQUIDATOR, USER, 100 ether);
    }

    modifier liquidated() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 userHealthFactor = engine.getHealthFactor(USER);

        ERC20Mock(weth).mint(LIQUIDATOR, collateralToCover);

        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(engine), collateralToCover);
        engine.depositCollateralAndMintDsc(weth, collateralToCover, AMOUNT_TO_MINT);
        dsc.approve(address(engine), AMOUNT_TO_MINT);
        engine.liquidate(weth, USER, AMOUNT_TO_MINT); // We are covering their whole debt
        vm.stopPrank();
        _;
    }

    function testLiquidateSuccess() public liquidated {
        uint256 liquidatorBalance = ERC20Mock(weth).balanceOf(LIQUIDATOR);
        uint256 expectedWeth = engine.getTokenAmountFromUsd(weth, AMOUNT_TO_MINT)
            + (engine.getTokenAmountFromUsd(weth, AMOUNT_TO_MINT) / engine.getLiquidationBonus());

        assertEq(liquidatorBalance, expectedWeth);
    }

    ////////////////////////////////////
    /////healthFactor Tests ////////////
    ////////////////////////////////////

    ////////////////////////////////////
    /////getter Tests //////////////////
    ////////////////////////////////////

    function testGetCollateralTokens() public view {
        address[] memory collateralTokens = engine.getCollateralTokens();
        assertEq(collateralTokens[0], weth);
    }

    uint256 MIN_HEALTH_FACTOR = 1e18;

    function testGetMinHealthFactor() public view {
        uint256 minHealthFactor = engine.getMinHealthFactor();
        assertEq(minHealthFactor, MIN_HEALTH_FACTOR);
    }

    uint256 constant LIQUIDATION_THRESHOLD = 50;

    function testGetLiquidationThreshold() public view {
        uint256 liquidationThreshold = engine.getLiquidationThreshold();
        assertEq(liquidationThreshold, LIQUIDATION_THRESHOLD);
    }

    function testGetAccountCollateralValueFromInformation() public depositedCollateral {
        (, uint256 collateralValue) = engine.getAccountInformation(USER);
        uint256 expectedCollateralValue = engine.getUsdValue(weth, AMOUNT_COLLATERAL);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetCollateralBalanceOfUser() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        uint256 collateralBalance = engine.getCollateralBalanceOfUser(USER, weth);
        assertEq(collateralBalance, AMOUNT_COLLATERAL);
    }

    function testGetAccountCollateralValue() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        uint256 collateralValue = engine.getAccountCollateralValueInUsd(USER);
        uint256 expectedCollateralValue = engine.getUsdValue(weth, AMOUNT_COLLATERAL);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetDsc() public view {
        address dscAddress = engine.getDsc();
        assertEq(dscAddress, address(dsc));
    }

    function testLiquidationPrecision() public view {
        uint256 expectedLiquidationPrecision = 100;
        uint256 actualLiquidationPrecision = engine.getLiquidationPrecision();
        assertEq(actualLiquidationPrecision, expectedLiquidationPrecision);
    }
}

// contract MaliciousContract {
//     DSCEngine public dscEngine;
//     ERC20Mock public token;

//     constructor(DSCEngine _dscEngine, ERC20Mock _token) {
//         dscEngine = _dscEngine;
//         token = _token;
//     }

//     function attack() public {
//         // Approve and deposit to initiate reentrancy
//         token.approve(address(dscEngine), 1 ether);
//         dscEngine.depositCollateral(address(token), 1 ether);
//     }

//     // Fallback function to attempt reentrant deposit
//     fallback() external {
//         dscEngine.depositCollateral(address(token), 1 ether);
//     }
// }
