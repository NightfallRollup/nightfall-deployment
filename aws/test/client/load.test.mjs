/* eslint-disable no-await-in-loop */
import chai from 'chai';
import chaiHttp from 'chai-http';
import config from 'config';
import chaiAsPromised from 'chai-as-promised';
import logger from '@polygon-nightfall/common-files/utils/logger.mjs';
import Nf3 from '../cli/lib/nf3.mjs';
import {
  depositNTransactionsAsync,
  transferNTransactionsAsync,
  Web3Client,
  waitForSufficientBalance,
  getLayer2Balances,
} from './utils.mjs';

// so we can use require with mjs file
chai.use(chaiHttp);
chai.use(chaiAsPromised);

// we need require here to import jsons
const environment = config.ENVIRONMENTS[process.env.ENVIRONMENT] || config.ENVIRONMENTS.aws;
const { N_TRANSACTIONS = 128, N_ITER = 1 } = process.env;

const {
  tokenConfigs: { tokenType, tokenId },
  mnemonics,
  signingKeys,
} = config.TEST_OPTIONS;

const initTx = N_TRANSACTIONS;
const maxNIter = N_ITER;
let nf3Users = [];
const transferValue = 1;
const depositValue = 200;
let nTotalTransactions = 0;

const web3Client = new Web3Client();

let erc20Address;
let stateAddress;
const eventLogs = [];

describe('Tx worker test', () => {
  before(async () => {
    if (process.env.LAUNCH_LOCAL === '') {
      environment.clientApiUrl = `https://${process.env.CLIENT_SERVICE}.${process.env.DOMAIN_NAME}`;
      environment.clientApiTxUrl = `https://${process.env.CLIENT_TX_WORKER_SERVICE}.${process.env.DOMAIN_NAME}`;
      environment.clientApiBpUrl = `https://${process.env.CLIENT_BP_WORKER_SERVICE}.${process.env.DOMAIN_NAME}`;
    }
    nf3Users = [new Nf3(signingKeys.user1, environment), new Nf3(signingKeys.user2, environment)];
    console.log(`Generating ${N_TRANSACTIONS} transactions`);

    // Proposer listening for incoming events
    await nf3Users[0].init(mnemonics.user1);
    await nf3Users[1].init(mnemonics.user2);
    const userL1Balance = await nf3Users[0].getL1Balance(nf3Users[0].ethereumAddress);
    console.log(
      `User info - L1 Balance: ${userL1Balance}, Address: ${nf3Users[0].ethereumAddress}`,
    );
    erc20Address = await nf3Users[0].getContractAddress('ERC20Mock');

    stateAddress = await nf3Users[0].stateContractAddress;
    web3Client.subscribeTo('logs', eventLogs, { address: stateAddress });
  });

  describe('Process Transactions', () => {
    it('Initial Deposits', async function () {
      logger.info('Start');
      let balance = await getLayer2Balances(nf3Users[0], erc20Address);
      console.log('User 0 L2 Balance', balance);
      if (balance >= initTx * depositValue) return;
      console.log(`Requesting ${initTx} deposits ${erc20Address}`);
      // We create enough transactions to initialize tx workers
      await depositNTransactionsAsync(
        nf3Users[0],
        initTx,
        erc20Address,
        tokenType,
        depositValue,
        tokenId,
        0,
      );

      await waitForSufficientBalance({
        nf3User: nf3Users[0],
        value: initTx * depositValue,
        ercAddress: erc20Address,
      });

      balance = await getLayer2Balances(nf3Users[0], erc20Address);
      console.log('User 0 L2 Balance', balance);
    });

    it('Deposits/Transfers', async function () {
      for (let niter = 0; niter < maxNIter; niter++) {
        logger.info('Start');
        console.log(`Requesting ${initTx} deposits and transfers`);
        // We create enough transactions to initialize tx workers
        let balanceUser0 = await getLayer2Balances(nf3Users[0], erc20Address);
        console.log('User 0 L2 Balance', balanceUser0);
        let balanceUser1 = await getLayer2Balances(nf3Users[1], erc20Address);
        console.log('User 1 L2 Balance', balanceUser1);
        await depositNTransactionsAsync(
          nf3Users[0],
          initTx / 2,
          erc20Address,
          tokenType,
          depositValue,
          tokenId,
          0,
        );
        await transferNTransactionsAsync(
          nf3Users[0],
          initTx / 2,
          erc20Address,
          tokenType,
          transferValue,
          tokenId,
          nf3Users[1].zkpKeys.compressedZkpPublicKey,
          0,
          true,
        );
        await waitForSufficientBalance({
          nf3User: nf3Users[1],
          value: (initTx / 2) * transferValue + balanceUser1,
          ercAddress: erc20Address,
        });
      }

      // log stats for id a
      logger.info(`Total transactions sent ${nTotalTransactions}`);
    });
  });

  after(async () => {
    await nf3Users[0].close();
    await web3Client.closeWeb3();
  });
});
