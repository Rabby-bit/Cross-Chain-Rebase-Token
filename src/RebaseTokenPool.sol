// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {RebaseToken} from "src/RebaseToken.sol";
import {TokenPool} from "@chainlink-ccip/contracts/pools/TokenPool.sol";
import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";
import {iRebaseToken} from "src/iRebaseToken.sol";
import {Pool} from "@chainlink-ccip/contracts/libraries/Pool.sol";
//import {IPoolV2} from "@chainlink-ccip/contracts/interfaces/IPoolV2.sol";

contract RebaseTokenPool is TokenPool {
    iRebaseToken internal immutable _iRebaseToken;
    constructor(
        IERC20 _iRebaseToken,
        uint8 _localTokenDecimals,
        address _advancedTokenPool,
        address _rmnProxy,
        address _router
    ) TokenPool(_iRebaseToken, 18, _advancedTokenPool, _rmnProxy, _router) {}

    function lockOrBurn(
        Pool.LockOrBurnInV1 calldata lockOrBurnIn,
        bytes4 requestedFinalityConfig,
        bytes calldata tokenArgs
    ) public override returns (Pool.LockOrBurnOutV1 memory, uint256 destTokenAmount) {
        uint256 feeAmount = _getFee(lockOrBurnIn, requestedFinalityConfig);
        _validateLockOrBurn(lockOrBurnIn, requestedFinalityConfig, tokenArgs, feeAmount);
        uint256 userInterestRate = iRebaseToken(address(_iRebaseToken)).getUserInterestRate(lockOrBurnIn.originalSender);

        iRebaseToken(address(_iRebaseToken)).burn(address(this), lockOrBurnIn.amount);

        destTokenAmount = lockOrBurnIn.amount - feeAmount;

        return (
            Pool.LockOrBurnOutV1({
                destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
                destPoolData: abi.encode(userInterestRate)
            }),
            destTokenAmount
        );
    }

    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn, bytes4 requestedFinalityConfig)
        public
        override
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        uint256 localAmount = releaseOrMintIn.sourceDenominatedAmount;

        uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));

        _validateReleaseOrMint(releaseOrMintIn, localAmount, requestedFinalityConfig);
        iRebaseToken(address(_iRebaseToken)).mint(releaseOrMintIn.receiver, localAmount, userInterestRate);

        return Pool.ReleaseOrMintOutV1({destinationAmount: localAmount});
    }
}
