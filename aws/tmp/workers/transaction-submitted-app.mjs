// ignore unused exports default

/*
  Implementation of a cluster of workers that handle transaction submitted events.

  This cluster of workers is provided as a complementary service to optimist to process
  transactions received in order to boost performance, so that optimist can focus on other activities.
  Optimist doesn't need to use this cluster of workers and can keep processing transactions
  received. To configure Optimist in legacy mode, just provide and invalid value to TX_WORKER_URL.

  Else, the cluster of workers will provide three services to optimist:
  - app.post('/workers/transaction-submitted') : Takes an incomming transaction received by transactionSubmittedEventHandler and
  dispatch it to an available worker
  - app.post('/proposer/offchain-transaction') : Processes offchain transaction. This is the endpoint that optimist
  can advertise when registering as a proposer so that clients send transactions here.
  - app.post('/workers/check-transaction') : Performs several checks on transactions (check duplicate commitment and nullifier, checks
     historic root block number and verifies transaction proof). It is thought mainly to offload optimist from
     processing transactions during block proposed events.
*/

import express from 'express';
import cluster from 'cluster';
import config from 'config';
import os from 'os';
import logger from '@polygon-nightfall/common-files/utils/logger.mjs';
import constants from '@polygon-nightfall/common-files/constants/index.mjs';
import { waitForContract } from '@polygon-nightfall/common-files/utils/contract.mjs';

import {
  submitTransaction,
  transactionSubmittedEventHandler,
} from '../event-handlers/transaction-submitted.mjs';

import { checkTransaction } from '../services/transaction-checker.mjs';

const { txWorkerCount } = config.TX_WORKER_PARAMS;
const { STATE_CONTRACT_NAME } = constants;

async function initWorkers() {
  if (cluster.isPrimary) {
    const totalCPUs = Math.min(os.cpus().length - 1, Number(txWorkerCount));

    logger.info(`Number of CPUs is ${totalCPUs}`);

    // Fork workers.
    for (let i = 0; i < totalCPUs; i++) {
      cluster.fork();
    }

    cluster.on('exit', worker => {
      logger.error(`worker ${worker.process.pid} died. Forking another one!`);
      cluster.fork();
    });
  } else {
    const app = express();
    app.use(express.json());
    logger.info(`Worker ${process.pid} started`);

    // Standard healthhcheck
    app.get('/healthcheck', async (req, res) => {
      res.sendStatus(200);
    });

    // End point to submit transactions to tx worker. It is called
    // by Optimist when receiving onchain transactions
    app.post('/workers/transaction-submitted', async (req, res) => {
      const { eventParams, enable } = req.body;
      try {
        const response = submitTransaction(eventParams, enable);
        res.json(response);
      } catch (err) {
        res.sendStatus(500);
      }
    });

    // End point to check transaction to tx worker. Called by
    // block proposed event handler
    app.post('/workers/check-transaction', async (req, res) => {
      const { transaction, transactionBlockNumberL2 } = req.body;
      try {
        await checkTransaction({
          transaction,
          checkDuplicatesInL2: true,
          checkDuplicatesInMempool: true,
          transactionBlockNumberL2,
        });
        res.sendStatus(200);
      } catch (err) {
        res.send({ err });
      }
    });

    // Handles offchain transactions
    app.post('/proposer/offchain-transaction', async (req, res) => {
      const { transaction } = req.body;
      logger.info({ msg: 'Offchain transaction request received', transaction });
      /*
        When a transaction is built by client, they are generalised into hex(32) interfacing with web3
        The response from on-chain events converts them to saner string values (e.g. uint64 etc).
        Since we do the transfer off-chain, we do the conversation manually here.
       */
      const { circuitHash, fee } = transaction;

      try {
        const stateInstance = await waitForContract(STATE_CONTRACT_NAME);
        const circuitInfo = await stateInstance.methods.getCircuitInfo(circuitHash).call();
        if (circuitInfo.isEscrowRequired) {
          res.sendStatus(400);
        } else {
          /*
              When comparing this with getTransactionSubmittedCalldata,
              note we dont need to decompressProof as proofs are only compressed if they go on-chain.
          */
          transactionSubmittedEventHandler({
            offchain: true,
            ...transaction,
            fee: Number(fee),
          });

          res.sendStatus(200);
        }
      } catch (err) {
        res.sendStatus(400);
      }
    });

    app.listen(80);
  }
}

initWorkers();

export default initWorkers;
