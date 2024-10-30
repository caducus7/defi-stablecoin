// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.18;

// import {Test} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DeployDSC} from "../../script/DeployDSC.s.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract InvariantsTest is StdInvariant, Test {
//     DecentralizedStableCoin dsc;
//     DSCEngine dsce;
//     HelperConfig config;
//     address weth;
//     address wbtc;

//     function setUp() public {
//         DeployDSC deployer = new DeployDSC();
//         (dsc, dsce, config) = deployer.run();
//         (weth, wbtc,,,) = config.activeNetworkConfig();
//         // set the target contract
//         targetContract(address(dsce));
//     }
// }
