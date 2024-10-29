//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../src/DSCEngine.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract DeployDSC is Script {
    HelperConfig public helperConfig;
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        helperConfig = new HelperConfig();
        (address weth, address wbtc, address wethUsdPriceFeed, address wbtcUsdPriceFeed, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];
        vm.startBroadcast(deployerKey);
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        dsc.transferOwnership(address(engine)); // transfer ownership of dsc to engine is required for Ownable
        vm.stopBroadcast();

        return (dsc, engine, helperConfig);
    }
}
