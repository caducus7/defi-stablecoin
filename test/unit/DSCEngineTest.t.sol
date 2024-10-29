//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {Test} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    uint256 public constant ETH_AMOUNT = 15e18;
    uint256 public constant PRICE = 2000;
    address weth;
    address ethUsdPriceFeed;
    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (weth,, ethUsdPriceFeed,,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);
    }

    ////////////////////////////
    /////Price Feed Tests///////
    ////////////////////////////

    function testGetUsdValue() public view {
        uint256 expectedUsd = ETH_AMOUNT * PRICE;
        engine.getUsdValue(weth, ETH_AMOUNT);
        assert(engine.getUsdValue(weth, ETH_AMOUNT) == expectedUsd);
    }

    function testRevertIfCollateralIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert();
        engine.depositCollateral(weth, 0);
    }
}
