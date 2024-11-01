//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @notice This library is used to check the Chanilink Oracle for stale data.
 * If a price is stale, the function will revert and render the DSCEngine unusable.
 * We want the DSCEngine to freeze if prices become stale.
 *
 *
 */
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

library OracleLib {
    uint256 private constant TIMEOUT = 3 hours; //10800 seconds

    error OracleLib__StalePrice();

    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - startedAt;
        if (secondsSince > TIMEOUT) {
            revert OracleLib__StalePrice();
        }
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
