//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {Vault} from "src/Vault.sol";
import {iRebaseToken} from "src/iRebaseToken.sol";
import {RebaseTokenPool} from "src/RebaseTokenPool.sol";
import {CCIPLocalSimulatorFork} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {Register} from "@chainlink-local/src/ccip/Register.sol";
import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@chainlink-ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@chainlink-ccip/contracts/tokenAdminRegistry/TokenAdminRegistry.sol";
import {RateLimiter} from "@chainlink-ccip/contracts/libraries/RateLimiter.sol";
import {TokenPool} from "@chainlink-ccip/contracts/pools/TokenPool.sol";
import {Client} from "@chainlink-ccip/contracts/libraries/Client.sol";
import {IRouterClient} from "@chainlink-ccip/contracts/interfaces/IRouterClient.sol";
// import{RegistryModuleOwnerCustom} from "@chainlink-local/src/ccip/RegistryModuleOwnerCustom.sol";

contract CrossChainTest is Test {
    uint256 sepoliafork;
    uint256 arbitrumfork;
    RebaseToken sepoliaToken;
    RebaseToken arbitrumToken;
    Vault vault;
    iRebaseToken irebaseToken;
    RebaseTokenPool sepoliaTokenPool;
    RebaseTokenPool arbitrumTokenPool;

    address owner = makeAddr("owner");

    CCIPLocalSimulatorFork cCIPLocalSimulatorFork;
    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbitrumNetworkDetails;

    function setUp() public {
        sepoliafork = vm.createSelectFork("sepolia");
        arbitrumfork = vm.createFork("arb-sepolia");

        cCIPLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(cCIPLocalSimulatorFork));
        sepoliaNetworkDetails = cCIPLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(iRebaseToken(address(sepoliaToken)));
        sepoliaTokenPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            18,
            address(0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );
        sepoliaToken.grantRole(sepoliaToken.BURN_MINTER_ROLE(), address(sepoliaTokenPool));
        sepoliaToken.grantRole(sepoliaToken.BURN_MINTER_ROLE(), address(vault));
        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(sepoliaToken), address(sepoliaTokenPool));
        configureTokenPool(
            sepoliafork,
            address(sepoliaTokenPool),
            sepoliaNetworkDetails.chainSelector,
            address(arbitrumTokenPool),
            address(arbitrumToken)
        );
        vm.stopPrank();

        vm.selectFork(arbitrumfork);
        arbitrumNetworkDetails = cCIPLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startPrank(owner);
        arbitrumToken = new RebaseToken();
        arbitrumTokenPool = new RebaseTokenPool(
            IERC20(address(arbitrumToken)),
            18,
            address(0),
            arbitrumNetworkDetails.rmnProxyAddress,
            arbitrumNetworkDetails.routerAddress
        );
        arbitrumToken.grantRole(arbitrumToken.BURN_MINTER_ROLE(), address(arbitrumTokenPool));
        RegistryModuleOwnerCustom(arbitrumNetworkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(arbitrumToken));
        TokenAdminRegistry(arbitrumNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(arbitrumToken));
        TokenAdminRegistry(arbitrumNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(arbitrumToken), address(arbitrumTokenPool));
        configureTokenPool(
            arbitrumfork,
            address(arbitrumTokenPool),
            arbitrumNetworkDetails.chainSelector,
            address(sepoliaTokenPool),
            address(sepoliaToken)
        );
        vm.stopPrank();
    }

    function configureTokenPool(
        uint256 forkId,
        address localpool,
        uint64 remoteChainSelector,
        address remotePoolAddress,
        address remoteTokenAddress
    ) public {
        //     uint64[] calldata remoteChainSelectorsToRemove,
        // ChainUpdate[] calldata chainsToAdd
        //      struct ChainUpdate {
        //     uint64 remoteChainSelector; // Remote chain selector.
        //     bytes[] remotePoolAddresses; // Address of the remote pool, ABI encoded in the case of a remote EVM chain.
        //     bytes remoteTokenAddress; // Address of the remote token, ABI encoded in the case of a remote EVM chain.
        //     RateLimiter.Config outboundRateLimiterConfig; // Outbound rate limited config, meaning the rate limits for all of the onRamps for the given chain.
        //     RateLimiter.Config inboundRateLimiterConfig; // Inbound rate limited config, meaning the rate limits for all of the offRamps for the given chain.
        //   }
        vm.selectFork(forkId);
        uint64[] memory remoteChainSelectorsToRemove = new uint64[](0);
        bytes[] memory remotePoolAddressesArray = new bytes[](1);
        remotePoolAddressesArray[0] = abi.encode(remotePoolAddress);

        //what is i wanted multiple chain what is that going to look like ?
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: remotePoolAddressesArray,
            remoteTokenAddress: abi.encode(remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0})
        });

        vm.startPrank(owner);
        TokenPool(localpool).applyChainUpdates(remoteChainSelectorsToRemove, chainsToAdd);
    }

    function bridgeTokenTransfer(
        uint256 localfork,
        uint256 remotefork,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localtoken,
        RebaseToken remotetoken,
        uint256 amountToBridge
    ) public {
        address user = makeAddr("user");
        vm.selectFork(localfork);

        //        struct EVM2AnyMessage {
        //     bytes receiver; // abi.encode(receiver address) for dest EVM chains.
        //     bytes data; // Data payload.
        //     EVMTokenAmount[] tokenAmounts; // Token transfers.
        //     address feeToken; // Address of feeToken. address(0) means you will send msg.value.
        //     bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV3).
        //   }

        // struct EVMTokenAmount {
        //     address token; // token address on the local chain.
        //     uint256 amount; // Amount of tokens.
        //   }

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(localtoken), amount: amountToBridge});

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: address(localtoken),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0}))
        });
        vm.prank(user);
        uint256 fees =
            IRouterClient(localNetworkDetails.routerAddress).getFee(localNetworkDetails.chainSelector, message);
        console.log("Fees to bridge: ", fees);

        cCIPLocalSimulatorFork.requestLinkFromFaucet(user, fees);
        // vm.selectFork(remotefork);
        vm.prank(user);
        IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fees);
        vm.prank(user);
        IERC20(address(localtoken)).approve(localNetworkDetails.routerAddress, amountToBridge);
        uint256 localBalanceBefore = localtoken.balanceOf(user);
        vm.prank(user);
        IRouterClient(remoteNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);
        uint256 localBalanceAfter = localtoken.balanceOf(user);

        assertEq(localBalanceBefore, localBalanceAfter + amountToBridge, "User should have less tokens after bridging");

        vm.warp(block.timestamp + 1 days);
        vm.selectFork(remotefork);
        uint256 remoteBalanceOfUserBefore = remotetoken.balanceOf(user);
        cCIPLocalSimulatorFork.switchChainAndRouteMessage(remotefork);

        uint256 remoteBalanceOfUserAfter = remotetoken.balanceOf(user);
        assertEq(remoteBalanceOfUserAfter, remoteBalanceOfUserBefore + amountToBridge);
    }
}
