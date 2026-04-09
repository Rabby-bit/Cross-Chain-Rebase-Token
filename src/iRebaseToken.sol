// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface iRebaseToken {
    function mint(address _user, uint256 _amount) external;

    function burn(address _user, uint256 _amount) external;
}
