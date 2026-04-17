//SPDX-Licenese_Identifier:MIT

pragma solidity ^0.8.24;
import {Script} from "forge-std/Script.sol";
import {Vault} from "src/Vault.sol";
import {iRebaseToken} from "src/iRebaseToken.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {RebaseTokenPool} from "src/RebaseTokenPool.sol";
import {CCIPLocalSimulatorFork} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {Register} from "@chainlink-local/src/ccip/Register.sol";
import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@chainlink-ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@chainlink-ccip/contracts/tokenAdminRegistry/TokenAdminRegistry.sol";

contract VaultScript is Script {
    function run(address _rebaseToken) public returns (Vault vault) {
        vm.startBroadcast();
        vault = new Vault(iRebaseToken(_rebaseToken));
        RebaseToken(_rebaseToken).grantRole(RebaseToken(_rebaseToken).BURN_MINTER_ROLE(), address(vault));
        vm.stopBroadcast();
    }
}

contract TokenAndPoolDeployer is Script {
    function run() public returns (RebaseToken rebasetoken, RebaseTokenPool pool) {
        //     constructor(
        //     IERC20 _token,
        //     uint8 _localTokenDecimals,
        //     address _advancedTokenPool,
        //     address _rmnProxy,
        //     address _router
        // ) TokenPool(_token, 18, _advancedTokenPool, _rmnProxy, _router) {
        //     _iRebaseToken = iRebaseToken(address(_token));
        // }
        CCIPLocalSimulatorFork cciplocalsimulatorfork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory details = cciplocalsimulatorfork.getNetworkDetails(block.chainid);

        vm.startBroadcast();
        rebasetoken = new RebaseToken();
        pool = new RebaseTokenPool(
            IERC20(address(rebasetoken)), 18, address(0), details.rmnProxyAddress, details.routerAddress
        );
        // rebasetoken.grantRole( rebasetoken.BURN_MINTER_ROLE(), address (vault));
        rebasetoken.grantRole(RebaseToken(rebasetoken).BURN_MINTER_ROLE(), address(pool));
        RegistryModuleOwnerCustom(details.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(rebasetoken));
        TokenAdminRegistry(details.tokenAdminRegistryAddress).acceptAdminRole(address(rebasetoken));
        TokenAdminRegistry(details.tokenAdminRegistryAddress).setPool(address(rebasetoken), address(pool));

        vm.stopBroadcast();
    }
}
