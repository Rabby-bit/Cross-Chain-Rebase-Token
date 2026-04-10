//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {Vault} from "src/Vault.sol";
import {iRebaseToken} from "src/iRebaseToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract RebaseTokenTest is Test {
    RebaseToken rebaseToken;
    Vault vault;
    iRebaseToken irebasetoken;
    uint96 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

    address user = makeAddr("user");
    address owner = makeAddr("owner");
    address user2 = makeAddr("user2");

    function setUp() public {
        vm.deal(user, 100 ether);
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(rebaseToken);
        rebaseToken.grantRole(rebaseToken.BURN_MINTER_ROLE(), address(vault));
        vm.stopPrank();
    }

    function test__depositfuzz(uint256 amount) public {
        amount = bound(amount, 1, MAX_DEPOSIT_SIZE);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        vm.warp(block.timestamp - 1);
        uint256 balanceOfUserAfterDeposit = rebaseToken.balanceOf(user);
        console.log(" balanceOfUserAfterDeposit", balanceOfUserAfterDeposit);
        assertEq(balanceOfUserAfterDeposit, amount);
        vm.stopPrank();
    }

    // function test__depositfuzzconsistent(uint256 amount) public {
    //     amount = bound(amount, 1, MAX_DEPOSIT_SIZE);
    //     vm.startPrank(user);
    //     vm.deal(user, amount);
    //     vault.deposit{value : amount}();
    //     vm.warp(block.timestamp + 1 days );
    //     uint256 balanceOfUserAfterDeposit1 = rebaseToken.balanceOf(user);
    //     console.log(" balanceOfUserAfterDeposit1" ,  balanceOfUserAfterDeposit1);
    //     vm.warp(block.timestamp + 1 days );
    //     uint256 balanceOfUserAfterDeposit2 = rebaseToken.balanceOf(user);
    //     console.log(" balanceOfUserAfterDeposit2" ,  balanceOfUserAfterDeposit2);
    //      vm.warp(block.timestamp + 1 days );
    //     uint256 balanceOfUserAfterDeposit3 = rebaseToken.balanceOf(user);
    //     console.log(" balanceOfUserAfterDeposit3" ,  balanceOfUserAfterDeposit3);

    //     assertGt(balanceOfUserAfterDeposit2  - balanceOfUserAfterDeposit1,balanceOfUserAfterDeposit3 -  balanceOfUserAfterDeposit2 );

    //     vm.stopPrank();

    // }

    function test__transfer(uint256 amount) public {
        amount = bound(amount, 1, MAX_DEPOSIT_SIZE);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        rebaseToken.transfer(user2, amount);
        uint256 balanceOfreciepent = rebaseToken.getPrincipalBalance(user2);
        assertEq(amount, balanceOfreciepent);
        vm.stopPrank();
    }

    function test__transferFrom(uint256 amount) public {
        amount = bound(amount, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();

        rebaseToken.approve(user2, amount);
        vm.stopPrank();

        vm.startPrank(user2);
        rebaseToken.transferFrom(user, user2, amount);

        uint256 balanceOfRecipient = rebaseToken.getPrincipalBalance(user2);
        assertEq(amount, balanceOfRecipient);

        vm.stopPrank();
    }
}
