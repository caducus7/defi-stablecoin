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
// function mintDsc(uint256 amount) public {
//     (uint256 totalDscMinted, uint256 totalCollateralValueUsd) = dsce.getAccountInformation(msg.sender);

//     int256 maxDscToMint = 0;
//     if (totalCollateralValueUsd / 2 > totalDscMinted) {
//         maxDscToMint = (int256(totalCollateralValueUsd / 2)) - int256(totalDscMinted);
//     }
//     mintNegative++;

//     if (maxDscToMint < 0) {
//         console.log("Minting skipped: maxDscToMint is non-positive", maxDscToMint);
//         return;
//     }
//     mintBeforeCalls++;
//     amount = bound(amount, 0, uint256(maxDscToMint)); // Use `1` as lower bound if zero is invalid

//     if (amount == 0) return;

//     vm.startPrank(msg.sender);
//     dsce.mintDsc(amount);
//     vm.stopPrank();
//     mintCalls++;
// }
