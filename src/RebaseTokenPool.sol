// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenPool, IERC20} from "lib/chainlink-ccip/chains/evm/contracts/pools/TokenPool.sol";
import {Pool} from "lib/chainlink-ccip/chains/evm/contracts/libraries/Pool.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";

contract RebaseTokenPool is TokenPool {
    // Debug events
    event LockOrBurnDebug(address indexed sender, uint256 amount, uint256 userInterestRate, bytes destPoolData);
    event ReleaseOrMintDebug(address indexed receiver, uint256 amount, uint256 userInterestRate, uint256 sourcePoolDataLength);
    error RebaseTokenPool__MissingInterestRate();

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
        
        // Emit debug event for testnet visibility
        emit LockOrBurnDebug(lockOrBurnIn.originalSender, lockOrBurnIn.amount, userInterestRate, lockOrBurnOut.destPoolData);
    }
    
    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        public virtual override
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        
        _validateReleaseOrMint(releaseOrMintIn, releaseOrMintIn.sourceDenominatedAmount);
        
         address receiver = releaseOrMintIn.receiver;
         if (releaseOrMintIn.sourcePoolData.length == 0) revert RebaseTokenPool__MissingInterestRate();
        (uint256 userInterestRate) = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));

        // Mint rebasing tokens to the receiver on the destination chain
        // This will also mint any interest that has accrued since the last time the user's balance was updated.
        IRebaseToken(address(i_token)).mint(receiver, releaseOrMintIn.sourceDenominatedAmount, userInterestRate);
        
        // Emit debug event for testnet visibility
        emit ReleaseOrMintDebug(receiver, releaseOrMintIn.sourceDenominatedAmount, userInterestRate, releaseOrMintIn.sourcePoolData.length);
        
        return Pool.ReleaseOrMintOutV1({
            destinationAmount: releaseOrMintIn.sourceDenominatedAmount
        });
    }
}
