/* eslint-disable no-await-in-loop */
import chai from 'chai';
import chaiHttp from 'chai-http';
import config from 'config';
import chaiAsPromised from 'chai-as-promised';
import axios from 'axios';
import Nf3 from '../cli/lib/nf3.mjs';
import {
  depositNTransactions,
  transferNTransactions,
  Web3Client,
  waitForTimeout,
} from './utils.mjs';
import {
  numberOfMempoolTransactions,
  numberOfBufferedTransactions,
} from '../nightfall-optimist/src/services/database.mjs';

// so we can use require with mjs file
chai.use(chaiHttp);
chai.use(chaiAsPromised);

// we need require here to import jsons
const environment = config.ENVIRONMENTS[process.env.ENVIRONMENT] || config.ENVIRONMENTS.localhost;
const { optimistTxWorkerApiUrl } = environment;
const { N_TRANSACTIONS = 2 } = process.env;

const {
  tokenConfigs: { tokenType, tokenId },
  mnemonics,
  signingKeys,
} = config.TEST_OPTIONS;

const initTx = N_TRANSACTIONS;
const nf3Users = [new Nf3(signingKeys.user1, environment), new Nf3(signingKeys.user2, environment)];
const nf3Proposer1 = new Nf3(signingKeys.proposer1, environment);
const transferValue = 1;
const depositValue = 200;

const web3Client = new Web3Client();

let erc20Address;
let stateAddress;
const eventLogs = [];
let txPerSecondWorkersOn;

// Generated deposits and transfers
const generateNTransactions = async () => {
  // disable worker processing and store transactions in tmp collection
  await axios.post(`${environment.optimistApiUrl}/debug/transaction-submitted-enable`, {
    enable: false,
  });
  // Deposits to cover some transfers
  console.log(`Requesting ${Math.ceil(initTx / 2)} deposits`);
  await depositNTransactions(
    nf3Users[0],
    Math.ceil(initTx / 2),
    erc20Address,
    tokenType,
    depositValue,
    tokenId,
    0,
  );

  // Transfers covered by deposits
  const balance = await nf3Users[0].getLayer2Balances();
  const submittedTransfers = Math.min(
    Math.ceil(initTx / 2),
    Math.floor(balance[erc20Address][0].balance / depositValue),
  );
  console.log(`Requesting ${submittedTransfers} transfers`);
  await transferNTransactions(
    nf3Users[0],
    submittedTransfers,
    erc20Address,
    tokenType,
    transferValue,
    tokenId,
    nf3Users[0].zkpKeys.compressedZkpPublicKey,
    0,
    true,
  );

  let nTx = 0;
  let nTx1 = 0;
  let nTotalTx = Math.ceil(initTx / 2) + submittedTransfers;
  let retries = 0;
  // Wait until all transactions are generated
  while (nTx < nTotalTx && retries < 10) {
    nTx = await numberOfBufferedTransactions();
    console.log(`N buffered transactions ${nTx}/${nTotalTx}`);
    await waitForTimeout(1000);
    retries++;
  }

  nTotalTx = (await numberOfBufferedTransactions()) + (await numberOfMempoolTransactions());
  nTx = await numberOfMempoolTransactions();
  console.log(`Start transaction processing ${nTx}/${nTotalTx}`);
  // enable worker processing and process transactions in tmp
  axios.post(`${environment.optimistApiUrl}/debug/transaction-submitted-enable`, { enable: true });
  const startTimeTx = new Date().getTime();
  // while unprocessed transactions (nTx) is less than number of transactions generated (initTx),
  // and number of transactions increases (first block is generated)
  retries = 0;
  while (nTx >= nTx1 && nTx < nTotalTx && retries < 30) {
    nTx1 = nTx;
    nTx = await numberOfMempoolTransactions();
    console.log(`N Unprocessed transactions ${nTx}/${nTotalTx}`);
    await waitForTimeout(100);
    retries++;
  }
  const elapsedTimeTx = new Date().getTime() - startTimeTx;
  return elapsedTimeTx !== 0 ? (initTx * 1000) / elapsedTimeTx : 0;
};

async function makeBlock() {
  console.log(`Make block...`);
  await nf3Proposer1.makeBlockNow();
  await web3Client.waitForEvent(eventLogs, ['blockProposed']);
}

describe('Tx worker test', () => {
  before(async () => {
    await nf3Proposer1.init(mnemonics.proposer);
    try {
      erc20Address = await nf3Proposer1.getContractAddress('ERC20Mock');
    } catch {
      erc20Address = '0x4315287906f3FCF2345Ad1bfE0f682457b041Fa7';
    }
    const propoposerL1Balance = await nf3Proposer1.getL1Balance(nf3Proposer1.ethereumAddress);
    const minStake = await nf3Proposer1.getMinimumStake();
    console.log(
      `Proposer info - L1 Balance: ${propoposerL1Balance}, Minimum Stake: ${minStake}, Address: ${nf3Proposer1.ethereumAddress}`,
    );
    if (propoposerL1Balance === '0') {
      console.log('Not enough balance in proposer');
      process.exit();
    }

    console.log(`Connecting to TX Workers at ${optimistTxWorkerApiUrl}`);
    await nf3Proposer1.registerProposer(optimistTxWorkerApiUrl, minStake);
    await nf3Proposer1.startProposer();

    console.log(`Generating ${N_TRANSACTIONS} transactions`);

    // Proposer listening for incoming events
    await nf3Users[0].init(mnemonics.user1);
    const userL1Balance = await nf3Users[0].getL1Balance(nf3Users[0].ethereumAddress);
    console.log(
      `User info - L1 Balance: ${userL1Balance}, Address: ${nf3Users[0].ethereumAddress}`,
    );

    stateAddress = await nf3Users[0].stateContractAddress;
    web3Client.subscribeTo('logs', eventLogs, { address: stateAddress });
  });

  describe('Process Transactions', () => {
    /**
     * In this first phase, we want to generate as many transactions as workers to
     * ensure that these workers have enough time to cache intermediate data to
     * speed up the process
     */
    it('Initialize tx worker', async function () {
      const balance = await nf3Users[0].getLayer2Balances();
      console.log('L2 Balance', balance);
      // enable workers
      await axios.post(`${environment.optimistApiUrl}/workers/transaction-worker-enable`, {
        enable: true,
      });
      // disable worker processing and store transactions in tmp collection
      await axios.post(`${environment.optimistApiUrl}/debug/transaction-submitted-enable`, {
        enable: false,
      });
      // We create enough transactions to initialize tx workers
      await depositNTransactions(
        nf3Users[0],
        initTx,
        erc20Address,
        tokenType,
        depositValue,
        tokenId,
        0,
      );

      let nTx = 0;
      // Wait until all transactions are generated
      while (nTx < initTx) {
        nTx = await numberOfBufferedTransactions();
        console.log('N buffered transactions', nTx);
        await waitForTimeout(1000);
      }
      console.log('Start transaction processing...');
      // enable worker processing and process transactions in tmp
      axios.post(`${environment.optimistApiUrl}/debug/transaction-submitted-enable`, {
        enable: true,
      });
      // leave some time for transaction processing
      await waitForTimeout(1000);
      let pendingTx = 1;
      // In this second part, measure time it takes to generate blocks
      while (pendingTx) {
        console.log('Pending transactions:', pendingTx);
        await makeBlock();
        pendingTx = await numberOfMempoolTransactions();
      }
      console.log('Pending transactions:', pendingTx);
    });

    /**
     * In this test, we generate and buffer transactions, and measure how long it takes to
     * process them all at once with workers.
     */

    it('Generate transactions and measure transaction processing and block assembly time with workers on', async function () {
      let pendingTx = 1;
      const blockTimestamp = [];
      let startTime;
      // enable workers
      await axios.post(`${environment.optimistApiUrl}/workers/transaction-worker-enable`, {
        enable: true,
      });
      txPerSecondWorkersOn = await generateNTransactions();
      console.log('Transactions per second', txPerSecondWorkersOn);

      // In this second part, measure time it takes to generate blocks
      while (pendingTx) {
        console.log('Pending transactions:', pendingTx);
        startTime = new Date().getTime();
        await makeBlock();
        blockTimestamp.push(new Date().getTime() - startTime);
        pendingTx = await numberOfMempoolTransactions();
      }
      console.log('Block times', blockTimestamp);
    });

    /**
     * In this test, we generate and buffer transactions, and measure how long it takes to
     * process them all at once without workers.
     */
    it('Generate transactions and measure transaction processing and block assembly time with workers off', async function () {
      let pendingTx = 1;
      const blockTimestamp = [];
      let startTime;
      // disable workers
      await axios.post(`${environment.optimistApiUrl}/workers/transaction-worker-enable`, {
        enable: false,
      });
      const txPerSecond = await generateNTransactions();
      console.log('Transactions per second', txPerSecond);
      // check that we can process more than 50 transactions per second. In reality, it should be more.
      expect(txPerSecondWorkersOn).to.be.greaterThan(txPerSecond);

      // In this second part, measure time it takes to generate blocks
      while (pendingTx) {
        console.log('Pending transactions:', pendingTx);
        startTime = new Date().getTime();
        await makeBlock();
        blockTimestamp.push(new Date().getTime() - startTime);
        pendingTx = await numberOfMempoolTransactions();
      }
      console.log('Block times', blockTimestamp);
    });
  });

  after(async () => {
    await nf3Proposer1.deregisterProposer();
    await nf3Proposer1.close();
    await nf3Users[0].close();
    await web3Client.closeWeb3();
  });
});
