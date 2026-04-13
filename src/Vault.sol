// SPDX-License-Identifier: MIT

// Layout of Contract:
// license
// version
// imports
// errors
// interfaces, libraries, contracts
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
// internal & private view & pure functions
// external & public view & pure functions

pragma solidity ^0.8.24;

import {RebaseToken} from "src/RebaseToken.sol";
import {iRebaseToken} from "src/iRebaseToken.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract Vault is ReentrancyGuard, AccessControl {
    // State variables
    iRebaseToken public immutable i_rebaseToken;

    mapping(address user => uint256 amountDeposited) private sUserToAmountDeposited;

    // Events
    error Vault__CantDepositZero();
    error Vault__CantRedeemZero();
    error Vault__WithDrawFailed();
    error Vault__DepositTransferFailed();
    error Vault__CantMoreThanDeposited();

    event Deposited(address indexed user, uint256 indexed amount);
    event Redeemed(address indexed user, uint256 indexed amount);

    // Modifiers

    // constructor
    constructor(iRebaseToken rebaseTokenAddress) {
        i_rebaseToken = rebaseTokenAddress;
    }
    // receive function
    receive() external payable {}

    function deposit() external payable {
        if (msg.value == 0) {
            revert Vault__CantDepositZero();
        }
        uint256 userInterestRate = i_rebaseToken.getUserInterestRate(msg.sender);

        if (userInterestRate == 0) {
            userInterestRate = i_rebaseToken.getInterestRate(); // define this
        }

        sUserToAmountDeposited[msg.sender] += msg.value;
        i_rebaseToken.mint(msg.sender, msg.value, userInterestRate);

        emit Deposited(msg.sender, msg.value);
    }

    function redeem(uint256 _amount) external payable nonReentrant {
        if (_amount == 0) {
            revert Vault__CantRedeemZero();
        }
        if (sUserToAmountDeposited[msg.sender] < _amount) {
            revert Vault__CantMoreThanDeposited();
        }

        sUserToAmountDeposited[msg.sender] -= _amount;
        i_rebaseToken.burn(msg.sender, _amount);

        (bool success,) = msg.sender.call{value: _amount}("");
        if (!success) {
            revert Vault__WithDrawFailed();
        }
        emit Redeemed(msg.sender, _amount);
    }
}
