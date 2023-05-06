/* eslint-disable no-await-in-loop */
import chai from 'chai';
import chaiHttp from 'chai-http';
import config from 'config';
import axios from 'axios';
import chaiAsPromised from 'chai-as-promised';
import logger from '@polygon-nightfall/common-files/utils/logger.mjs';
import Nf3 from '../cli/lib/nf3.mjs';
import {
  depositNTransactionsAsync,
  transferNTransactionsAsync,
  Web3Client,
  getLayer2Balances,
  waitForTimeout,
  waitForSufficientTransactionsMempool,
} from './utils.mjs';

// so we can use require with mjs file
chai.use(chaiHttp);
chai.use(chaiAsPromised);

// we need require here to import jsons
const environment = config.ENVIRONMENTS[process.env.ENVIRONMENT] || config.ENVIRONMENTS.aws;
const {
  N_TRANSACTIONS = 10,
  N_ITER = 1,
  BLOCK_GENERATION_MILLIS = 20000,
  N_CPUS = 16,
} = process.env;

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

async function makeBlockNow(optimistUrl) {
  await axios.post(`${optimistUrl}/block/make-now`);
}

async function setBlockPeriod(optimistUrl, timeMs) {
  logger.info(`Setting block generation period to ${timeMs} ms`);
  await axios.post(`${optimistUrl}/block/block-time`, { timeMs });
}

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
      // Disable block generation
      setBlockPeriod(environment.optimistApiBaUrl, -1);
      const balanceUser0Before = await getLayer2Balances(nf3Users[0], erc20Address);
      const balanceUser1Before = await getLayer2Balances(nf3Users[1], erc20Address);
      console.log('User 0 L2 Balance', balanceUser0Before);
      console.log('User 1 L2 Balance', balanceUser1Before);
      //if (balanceUser0Before >= initTx * depositValue) return;
      console.log(`Requesting ${initTx} deposits ${erc20Address}`);
      // We create enough transactions to initialize tx workers
      depositNTransactionsAsync(
        nf3Users[0],
        initTx,
        erc20Address,
        tokenType,
        depositValue,
        tokenId,
        0,
        N_CPUS,
      );

      await waitForSufficientTransactionsMempool({
        optimistBaseUrl: environment.optimistApiUrl,
        //nTransactions: Math.floor(Math.min(50, N_TRANSACTIONS / 4)),
        nTransactions: N_TRANSACTIONS,
      });

      let mempool = [];
      setBlockPeriod(environment.optimistApiBaUrl, 60 * 1000);
      // start building blocks
      let gains = (await getLayer2Balances(nf3Users[0], erc20Address)) - balanceUser0Before;
      let count = 0;
      while (gains < initTx * depositValue) {
        await makeBlockNow(environment.optimistApiBaUrl);
        await waitForTimeout(BLOCK_GENERATION_MILLIS);
        mempool =
          (await axios.get(`${environment.optimistApiUrl}/proposer/mempool`)).data.result ?? [];
        logger.info(`N Transactions in mempool: ${mempool.length}`);
        gains = (await getLayer2Balances(nf3Users[0], erc20Address)) - balanceUser0Before;
        console.log(`Balance gains are ${gains}/${initTx * depositValue}`);
        count += 1;
        if (count >= 100) break;
      }
      const balanceUser0After = await getLayer2Balances(nf3Users[0], erc20Address);
      const balanceUser1After = await getLayer2Balances(nf3Users[1], erc20Address);
      console.log('Balance User 0', balanceUser0After);
      console.log('Balance User 1', balanceUser1After);
    });

    it('Deposits/Transfers', async function () {
      const balanceUser0Before = await getLayer2Balances(nf3Users[0], erc20Address);
      const balanceUser1Before = await getLayer2Balances(nf3Users[1], erc20Address);
      setBlockPeriod(environment.optimistApiBaUrl, -1);
      for (let niter = 0; niter < maxNIter; niter++) {
        console.log(`Requesting ${initTx} deposits and transfers`);
        // We create enough transactions to initialize tx workers
        depositNTransactionsAsync(
          nf3Users[0],
          initTx / 2,
          erc20Address,
          tokenType,
          depositValue,
          tokenId,
          0,
          N_CPUS / 2,
        );
        transferNTransactionsAsync(
          nf3Users[0],
          initTx / 2,
          erc20Address,
          tokenType,
          transferValue,
          tokenId,
          nf3Users[1].zkpKeys.compressedZkpPublicKey,
          0,
          true,
          N_CPUS / 2,
        );
        // start building blocks
        let gains0 = (await getLayer2Balances(nf3Users[0], erc20Address)) - balanceUser0Before;
        let gains1 = (await getLayer2Balances(nf3Users[1], erc20Address)) - balanceUser1Before;
        let count = 0;

        await waitForSufficientTransactionsMempool({
          optimistBaseUrl: environment.optimistApiUrl,
          nTransactions: Math.floor(Math.min(50, N_TRANSACTIONS / 4)),
        });
        let mempool = [];
        setBlockPeriod(environment.optimistApiBaUrl, 60 * 1000);
        while (
          gains0 !== (initTx / 2) * (depositValue - transferValue) * (niter + 1) ||
          gains1 !== (initTx / 2) * transferValue * (niter + 1)
        ) {
          await makeBlockNow(environment.optimistApiBaUrl);
          await waitForTimeout(BLOCK_GENERATION_MILLIS);
          mempool =
            (await axios.get(`${environment.optimistApiUrl}/proposer/mempool`)).data.result ?? [];
          logger.info(`N Transactions in mempool: ${mempool.length}`);
          gains0 = (await getLayer2Balances(nf3Users[0], erc20Address)) - balanceUser0Before;
          gains1 = (await getLayer2Balances(nf3Users[1], erc20Address)) - balanceUser1Before;
          console.log(
            `gains0 are ${gains0}/${(initTx / 2) * (depositValue - transferValue) * (niter + 1)}`,
          );
          console.log(`gains1 are ${gains1}/${(initTx / 2) * transferValue * (niter + 1)}`);
          count += 1;
          if (count >= 1000) break;
        }
      }
      const balanceUser0After = await getLayer2Balances(nf3Users[0], erc20Address);
      const balanceUser1After = await getLayer2Balances(nf3Users[1], erc20Address);
      console.log('Balance User 0', balanceUser0After);
      console.log('Balance User 1', balanceUser1After);
      // log stats for id a
      logger.info(`Total transactions sent ${nTotalTransactions}`);
    });
  });

  after(async () => {
    await nf3Users[0].close();
    await nf3Users[1].close();
    await web3Client.closeWeb3();
  });
});
