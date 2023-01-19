import fs from 'fs';

const { TRANSACTIONS_PER_BLOCK = 2, N_TRANSACTIONS = 4, STARTING_L2_BLOCK = 0 } = process.env;

//const blocks = JSON.parse(fs.readFileSync('./data/blocks.json','utf-8'));
//const transactions = JSON.parse(fs.readFileSync('./data/transactions.json', 'utf-8'));
const COMPRESSED_SECRETS_LENGTH = 8;
const PROOF_LENGTH = 8;

function randomHex(length) {
  var result = '0x0';
  const characters = 'ABCDEF0123456789';
  for (var i = 0; i < length; i++) {
    result += characters.charAt(Math.floor(Math.random() * characters.length));
  }
  return result;
}

function randomInt(max) {
  return Math.floor(Math.random() * max);
}

function generateTransactions(nTransactions) {
  const transactions = [];
  for (var i = 0; i < nTransactions; i++) {
    const transaction = {};
    const commitments = [];
    const nullifiers = [];
    const compressedSecrets = [];
    const proof = [];
    const rootL2 = [];
    transaction.transactionHash = randomHex(63);
    transaction.ercAddress = randomHex(63);
    transaction.blockNumber = randomInt(10000);
    transaction.blockNumberL2 = randomInt(10000);
    transaction.fee = 10;
    transaction.mempool = false;
    transaction.recipientAddress = randomHex(63);
    transaction.tokenId = randomHex(63);
    transaction.tokenType = '0';
    transaction.transactionHashL1 = randomHex(63);
    transaction.transactionType = '0';
    transaction.value = '1';

    for (var j1 = 0; j1 < 2; j1++) {
      commitments.push(randomHex(63));
      nullifiers.push(randomHex(63));
      rootL2.push(String(randomInt(100)));
    }
    transaction.commitments = commitments;
    transaction.nullifiers = nullifiers;
    transaction.historicRootBlockNumberL2 = rootL2;

    for (var j2 = 0; j2 < COMPRESSED_SECRETS_LENGTH; j2++) {
      compressedSecrets.push(randomHex(63));
    }
    transaction.compressedSecrets = compressedSecrets;

    for (var j3 = 0; j3 < PROOF_LENGTH; j3++) {
      proof.push(randomHex(63));
    }
    transaction.proof = proof;

    transactions.push(transaction);
  }
  return transactions;
}

function generateBlocks(transactions) {
  const blocks = [];
  for (var blockIdx = 0; blockIdx < transactions.length / TRANSACTIONS_PER_BLOCK; blockIdx++) {
    const block = {};
    const transactionHashes = [];
    block.blockHash = randomHex(63);
    block.blockNumber = randomInt(1000);
    block.blockNumberL2 = blockIdx + Number(STARTING_L2_BLOCK);
    block.leafCount = randomInt(100);
    block.nCommitments = 2;
    block.previousBlockHash = randomHex(63);
    block.proposer = randomHex(63);
    block.transactionHashL1 = randomHex(63);
    for (var transactionIdx = 0; transactionIdx < TRANSACTIONS_PER_BLOCK; transactionIdx++) {
      transactionHashes.push(
        transactions[transactionIdx + blockIdx * TRANSACTIONS_PER_BLOCK].transactionHash,
      );
    }
    block.transactionHashes = transactionHashes;
    blocks.push(block);
  }

  return blocks;
}

function generateTimber(blocks) {
  const timberArray = [];
  for (const block of blocks) {
    const timber = {};
    timber.frontier = [];
    for (var timberIdx = 0; timberIdx < 6; timberIdx++) {
      timber.frontier.push(randomHex(63));
    }
    timber.blockNumberL2 = block.blockNumberL2;
    timber.leafCount = randomInt(63);
    timber.blockNumber = block.blockNumber;
    timber.root = randomHex(63);
    timberArray.push(timber);
  }
  return timberArray;
}

async function main() {
  const transactions = generateTransactions(N_TRANSACTIONS);
  const blocks = generateBlocks(transactions, TRANSACTIONS_PER_BLOCK);
  const timber = generateTimber(blocks);

  fs.writeFileSync('../data/blocks.json', JSON.stringify(blocks, null, 2));
  fs.writeFileSync('../data/transactions.json', JSON.stringify(transactions, null, 2));
  fs.writeFileSync('../data/timber.json', JSON.stringify(timber, null, 2));
}

main();
