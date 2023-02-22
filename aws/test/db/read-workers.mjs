import cluster from 'cluster';
import os from 'os';
import * as db from './database.mjs';
import { performance, PerformanceObserver } from 'node:perf_hooks';
import { checkTransaction } from './transactions.mjs';
import {
  deleteDuplicateCommitmentsAndNullifiersFromMemPool,
  saveTransaction,
} from './database.mjs';

const { N_TRANSACTIONS = 32 } = process.env;

function sample(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

//  ip addr show docker0
async function initWorkers() {
  const nTransactions = Number(N_TRANSACTIONS);
  const TRANSACTIONS_PER_BLOCK = 32;
  if (cluster.isPrimary) {
    const totalCPUs = Math.min(os.cpus().length - 1);

    // Fork workers.
    for (let i = 0; i < totalCPUs; i++) {
      cluster.fork();
    }
  } else {
    // instantiate an observer that will format the performance report
    const perfObserver = new PerformanceObserver(items => {
      items.getEntries().forEach(entry => {
        console.log(entry);
      });
    });
    perfObserver.observe({ entryTypes: ['measure'], buffer: true });

    //const blocks = await db.readRandomBlock(100);
    const transactions = await db.readRandomTransaction(1);
    //const timber = await db.readRandomTree(100);
    performance.mark('start');

    // This is the transaction submitted event handler:
    //  - Check transactions (nullifier and commitment duplicate verification, root, and proof)
    //  - For the transactions that pass this check, we delete duplicate commitments and nullifiers in mempool and save transactions
    for (const transaction of transactions) {
      /*
      const [transactionCommitments, transactionNullifiers] = await checkTransaction({
        transaction,
        checkDuplicatesInL2: true,
        checkDuplicatesInMempool: true,
      });
      */

      // Check Transactions
      checkTransaction({
        transaction,
        checkDuplicatesInL2: true,
        checkDuplicatesInMempool: true,
      })
        // If ok, then delete duplicate nullifiers and commitments from mempool and
        //  save transactions
        .then(tx => {
          // can we do async?
          deleteDuplicateCommitmentsAndNullifiersFromMemPool(
            tx[0][0].commitments,
            tx[1][0].nullifiers,
          ).then(saveTransaction({ ...transaction }));
        })
        // if transaction did not verify, just raise error
        .catch(err => console.log('ERROR', err));

      //await saveTransaction({ ...transaction });
    }
    /*
    for (let i = 0; i < 1; i++) {
      await db.getBlockByTransactionHash(sample(transactions).transactionHash);
    }
    */
    performance.mark('end');
    performance.measure('mongodb-access', 'start', 'end');
  }
}

initWorkers();
