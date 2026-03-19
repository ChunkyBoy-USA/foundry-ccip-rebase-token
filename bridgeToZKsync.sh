#!/bin/bash

# Define constants 
AMOUNT=2000000

ZKSYNC_REGISTRY_MODULE_OWNER_CUSTOM="0xaD417c0611dBD225471D31F056b8B6beC1CBC153"
ZKSYNC_TOKEN_ADMIN_REGISTRY="0x8126bE56454B628a88C17849B9ED99dd5a11Bd2f"
ZKSYNC_ROUTER="0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165"
ZKSYNC_RNM_PROXY_ADDRESS="0x9527E2d01A3064ef6b50c1Da1C0cC523803BCFF2"
ZKSYNC_SEPOLIA_CHAIN_SELECTOR="3478487238524512106"
ZKSYNC_LINK_ADDRESS="0xb1D4538B4571d411F07960EF2838Ce337FE1E80E"

SEPOLIA_REGISTRY_MODULE_OWNER_CUSTOM="0xa3c796d480638d7476792230da1E2ADa86e031b0"
SEPOLIA_TOKEN_ADMIN_REGISTRY="0x95F29FEE11c5C55d26cCcf1DB6772DE953B37B82"
SEPOLIA_ROUTER="0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59"
SEPOLIA_RNM_PROXY_ADDRESS="0xba3f6251de62dED61Ff98590cB2fDf6871FbB991"
SEPOLIA_CHAIN_SELECTOR="16015286601757825753"
SEPOLIA_LINK_ADDRESS="0x779877A7B0D9E8603169DdbD7836e478b4624789"

# Compile and deploy the Rebase Token contract
source .env
forge build
echo "Compiling and deploying the Rebase Token contract on ZKsync..."
ZKSYNC_REBASE_TOKEN_ADDRESS=$(forge create src/RebaseToken.sol:RebaseToken --legacy  --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount --broadcast --verify --gas-price 250000000  | awk '/Deployed to:/ {print $3}')
echo "ZKsync rebase token address: $ZKSYNC_REBASE_TOKEN_ADDRESS"
# ZKSYNC_REBASE_TOKEN_ADDRESS="0x0b24eD66b4bd34d6C9BF070F108B8E4b2786A06b"
# # Compile and deploy the pool contract
echo "Compiling and deploying the pool contract on ZKsync..."
pool_output=$(forge create src/RebaseTokenPool.sol:RebaseTokenPool --legacy --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount --broadcast --verify --gas-price 250000000  --constructor-args ${ZKSYNC_REBASE_TOKEN_ADDRESS} '[]' ${ZKSYNC_RNM_PROXY_ADDRESS} ${ZKSYNC_ROUTER})
echo "$pool_output"
ZKSYNC_POOL_ADDRESS=$(echo "$pool_output" | awk '/Deployed to:/ {print $3}')
# ZKSYNC_POOL_ADDRESS="0x3896c8fc501eBfa40578fE1716081Ec48201c017"
echo "ZKSYNC Pool address: $ZKSYNC_POOL_ADDRESS"

# # Set the permissions for the pool contract
echo "Setting the permissions for the pool contract on ZKsync..."
cast send ${ZKSYNC_REBASE_TOKEN_ADDRESS} "grantMintAndBurnRole(address)" ${ZKSYNC_POOL_ADDRESS} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount
echo "Pool permissions set"

# # Set the CCIP roles and permissions
echo "Setting the CCIP roles and permissions on ZKsync..."
cast send ${ZKSYNC_REGISTRY_MODULE_OWNER_CUSTOM} "registerAdminViaOwner(address)" ${ZKSYNC_REBASE_TOKEN_ADDRESS} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount
cast send ${ZKSYNC_TOKEN_ADMIN_REGISTRY} "acceptAdminRole(address)" ${ZKSYNC_REBASE_TOKEN_ADDRESS} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount
cast send ${ZKSYNC_TOKEN_ADMIN_REGISTRY} "setPool(address,address)" ${ZKSYNC_REBASE_TOKEN_ADDRESS} ${ZKSYNC_POOL_ADDRESS} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount
echo "CCIP roles and permissions set"

# # 2. On Sepolia!

echo "Running the script to deploy the contracts on Sepolia..."
output=$(forge script ./script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url ${SEPOLIA_RPC_URL} --account myaccount --broadcast --verify --gas-price 250000000 )
echo "Contracts deployed and permission set on Sepolia"

# Extract the addresses from the output
SEPOLIA_REBASE_TOKEN_ADDRESS=$(echo "$output" | grep 'token: contract RebaseToken' | awk '{print $4}')
SEPOLIA_POOL_ADDRESS=$(echo "$output" | grep 'pool: contract RebaseTokenPool' | awk '{print $4}')
# SEPOLIA_REBASE_TOKEN_ADDRESS="0x0cc34C65F544E4852a4123254803c2CD02C3b6e4"
# SEPOLIA_POOL_ADDRESS="0xba2d3e3E54C17FB3344c5d433AF39Bf2E01FE91f"
echo "Sepolia rebase token address: $SEPOLIA_REBASE_TOKEN_ADDRESS"
echo "Sepolia pool address: $SEPOLIA_POOL_ADDRESS"

# Deploy the vault 
echo "Deploying the vault on Sepolia..."
VAULT_ADDRESS=$(forge script ./script/Deployer.s.sol:VaultDeployer --rpc-url ${SEPOLIA_RPC_URL} --account myaccount --broadcast --verify --gas-price 250000000  --sig "run(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS} | grep 'vault: contract Vault' | awk '{print $NF}')
# VAULT_ADDRESS="0xf149943DA8c8d5652C6777C058A257462DB9A2fB"
echo "Vault address: $VAULT_ADDRESS"

# Configure the pool on Sepolia
echo "Configuring the pool on Sepolia..."
# uint64 remoteChainSelector,
#         address remotePoolAddress, /
#         address remoteTokenAddress, /
#         bool outboundRateLimiterIsEnabled, false 
#         uint128 outboundRateLimiterCapacity, 0
#         uint128 outboundRateLimiterRate, 0
#         bool inboundRateLimiterIsEnabled, false 
#         uint128 inboundRateLimiterCapacity, 0 
#         uint128 inboundRateLimiterRate 0 
forge script ./script/ConfigurePool.s.sol:ConfigurePoolScript --rpc-url ${SEPOLIA_RPC_URL} --account myaccount --broadcast --verify --gas-price 250000000  --sig "run(address,uint64,address,address,bool,uint128,uint128,bool,uint128,uint128)" ${SEPOLIA_POOL_ADDRESS} ${ZKSYNC_SEPOLIA_CHAIN_SELECTOR} ${ZKSYNC_POOL_ADDRESS} ${ZKSYNC_REBASE_TOKEN_ADDRESS} false 0 0 false 0 0

# Deposit funds to the vault
echo "Depositing funds to the vault on Sepolia..."
cast send ${VAULT_ADDRESS} --value ${AMOUNT} --rpc-url ${SEPOLIA_RPC_URL} --account myaccount "deposit()"

# Wait a beat for some interest to accrue

# Configure the pool on ZKsync
echo "Configuring the pool on ZKsync..."
# cast send ${ZKSYNC_POOL_ADDRESS}  --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount "applyChainUpdates(uint64[],(uint64,bytes[],bytes,(bool,uint128,uint128),(bool,uint128,uint128))[])" "[${SEPOLIA_CHAIN_SELECTOR}]" "[(${SEPOLIA_CHAIN_SELECTOR},[$(cast abi-encode "f(address)" ${SEPOLIA_POOL_ADDRESS})],$(cast abi-encode "f(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS}),(false,0,0),(false,0,0))]"
forge script ./script/ConfigurePool.s.sol:ConfigurePoolScript --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount --broadcast --verify --gas-price 250000000  --sig "run(address,uint64,address,address,bool,uint128,uint128,bool,uint128,uint128)" ${ZKSYNC_POOL_ADDRESS} ${SEPOLIA_CHAIN_SELECTOR} ${SEPOLIA_POOL_ADDRESS} ${SEPOLIA_REBASE_TOKEN_ADDRESS} false 0 0 false 0 0

# Bridge the funds using the script to zksync 
echo "Bridging the funds using the script to ZKsync..."
SEPOLIA_BALANCE_BEFORE=$(cast balance $(cast wallet address --account myaccount) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance before bridging: $SEPOLIA_BALANCE_BEFORE"
forge script ./script/BridgeTokens.s.sol:BridgeTokensScript --rpc-url ${SEPOLIA_RPC_URL} --account myaccount --broadcast --verify --gas-price 250000000  --sig "run(address,address,uint64,address,uint256,address)" $(cast wallet address --account myaccount) ${SEPOLIA_LINK_ADDRESS} ${ZKSYNC_SEPOLIA_CHAIN_SELECTOR} ${SEPOLIA_REBASE_TOKEN_ADDRESS} ${AMOUNT} ${SEPOLIA_ROUTER}
echo "Funds bridged to ZKsync"
SEPOLIA_BALANCE_AFTER=$(cast balance $(cast wallet address --account myaccount) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance after bridging: $SEPOLIA_BALANCE_AFTER"