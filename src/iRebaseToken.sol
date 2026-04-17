// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface iRebaseToken {
    function mint(address _user, uint256 _amount, uint256 _interestRate) external;

    function burn(address _user, uint256 _amount) external;

    function getUserInterestRate(address _user) external view returns (uint256);

    function getInterestRate() external view returns (uint256);

    // function grantRole( address account) public onlyOwner {
    //     _grantRole(BURN_MINTER_ROLE, account);
    // }

    // function grantRole(bytes32 role, address account) external  onlyOwner;
}
