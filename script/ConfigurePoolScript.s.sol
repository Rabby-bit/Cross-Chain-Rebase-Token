//SPDX-Licenese_Identifier:MIT

pragma solidity ^0.8.24;
import {Script} from "forge-std/Script.sol";
import {RateLimiter} from "@chainlink-ccip/contracts/libraries/RateLimiter.sol";
import {TokenPool} from "@chainlink-ccip/contracts/pools/TokenPool.sol";
import {Client} from "@chainlink-ccip/contracts/libraries/Client.sol";
import {IRouterClient} from "@chainlink-ccip/contracts/interfaces/IRouterClient.sol";

contract ConfigurePoolScript is Script {
    function run(
        address pool,
        uint64 remoteChainSelector,
        uint64[] memory chainsToAdd,
        address remotePoolAddress,
        address remoteTokenAddress,
        bool isEnabled,
        uint128 capacity,
        uint128 rate
    ) public {
        vm.startBroadcast();
        uint64[] memory remoteChainSelectorsToRemove = new uint64[](0);
        bytes[] memory remotePoolAddresses = new bytes[](1);
        bytes memory remotePoolAddress = abi.encode(remotePoolAddress);
        //         struct ChainUpdate {
        //        uint64 remoteChainSelector; // Remote chain selector.
        //     bytes[] remotePoolAddresses; // Address of the remote pool, ABI encoded in the case of a remote EVM chain.
        //     bytes remoteTokenAddress; // Address of the remote token, ABI encoded in the case of a remote EVM chain.
        //     RateLimiter.Config outboundRateLimiterConfig; // Outbound rate limited config, meaning the rate limits for all of the onRamps for the given chain.
        //     RateLimiter.Config inboundRateLimiterConfig; // Inbound rate limited config, meaning the rate limits for all of the offRamps for the given chain.
        //   }
        // struct Config {
        //     bool isEnabled; // Indication whether the rate limiting should be enabled.
        //     uint128 capacity; // ──╮ Specifies the capacity of the rate limiter.
        //     uint128 rate; //  ─────╯ Specifies the rate of the rate limiter.
        //
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: remotePoolAddresses,
            remoteTokenAddress: abi.encode(remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: isEnabled, capacity: capacity, rate: rate}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: isEnabled, capacity: capacity, rate: rate})
        });

        TokenPool(pool).applyChainUpdates(remoteChainSelectorsToRemove, chainsToAdd);
        vm.stopBroadcast();
    }
}
