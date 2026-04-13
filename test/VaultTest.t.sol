//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {Vault} from "src/Vault.sol";
import {iRebaseToken} from "src/iRebaseToken.sol";

contract VaultandTokenTest is Test {
    //State variables
    address owner = makeAddr("owner");

    address user = makeAddr("user");

    address user2 = makeAddr("user2");
    RebaseToken rebaseToken;
    Vault vault;
    iRebaseToken irebasetoken;

    function setUp() public {
        vm.deal(user, 100 ether);
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(rebaseToken);
        rebaseToken.grantRole(rebaseToken.BURN_MINTER_ROLE(), address(vault));
        vm.stopPrank();
    }

    function test__deposit() public {
        vm.startPrank(user);
        vm.deal(user, 100 ether);
        vm.expectEmit(true, true, false, false);
        emit Vault.Deposited(user, 1 ether);
        vault.deposit{value: 1 ether}();
        vm.stopPrank();
    }

    function test__depositRevert() public {
        vm.startPrank(user);
        vm.deal(user, 100 ether);
        vm.expectRevert(Vault.Vault__CantDepositZero.selector);
        vault.deposit{value: 0 ether}();
        vm.stopPrank();
    }

    function test__redeem() public {
        vm.startPrank(user);
        vm.deal(user, 100 ether);
        vault.deposit{value: 10 ether}();
        vm.expectEmit(true, true, false, false);
        emit Vault.Redeemed(user, 4);
        vault.redeem(4);

        vm.stopPrank();
    }

    function test__redeemRevertZero() public {
        vm.startPrank(user);
        vm.deal(user, 100 ether);
        vault.deposit{value: 10 ether}();
        vm.expectRevert(Vault.Vault__CantRedeemZero.selector);
        vault.redeem(0);
        vm.stopPrank();
    }

    function test__redeemRevertMoreThanDeposited() public {
        vm.startPrank(user);
        vm.deal(user, 100 ether);
        vault.deposit{value: 10 ether}();
        vm.expectRevert(Vault.Vault__CantMoreThanDeposited.selector);
        vault.redeem(20e18);
        vm.stopPrank();
    }

    function test__mintRevert() public {
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.mint(user2, 2, 4e10);
        vm.stopPrank();
    }

    function test__burnRevert() public {
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.burn(user2, 2);
        vm.stopPrank();
    }

    function test__setInterestRateRevert() public {
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.setInterestRete(5e18);
        vm.stopPrank();
    }

    function test__setInterestRate() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false);
        emit RebaseToken.InterestRateSet(4e10);
        rebaseToken.setInterestRete(4e10);
        vm.stopPrank();
    }

    function test__setInterestRateGreateNo() public {
        vm.startPrank(owner);
        vm.expectRevert(RebaseToken.RebaseToken__InterestRateShouldOnlyDecrease.selector);
        rebaseToken.setInterestRete(5e18);
        vm.stopPrank();
    }
}
