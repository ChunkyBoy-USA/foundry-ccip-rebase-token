// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenPool, IERC20} from "lib/chainlink-ccip/chains/evm/contracts/pools/TokenPool.sol";
import {Pool} from "lib/chainlink-ccip/chains/evm/contracts/libraries/Pool.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";

contract RebaseTokenPool is TokenPool {
    constructor(IERC20 _token, address[] memory _allowList, address _rmnProxy, address _router)
        TokenPool(_token, 18, _allowList, _rmnProxy, _router)
    {}

    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        public virtual override 
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        _validateLockOrBurn(lockOrBurnIn);
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(lockOrBurnIn.originalSender);
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
        });
    }

    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        public virtual override
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        _validateReleaseOrMint(releaseOrMintIn, releaseOrMintIn.sourceDenominatedAmount);
        // Decode the user's interest rate from the source pool's lockOrBurn function
        uint256 userInterestRate = 0;
        if (releaseOrMintIn.sourcePoolData.length > 0) {
            userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        } else {
            // Fallback: use the current global interest rate if no data provided
            userInterestRate = IRebaseToken(address(i_token)).getInterestRate();
        }
        IRebaseToken(address(i_token)).mint(releaseOrMintIn.receiver, releaseOrMintIn.sourceDenominatedAmount, userInterestRate);

        return Pool.ReleaseOrMintOutV1({
            destinationAmount: releaseOrMintIn.sourceDenominatedAmount
        });
    }
}
