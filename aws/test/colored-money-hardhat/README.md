# RLN contracts
Contracts are in `contracts` folder.
## Compile contracts
Compiling contracts will generate `typechain` folder with types in contracts to be able to use them in TypeScript scripts.
```
npx hardhat compile
```
## Deploy contracts
We can deploy contracts in different networks.
You should configure previously the `.env` (copy from `.example.env`) file with the information for deploying.

```
# Blockchain URL for deployment
BLOCKCHAIN_URL=
# Private key of the deployer / owner
PRIVATE_KEY=
# Ethereum address of the private key PRIVATE_KEY
ETH_ADDRESS=
``` 
After deploying the contract put the ADDRESS displayed as result of `RLN address` in the `CONTRACT_ADDRESS` variable of the .env
```
# Contract address of the RLN once it's deployed in the network
CONTRACT_ADDRESS=
```
### Deploy in localhost.

1. In one terminal start nightfall from the public nightfall repo in localhost
```
NF_SERVICES_TO_START=blockchain,client,deployer,optimist,worker ./bin/start-nightfall -g -d
```
2. In another terminal
```
npx hardhat run scripts/deploy_contract.ts --network localhost
```
### Deploy in Edge
```
npx hardhat run scripts/deploy_contract.ts --network staging_edge
```
or
```
npm run edge:deploy
```

### Deploy in Mumbai
```
npx hardhat run scripts/deploy_contract.ts --network mumbai
```


### Testing deployment in Edge
Some hardhat tasks have been added to help with RLN testing (`balance`, `bank`, `mint`, `fund`). You could see the information about the tasks with the command `npx hardhat help <task>`.

> **_WARNING:_** In order to be able to execute the tasks, the address that access the blockchain should have some amount of the native token of the blockchain. If not the transaction will be reverted because not enough funds to cover the execution cost of the transaction.

- Add a bank to the contract
```
npx hardhat bank --account <account> --name <name> --network staging_edge
```
Example:
```
npx hardhat bank --account 0xa12D5C4921518980c57Ce3fFe275593e4BAB9211 --name "Bank Test 1" --network staging_edge
```
- List available banks in the contract
```
npx hardhat banks --network staging_edge
```
- Mint RLN tokens for the bank with entityId
```
npx hardhat mint --entityid <entityid> --amount <amount> --network staging_edge
```
Example:
```
npx hardhat mint --entityid 1 --amount 2000 --network staging_edge
```
- Add funds of RLN token to the customer recipient address for the bank with entityid
```
npx hardhat fund --entityid <entityid> --account <account> --amount <amount> --network staging_edge
```
Example:
```
npx hardhat fund --entityid 1 --account 0xa12D5C4921518980c57Ce3fFe275593e4BAB9211 --amount 2000 --network staging_edge
```
- Get balance of an account for a specific bank with entityid
```
npx hardhat balance --token RLN --account <account> --entityid <entityid> --network staging_edge      
```
Example:
```
npx hardhat balance --token RLN --account 0x9C8B2276D490141Ae1440Da660E470E7C0349C63 --entityid 1 --network staging_edge
```
- Get balance of an account in native token
```
npx hardhat balance --token ETH --account <account> --network staging_edge      
```
Example:
```
npx hardhat balance --token ETH --account 0x9C8B2276D490141Ae1440Da660E470E7C0349C63 --network staging_edge
```
- Transfer native token to accounts separated by ','
```
npx hardhat transfer --account <account> --amount <amount> --network staging_edge      
```
Example:
```
npx hardhat transfer --account 0x9C8B2276D490141Ae1440Da660E470E7C0349C63 --amount 1000 --network staging_edge      
```
- Transfer ERC20 token to accounts separated by ','
```
npx hardhat transfer --account <account> --amount <amount> --token <token address> --network staging_edge      
```
Example:
```
npx hardhat transfer --account 0x9efc63e6914a7883ccd302c37bc690fff00b1eb7,0x2b2b71c145b3bd22fca39312181f2bce8087a90e --amount 1000 --token 0xe721F2D97c58b1D1ccd0C80B88256a152d27f0Fe --network staging_edge      
```

## Run tests
For running the tests you need to specify in the .env the following variables
```
# Blockchain wss for deployment
BLOCKCHAIN_WSS=
# Client API URL
CLIENT_API_URL=
# Mnemonic for initializing the sdk
MNEMONIC=
# Optimist WS
OPTIMIST_WS=
# Optimist API URL
OPTIMIST_API_URL=
```
You can run tests with logs with
```
npx hardhat test
```
or without logs with 
```
npm run test
```
