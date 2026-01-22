// SPDX-License-Identifier: MIT

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

pragma solidity 0.8.24;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/*
* @title RebaseToken
* @author Jimmy
* @notice This is a cross-chain rebase token that incentivises users to deposit into a vault
* @notice The interest rate in tne smart contract can only decrease
* @notice Each user will have their interest rate that is global interest rate at the time of depositting
*/
contract RebaseToken is ERC20 {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") {}

    /**
     * @notice Set the interest rate in the contract
     * @param _newInterestRate The interest rate to set
     * @dev The interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external {
        // set the interest rate

        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice Mint the user tokens when they deposit into the vault
     * @param _to The user to mint tokens to
     * @param _amount The amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /**
     * calculate the balance for the user including the interest that has accumulated since the last update
     * (principle balance) + some interest that has accrued
     * @param _user The user to calculate the balance for
     * @return The balance of the user including the interest that has accumulated since the last update
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principle balance of the user (the numbers of token that have actually been minted to the user)
        // multiply the principle balance by the interest that has accumulated in the time since the balance was last updated
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /**
     * @notice Calculate the interest that has accumlated since the last updated
     * @param _user The user to calculate the interest accumlated for
     * @return The interest that has accumlated since the last update
     */
    function _calculateUserAccumlatedInterestSinceLastUpdated(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        // we need to calculate the interest that has accumlated since the last updated
        // this is going to be linear growth with time
        // 1. calculate the time since last updated
        // 2. calculate the amount of linear growth
        // (principal amount) + (principal amount * user interest rate * time elapsed)
        //  = (principal amount) * (1 + user interest rate * time elapsed)
        // deposit: 10 tokens, interest rate: 0.5 tokens per token per second, time elapsed is 2 seconds
        // 10 + (10 * 0.5 * 2) = 10 + 10 = 20
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        uint256 linearInterest = (PRECISION_FACTOR + s_userInterestRate[_user] * timeElapsed);
        return linearInterest;
    }

    function _mintAccruedInterest(address _user) internal {
        // (1) find their current balance of rebase tokens that have been minted to the user -> principle
        // (2) calculate their current balance including their interest -> balanceOf
        // calculate the number of tokens that need to be minted to the user -> (2) - (1)
        // call _mint to mint the tokens to the user
        // set the user last updated timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
    }

    /*
    * @notice Get the interest rate for the user
    * @param _user The user to get the interest rate for
    * @return The interest rate for the user
    */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
