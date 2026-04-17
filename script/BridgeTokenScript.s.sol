//SPDX-Licenese_Identifier:MIT

pragma solidity ^0.8.24;
import {Script} from "forge-std/Script.sol";
import {Client} from "@chainlink-ccip/contracts/libraries/Client.sol";
import {IRouterClient} from "@chainlink-ccip/contracts/interfaces/IRouterClient.sol";
import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";

contract BridgeTokenScript is Script {
    function run(
        address receiver,
        address token,
        uint256 amount,
        address feeToken,
        uint64 destinationChainSelector,
        address routerAddress
    ) public {
        vm.startBroadcast();
        //      struct EVM2AnyMessage {
        //     bytes receiver; // abi.encode(receiver address) for dest EVM chains.
        //     bytes data; // Data payload.
        //     EVMTokenAmount[] tokenAmounts; // Token transfers.
        //     address feeToken; // Address of feeToken. address(0) means you will send msg.value.
        //     bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV3).
        //   }
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: token, amount: amount});

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: feeToken,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0}))
        });

        uint256 fee = IRouterClient(routerAddress).getFee(destinationChainSelector, message);
        IERC20(feeToken).approve(routerAddress, fee);
        IERC20(token).approve(routerAddress, amount);
        IRouterClient(routerAddress).ccipSend(destinationChainSelector, message);
        vm.stopBroadcast();
    }
}
