//SPDX-License-Identifier: MIT
// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

/**
 * @title DSCEngine
 * @author Stefanos Kissas
 * @dev DSCEngine is designed to be as minimal as possible and have the tokens maintain a 1 token == $1 peg.
 * This stablecoin has the properties:
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * Out DSC system should always be "overcollateralized". This means that the the value of the collateral should always be greater than value of DSC.
 *
 * Similar to DAI, but without governance, no fees and only backed by wETH and wBTC.
 * @notice This contract is the core of the DSC System. It handles all the logic for mining and redeeming DSC, as well as depositing & withdrawing collateral.
 * @notice This contract is very loosely based on the MakerDAO DSS (DAI) system.
 */
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8//interfaces/AggregatorV3Interface.sol";

contract DSCEngine is ReentrancyGuard {
    /// Errors ///

    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeTheSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorBroken(uint256 healthFactor);
    error DSCEngine__MintFailed();

    /// State Variables ///

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;
    DecentralizedStableCoin private immutable i_dsc;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amount) private s_dscMinted;
    address[] private s_collateralTokens;

    /// Events ///

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    /// Modifiers ///

    modifier MoreThanZero(uint256 value) {
        if (value <= 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    modifier IsAllowedToken(address tokenAddress) {
        if (s_priceFeeds[tokenAddress] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    /// Functions ///

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeTheSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_collateralTokens.push(tokenAddresses[i]);
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /// External Functions ///

    function depositCollateralAndMintDsc() external {}

    function depositCollateralAndMintDscWithCollateral(uint256 amountCollateral) external {}
    /*
     *@notice Follows CEI.
     *@param tokenCollateralAddress The address of the token used for collateral.
     *@param amountCollateral The amount of collateral to deposit.
     */

    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        payable
        MoreThanZero(amountCollateral)
        IsAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    /*
    * @notice Follows CEI.
    * @param amountDscToMint The amount of DSC to mint.
    * @notice they must have more collateral value than the minimum threshold.
    */
    function mintDsc(uint256 amountDscToMint) external MoreThanZero(amountDscToMint) nonReentrant {
        s_dscMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view returns (uint256) {
        return _healthFactor(msg.sender);
    }

    /// Private & Internal View Functions ///

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 totalCollateralValueUsd)
    {
        totalDscMinted = s_dscMinted[user];
        totalCollateralValueUsd = getAccountCollateralValueInUsd(user);
    }

    /**
     * Returns how close to liquidation a user is
     * If a user goes below 1, then they can get liquidated.
     *
     */
    function _healthFactor(address user) internal view returns (uint256) {
        (uint256 totalDscMinted, uint256 totalCollateralValueUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold =
            (LIQUIDATION_THRESHOLD * totalCollateralValueUsd) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorBroken(userHealthFactor);
        }
    }

    /// Public & External View Functions ///

    function getAccountCollateralValueInUsd(address user) public view returns (uint256) {
        uint256 totalCollateralValueUsd = 0;
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}
