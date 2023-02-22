import cluster from 'cluster';
import os from 'os';
import generateData from './generate-data.mjs';

const { N_TRANSACTIONS = 32 } = process.env;

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
    for (var txIdx = 0; txIdx < nTransactions; txIdx += TRANSACTIONS_PER_BLOCK * 10) {
      await generateData(TRANSACTIONS_PER_BLOCK * 10, TRANSACTIONS_PER_BLOCK);
    }

    process.exit();
  }
}

initWorkers();
