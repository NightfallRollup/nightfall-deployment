// hardhat.config.ts
import '@nomicfoundation/hardhat-toolbox';
import { HardhatUserConfig, task } from 'hardhat/config';
import { UserConfig } from './helper-hardhat-config';
import {
  addBank,
  addFunds,
  getBalanceToken,
  getBanks,
  getContract,
  mint,
  transfer,
  generateNightfallMnemonics,
} from './scripts/common';

// Define some tasks for token management
task('balance', `Prints an account's RLN token balance`)
  .addOptionalParam(
    'token',
    'Token for the balance. Could be empty for the native token, RLN for the RLN token or the address of the ERC token in 0x format',
    '',
  )
  .addOptionalParam('entityid', `The entityId of the bank in the system`)
  .addParam('account', `The account's address`)
  .setAction(async (taskArgs, hre) => {
    await getContract(hre).then(RLN =>
      getBalanceToken(RLN, hre, taskArgs.account, taskArgs.token, taskArgs.entityid),
    );
  });

task('transfer', `Transfer native token to the account`)
  .addOptionalParam('token', 'Token address', '')
  .addOptionalParam('tokenid', 'Token id', '')
  .addParam('account', `Account's addresses to transfer separated by ','`)
  .addParam('amount', `Amount of native token to be transferred`)
  .setAction(async (taskArgs, hre) => {
    await transfer(hre, taskArgs.account, taskArgs.amount, taskArgs.token, taskArgs.tokenid);
  });

task('mint', `Mint RLN tokens for the bank`)
  .addParam('entityid', `The entityId of the bank in the system`)
  .addParam('amount', `Amount of RLN token to be minted`)
  .setAction(async (taskArgs, hre) => {
    await getContract(hre).then(RLN => mint(RLN, hre, taskArgs.entityid, taskArgs.amount));
  });

task('fund', `Funds an account's with RLN token`)
  .addParam('entityid', `The entityId of the bank in the system`)
  .addParam('account', `The account's recipient address`)
  .addParam('amount', `Amount of RLN token to be transferred`)
  .setAction(async (taskArgs, hre) => {
    await getContract(hre).then(RLN =>
      addFunds(RLN, hre, taskArgs.entityid, taskArgs.account, taskArgs.amount),
    );
  });

task('bank', `Add bank to RLN token system`)
  .addParam('account', `The account's address`)
  .addParam('name', `The name of the bank`)
  .setAction(async (taskArgs, hre) => {
    await getContract(hre).then(RLN => addBank(RLN, taskArgs.name, taskArgs.account));
  });

task('banks', `Get banks from the system`).setAction(async (taskArgs, hre) => {
  await getContract(hre).then(RLN => getBanks(RLN));
});

task('mnemonic', `Generate mnemonics`)
  .addParam('amount', `Amount of mnemonics`)
  .setAction(async taskArgs => {
    await generateNightfallMnemonics(taskArgs.amount);
  });

// Hardhat config
const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.9',
        settings: {
          optimizer: { enabled: true, runs: 200 },
        },
      },
    ],
  },
  networks: {
    mainnet: {
      url: UserConfig.BLOCKCHAIN_URL,
      accounts: [UserConfig.PRIVATE_KEY],
    },
    ropsten: {
      url: UserConfig.BLOCKCHAIN_URL,
      accounts: [UserConfig.PRIVATE_KEY],
    },
    goerli: {
      url: UserConfig.BLOCKCHAIN_URL,
      accounts: [UserConfig.PRIVATE_KEY],
    },
    rinkeby: {
      url: UserConfig.BLOCKCHAIN_URL,
      accounts: [UserConfig.PRIVATE_KEY],
    },
    mumbai: {
      url: UserConfig.BLOCKCHAIN_URL,
      accounts: [UserConfig.PRIVATE_KEY],
    },
    localhost: {
      url: UserConfig.BLOCKCHAIN_URL,
      accounts: [UserConfig.PRIVATE_KEY],
    },
    staging_edge: {
      url: UserConfig.BLOCKCHAIN_URL,
      accounts: [UserConfig.PRIVATE_KEY],
    },
    hardhat: {},
  },
};

export default config;
