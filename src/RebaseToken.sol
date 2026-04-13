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

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {iRebaseToken} from "src/iRebaseToken.sol";

contract RebaseToken is ERC20, AccessControl, Ownable, iRebaseToken {
    // State variables
    uint256 private sInterestRate = 5e10;
    uint256 private constant PRECISION_FACTOR = 1e18;
    mapping(address user => uint256 amountMinted) private sUserToAmountMinted;
    mapping(address user => uint256 interestRate) private sUserToInterestRate;
    mapping(address user => uint256 timeStamp) private sUserToLastUpdatedTimeStamp;
    bytes32 public constant BURN_MINTER_ROLE = keccak256("BURN_MINTER_ROLE");

    // Events
    error RebaseToken__InterestRateShouldOnlyDecrease();

    event InterestRateSet(uint256 indexed newInterestRate);
    // Modifiers

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {}

    ///External//
    function mint(address _user, uint256 _amount, uint256 _userInterestRate) external onlyRole(BURN_MINTER_ROLE) {
        _mintAccuredInterest(_user);
        sUserToInterestRate[_user] = _userInterestRate;
        sUserToAmountMinted[_user] += _amount;
        _mint(_user, _amount);
    }

    function burn(address _user, uint256 _amount) external onlyRole(BURN_MINTER_ROLE) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_user);
        }
        _mintAccuredInterest(_user);
        sUserToAmountMinted[_user] -= _amount;
        _burn(_user, _amount);
    }

    function transfer(address _reciepent, uint256 _amount) public override returns (bool) {
        _mintAccuredInterest(_reciepent);
        _mintAccuredInterest(msg.sender);

        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        return super.transfer(_reciepent, _amount);
    }

    function transferFrom(address _sender, address _reciepent, uint256 _amount) public override returns (bool) {
        _mintAccuredInterest(_reciepent);
        _mintAccuredInterest(_sender);

        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }

        return super.transferFrom(_sender, _reciepent, _amount);
    }

    ///Public//
    function setInterestRete(uint256 _newInterestRate) public onlyOwner {
        if (_newInterestRate > sInterestRate) {
            revert RebaseToken__InterestRateShouldOnlyDecrease();
        }
        sInterestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }
    //earlier we talked about storage and storage variables,
    //the line i comment out
    //but do i really update the storage interest to the _newInterfestRate

    function grantRole(bytes32 role, address account) public override onlyOwner {
        _grantRole(BURN_MINTER_ROLE, account);
    }
    //Internal//

    //Private//

    //internal & private view/pure//

    function _mintAccuredInterest(address _user) internal view returns (uint256 increaseInBalance) {
        /// TODO: Implement full logic to calculate and mint actual interest tokens.
        // The amount of interest to mint would be:
        // current_dynamic_balance - current_stored_principal_balance
        // Then, _mint(_user, interest_amount_to_mint);
        uint256 previousPrincipleBalance = super.balanceOf(_user);

        uint256 dynamicBalance = balanceOf(_user);

        increaseInBalance = dynamicBalance - previousPrincipleBalance;
    }

    function _calculateAccumulateInterest(address _user) internal view returns (uint256 linearInterest) {
        uint256 timeElapsed = block.timestamp - sUserToLastUpdatedTimeStamp[_user];
        linearInterest = PRECISION_FACTOR + (sUserToInterestRate[_user] * timeElapsed);
    }

    //external & public view/pure //
    function balanceOf(address _user) public view override returns (uint256) {
        uint256 principleBalance = super.balanceOf(_user);

        uint256 growthFactor = _calculateAccumulateInterest(_user);
        return (principleBalance * growthFactor) / PRECISION_FACTOR;
    }

    function getUserInterestRate(address _user) external view returns (uint256) {
        return sUserToInterestRate[_user];
    }

    function getPrincipalBalance(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    function getInterestRate() external view returns (uint256) {
        return sInterestRate;
    }
}
