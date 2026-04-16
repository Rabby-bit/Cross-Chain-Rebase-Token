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
    uint256 public constant SEND_VALUE = 1e5;

    address owner = makeAddr("owner");
    address user = makeAddr("user");

    CCIPLocalSimulatorFork cCIPLocalSimulatorFork;
    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbitrumNetworkDetails;

    function setUp() public {
        sepoliafork = vm.createSelectFork("sepolia");
        arbitrumfork = vm.createFork("arb-sepolia");

        cCIPLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(cCIPLocalSimulatorFork));
        sepoliaNetworkDetails = cCIPLocalSimulatorFork.getNetworkDetails(11155111);
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(iRebaseToken(address(sepoliaToken)));
        //constructor  constructor(IERC20 _iRebaseToken, uint8 _localTokenDecimals, address _advancedTokenPool,address _rmnProxy, address _router )
        sepoliaTokenPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            18,
            address(0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );

        sepoliaToken.grantRole(sepoliaToken.BURN_MINTER_ROLE(), address(sepoliaTokenPool));
        sepoliaToken.grantRole(sepoliaToken.BURN_MINTER_ROLE(), address(vault));
        console.log(
            "sepoliaNetworkDetails.registryModuleOwnerCustomAddress",
            sepoliaNetworkDetails.registryModuleOwnerCustomAddress
        );
        console.log("sepoliaNetworkDetails.tokenAdminRegistryAddress", sepoliaNetworkDetails.tokenAdminRegistryAddress);
        console.log("sepoliaNetworkDetails.rmnProxyAddress", sepoliaNetworkDetails.rmnProxyAddress);
        console.log(" sepoliaNetworkDetails.routerAddress", sepoliaNetworkDetails.routerAddress);
        console.log("chain", block.chainid);
        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(sepoliaToken), address(sepoliaTokenPool));

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
        console.log("chain", block.chainid);
        RegistryModuleOwnerCustom arbitrumRegistryModuleOwnerCustom =
            RegistryModuleOwnerCustom(arbitrumNetworkDetails.registryModuleOwnerCustomAddress);
        arbitrumRegistryModuleOwnerCustom.registerAdminViaOwner(address(arbitrumToken));

        TokenAdminRegistry arbitrumTokenAdminRegistry =
            TokenAdminRegistry(arbitrumNetworkDetails.tokenAdminRegistryAddress);
        arbitrumTokenAdminRegistry.acceptAdminRole(address(arbitrumToken));
        arbitrumTokenAdminRegistry.setPool(address(arbitrumToken), address(arbitrumTokenPool));

        vm.stopPrank();
        configureTokenPool(
            sepoliafork,
            address(sepoliaTokenPool),
            arbitrumNetworkDetails.chainSelector,
            address(arbitrumTokenPool),
            address(arbitrumToken)
        );
        configureTokenPool(
            arbitrumfork,
            address(arbitrumTokenPool),
            sepoliaNetworkDetails.chainSelector,
            address(sepoliaTokenPool),
            address(sepoliaToken)
        );
        console.log("sepoliaNetworkDetails.chainSelector:", sepoliaNetworkDetails.chainSelector);
        console.log("arbitrumNetworkDetails.chainSelector:", arbitrumNetworkDetails.chainSelector);
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

        vm.prank(owner);
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
        vm.selectFork(localfork);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(localtoken), amount: amountToBridge});

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: localNetworkDetails.linkAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 1_000_000}))
        });
        console.log("amountToBridge: ", amountToBridge);
        vm.prank(user);
        uint256 fees =
            IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message);
        console.log("Fees to bridge: ", fees);

        cCIPLocalSimulatorFork.requestLinkFromFaucet(user, fees);
        // vm.selectFork(remotefork);
        vm.prank(user);
        IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fees);
        vm.prank(user);
        IERC20(address(localtoken)).approve(localNetworkDetails.routerAddress, amountToBridge);
        uint256 localBalanceBefore = localtoken.balanceOf(user);
        console.log("localBalanceBefore :", localBalanceBefore);
        vm.prank(user);
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);

        vm.selectFork(remotefork);
        uint256 remoteBalanceOfUserBefore = remotetoken.balanceOf(user);
        cCIPLocalSimulatorFork.switchChainAndRouteMessage(remotefork);

        vm.warp(block.timestamp + 1 days);

        uint256 remoteBalanceOfUserAfter = remotetoken.balanceOf(user);
        console.log("remoteBalanceOfUserBefore :", remoteBalanceOfUserBefore);
        console.log("remoteBalanceOfUserAfter :", remoteBalanceOfUserAfter);
        assertEq(remoteBalanceOfUserAfter, remoteBalanceOfUserBefore);
    }

    function test_transfertoken() public {
        address user = makeAddr("user");
        vm.selectFork(sepoliafork);
        vm.deal(user, SEND_VALUE);

        vm.prank(user);
        vault.deposit{value: SEND_VALUE}();

        bridgeTokenTransfer(
            sepoliafork,
            arbitrumfork,
            sepoliaNetworkDetails,
            arbitrumNetworkDetails,
            sepoliaToken,
            arbitrumToken,
            SEND_VALUE
        );
    }
}
