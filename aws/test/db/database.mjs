import mongo from './mongo.mjs';

const { MONGO_URL } = process.env;

const ZERO = '0x0000000000000000000000000000000000000000000000000000000000000000';
const OPTIMIST_DB = 'optimist_data';
const TRANSACTIONS_COLLECTION = 'transactions';
const SUBMITTED_BLOCKS_COLLECTION = 'blocks';
const TIMBER_COLLECTION = 'timber';

export async function saveTransaction(_transaction) {
  const transaction = {
    _id: _transaction.transactionHash,
    ..._transaction,
  };
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { transactionHash: transaction.transactionHash };
  const update = { $set: transaction };

  return db.collection(TRANSACTIONS_COLLECTION).updateOne(query, update, { upsert: true });
}

export async function saveBlock(_block) {
  const block = { _id: _block.blockHash, ..._block };
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);

  const query = { blockHash: block.blockHash };
  const update = { $set: block };

  return db.collection(SUBMITTED_BLOCKS_COLLECTION).updateOne(query, update, { upsert: true });
}

export async function saveTree(timber) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  return db.collection(TIMBER_COLLECTION).insertOne({
    _id: timber.leafCount,
    blockNumber: timber.blockNumber,
    blockNumberL2: timber.blockNumberL2,
    frontier: timber.frontier,
    leafCount: timber.leafCount,
    root: timber.root,
  });
}

// READ
export async function readRandomTransaction(nTx) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { $sample: { size: nTx } };
  return db.collection(TRANSACTIONS_COLLECTION).aggregate([query]).toArray();
}

export async function readRandomBlock(nBlocks) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { $sample: { size: nBlocks } };
  return db.collection(SUBMITTED_BLOCKS_COLLECTION).aggregate([query]).toArray();
}

export async function readRandomTree(nTree) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { $sample: { size: nTree } };
  return db.collection(TIMBER_COLLECTION).aggregate([query]).toArray();
}

export async function getBlockByTransactionHash(transactionHash) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { transactionHashes: transactionHash };
  return db.collection(SUBMITTED_BLOCKS_COLLECTION).find(query).toArray();
}

export async function getBlockByTransactionHashL1(transactionHashL1) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { transactionHashL1 };
  return db.collection(SUBMITTED_BLOCKS_COLLECTION).findOne(query);
}

/**
function to get a block by blockHash, if you know the hash of the block. This
is useful for rolling back Timber.
*/
export async function getBlockByBlockHash(blockHash) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { blockHash };
  return db.collection(SUBMITTED_BLOCKS_COLLECTION).findOne(query);
}

/**
function to get a block by root, if you know the root of the block. This
is useful for nightfall-client to establish the layer block number containing
a given (historic) root.
*/
export async function getBlockByRoot(root) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { root };
  return db.collection(SUBMITTED_BLOCKS_COLLECTION).findOne(query);
}

async function getMempoolTransaction(query) {
  //const connection = await mongo.connection(MONGO_URL);
  //const db = connection.db(OPTIMIST_DB);
  // eslint-disable-next-line no-param-reassign
  query.mempool = true;
  //return db.collection(TRANSACTIONS_COLLECTION).findOne(query);
  return mongo.collection(MONGO_URL, OPTIMIST_DB, TRANSACTIONS_COLLECTION).findOne(query);
}

export async function getMempoolTransactionByCommitment(commitmentHash, transactionFee) {
  return getMempoolTransaction({
    commitments: { $in: [commitmentHash] },
    fee: { $gt: transactionFee },
  });
}

export async function deleteDuplicateCommitmentsAndNullifiersFromMemPool(
  commitments,
  nullifiers,
  transactionHashes = [],
) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = {
    $or: [{ commitments: { $in: commitments } }, { nullifiers: { $in: nullifiers } }],
    transactionHash: { $nin: transactionHashes },
    mempool: true,
  };
  return db.collection(TRANSACTIONS_COLLECTION).deleteMany(query);
}

export async function getTransactionByCommitment(commitmentHash) {
  const query = {
    commitments: { $in: commitmentHash },
  };
  return mongo.collection(MONGO_URL, OPTIMIST_DB, TRANSACTIONS_COLLECTION).find(query).toArray();
}

export async function getTransactionByNullifier(nullifierHash) {
  const query = {
    nullifiers: { $in: nullifierHash },
  };
  return mongo.collection(MONGO_URL, OPTIMIST_DB, TRANSACTIONS_COLLECTION).find(query).toArray();
}

/**
 * Filter mempool by nullifier hash and fee
 */
export async function getMempoolTransactionByNullifier(nullifierHash, transactionFee) {
  return getMempoolTransaction({
    nullifiers: { $in: [nullifierHash] },
    fee: { $gt: transactionFee },
  });
}

/**
get the latest blockNumberL2 in our database
*/
export async function getLatestBlockInfo() {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const [blockInfo] = await db
    .collection(SUBMITTED_BLOCKS_COLLECTION)
    .find({}, { blockNumberL2: 1, blockHash: 1, blockNumber: 1 })
    .sort({ blockNumberL2: -1 })
    .limit(1)
    .toArray();
  return blockInfo ?? { blockNumberL2: -1, blockHash: ZERO };
}

/**
function to get a block by blockNumberL2, if you know the number of the block. This is useful for rolling back Timber.
*/
export async function getBlockByBlockNumberL2(blockNumberL2) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { blockNumberL2: Number(blockNumberL2) };
  return db.collection(SUBMITTED_BLOCKS_COLLECTION).findOne(query);
}

/**
function to delete a block. This is useful after a rollback event, whereby the
block no longer exists
*/
export async function deleteBlock(blockNumberL2) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { blockNumberL2: Number(blockNumberL2) };
  return db.collection(SUBMITTED_BLOCKS_COLLECTION).deleteOne(query);
}

/**
function to find blocks with a layer 2 blockNumber >= blockNumberL2
*/
export async function findBlocksFromBlockNumberL2(blockNumberL2) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { blockNumberL2: { $gte: Number(blockNumberL2) } };
  return db
    .collection(SUBMITTED_BLOCKS_COLLECTION)
    .find(query, { sort: { blockNumberL2: -1 } })
    .toArray();
}

// function that sets the Block's L1 blocknumber to null
// to indicate that it's back in the L1 mempool (and will probably be re-mined
// and given a new L1 transactionHash)
export async function clearBlockNumberL1ForBlock(transactionHashL1) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { transactionHashL1 };
  const update = { $set: { blockNumber: null } };
  return db.collection(SUBMITTED_BLOCKS_COLLECTION).updateOne(query, update);
}

/**
 * function to find blocks produced by a proposer
 */
export async function findBlocksByProposer(proposer) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { proposer };
  return db
    .collection(SUBMITTED_BLOCKS_COLLECTION)
    .find(query, { sort: { blockNumberL2: 1 } })
    .toArray();
}

/**
Function to remove a set of transactions from the layer 2 mempool once they've
been processed into a block
*/
export async function removeTransactionsFromMemPool(
  transactionHashes,
  blockNumberL2 = -1,
  timeBlockL2 = null,
) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { transactionHash: { $in: transactionHashes }, blockNumberL2: -1 };
  const update = { $set: { mempool: false, blockNumberL2, timeBlockL2 } };
  return db.collection(TRANSACTIONS_COLLECTION).updateMany(query, update);
}

/**
Function to remove a set of commitments from the layer 2 mempool once they've
been processed into an L2 block
*/
export async function deleteDuplicateCommitmentsFromMemPool(commitments, transactionHashes = []) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = {
    commitments: { $in: commitments },
    transactionHash: { $nin: transactionHashes },
    mempool: true,
  };
  return db.collection(TRANSACTIONS_COLLECTION).deleteMany(query);
}

/**
Function to remove a set of nullifiers from the layer 2 mempool once they've
been processed into an L2 block
*/
export async function deleteDuplicateNullifiersFromMemPool(nullifiers, transactionHashes = []) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = {
    nullifiers: { $in: nullifiers },
    transactionHash: { $nin: transactionHashes },
    mempool: true,
  };
  return db.collection(TRANSACTIONS_COLLECTION).deleteMany(query);
}

/**
How many transactions are waiting to be processed into a block?
*/
export async function getMempoolTxsSortedByFee() {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  return db
    .collection(TRANSACTIONS_COLLECTION)
    .find({ mempool: true }, { _id: 0 })
    .sort({ fee: -1 })
    .toArray();
}

/**
function to look a transaction by transactionHash, if you know the hash of the transaction.
*/
export async function getTransactionByTransactionHash(transactionHash) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { transactionHash };
  return db.collection(TRANSACTIONS_COLLECTION).findOne(query);
}

/**
function to find transactions with a transactionHash in the array transactionHashes.
*/
export async function getTransactionsByTransactionHashes(transactionHashes) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { transactionHash: { $in: transactionHashes } };
  const returnedTransactions = await db.collection(TRANSACTIONS_COLLECTION).find(query).toArray();
  // Create a dictionary where we will store the correct position ordering
  const positions = {};
  // Use the ordering of txHashes in the block to fill the dictionary-indexed by txHash
  // eslint-disable-next-line no-return-assign
  transactionHashes.forEach((t, index) => (positions[t] = index));
  const transactions = returnedTransactions.sort(
    (a, b) => positions[a.transactionHash] - positions[b.transactionHash],
  );
  return transactions;
}

/**
function to find transactions with a transactionHash in the array transactionHashes.
*/
export async function getTransactionsByTransactionHashesByL2Block(transactionHashes, block) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = {
    transactionHash: { $in: transactionHashes },
    blockNumberL2: { $eq: block.blockNumberL2 },
  };
  const returnedTransactions = await db.collection(TRANSACTIONS_COLLECTION).find(query).toArray();
  // Create a dictionary where we will store the correct position ordering
  const positions = {};
  // Use the ordering of txHashes in the block to fill the dictionary-indexed by txHash
  // eslint-disable-next-line no-return-assign
  transactionHashes.forEach((t, index) => (positions[t] = index));
  const transactions = returnedTransactions.sort(
    (a, b) => positions[a.transactionHash] - positions[b.transactionHash],
  );
  return transactions;
}

/*
For added safety we only delete mempool: true, we should never be deleting
transactions from our local db that have been spent.
*/
export async function deleteTransactionsByTransactionHashes(transactionHashes) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  // We should not delete from a spent mempool
  const query = { transactionHash: { $in: transactionHashes } };
  return db.collection(TRANSACTIONS_COLLECTION).deleteMany(query);
}

/**
 * Function that sets the Transactions's L1 blocknumber to null
 * to indicate that it's back in the L1 mempool (and will probably be re-mined
 * and given a new L1 transactionHash)
 */
export async function clearBlockNumberL1ForTransaction(transactionHashL1) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { transactionHashL1 };
  const update = { $set: { blockNumber: null } };
  return db.collection(TRANSACTIONS_COLLECTION).updateOne(query, update);
}

export async function getTransactionMempoolByCommitment(commitmentHash, transactionFee) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = {
    commitments: { $in: [commitmentHash] },
    fee: { $gt: transactionFee },
    mempool: true,
  };
  return db.collection(TRANSACTIONS_COLLECTION).findOne(query);
}

export async function getTransactionL2ByCommitment(commitmentHash, blockNumberL2OfTx) {
  //const connection = await mongo.connection(MONGO_URL);
  //const db = connection.db(OPTIMIST_DB);
  const query = {
    commitments: { $in: [commitmentHash] },
    blockNumberL2: { $gt: -1, $ne: blockNumberL2OfTx },
  };
  //return db.collection(TRANSACTIONS_COLLECTION).findOne(query);
  return mongo.collection(MONGO_URL, OPTIMIST_DB, TRANSACTIONS_COLLECTION).findOne(query);
}

export async function getTransactionMempoolByNullifier(nullifierHash, transactionFee) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = {
    nullifiers: { $in: [nullifierHash] },
    fee: { $gt: transactionFee },
    mempool: true,
  };
  return db.collection(TRANSACTIONS_COLLECTION).findOne(query);
}

export async function getTransactionL2ByNullifier(nullifierHash, blockNumberL2OfTx) {
  //const connection = await mongo.connection(MONGO_URL);
  //const db = connection.db(OPTIMIST_DB);
  const query = {
    nullifiers: { $in: [nullifierHash] },
    blockNumberL2: { $gt: -1, $ne: blockNumberL2OfTx },
  };
  //return db.collection(TRANSACTIONS_COLLECTION).findOne(query);
  return mongo.collection(MONGO_URL, OPTIMIST_DB, TRANSACTIONS_COLLECTION).findOne(query);
}

// This function is useful in resetting transacations that have been marked out of the mempool because
// we have included them in blocks, but those blocks did not end up being mined on-chain.
export async function resetUnsuccessfulBlockProposedTransactions() {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { blockNumberL2: -1, mempool: false }; // Transactions out of mempool but not yet on chain
  const update = { $set: { mempool: true, blockNumberL2: -1 } };
  return db.collection(TRANSACTIONS_COLLECTION).updateMany(query, update);
}

export async function getMempoolTransactions() {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  const query = { mempool: true }; // Transactions in the mempool
  return db.collection(TRANSACTIONS_COLLECTION).find(query).toArray();
}

/**
Timber functions
*/

export async function getLatestTree() {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  return db.collection(TIMBER_COLLECTION).find().sort({ blockNumberL2: -1 }).limit(1).toArray();
}

export async function getTreeByBlockNumberL2(blockNumberL2) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  return db.collection(TIMBER_COLLECTION).findOne({ blockNumberL2 });
}

export async function getTreeByLeafCount(historicalLeafCount) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  return db.collection(TIMBER_COLLECTION).findOne({ leafCount: historicalLeafCount });
}

export async function deleteTreeByBlockNumberL2(blockNumberL2) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  await db.collection(TIMBER_COLLECTION).updateOne({ blockNumberL2 }, { $set: { rollback: true } });
  await new Promise(resolve => setTimeout(() => resolve(), 1000));
  return db.collection(TIMBER_COLLECTION).deleteMany({ blockNumberL2: { $gte: blockNumberL2 } });
}

export async function getNumberOfL2Blocks() {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  return db.collection(TIMBER_COLLECTION).find().count();
}

// function to set the path of the transaction hash leaf in transaction hash timber
export async function setTransactionHashSiblingInfo(
  transactionHash,
  transactionHashSiblingPath,
  transactionHashLeafIndex,
  transactionHashesRoot,
) {
  const connection = await mongo.connection(MONGO_URL);
  const query = { transactionHash };
  const update = {
    $set: { transactionHashSiblingPath, transactionHashLeafIndex, transactionHashesRoot },
  };
  const db = connection.db(OPTIMIST_DB);
  return db.collection(TRANSACTIONS_COLLECTION).updateMany(query, update, { upsert: true });
}

// function to get the path of the transaction hash leaf in transaction hash timber
export async function getTransactionHashSiblingInfo(transactionHash) {
  const connection = await mongo.connection(MONGO_URL);
  const db = connection.db(OPTIMIST_DB);
  return db.collection(TRANSACTIONS_COLLECTION).findOne(
    { transactionHash },
    {
      projection: {
        transactionHashSiblingPath: 1,
        transactionHashLeafIndex: 1,
        transactionHashesRoot: 1,
        isOnChain: 1,
      },
    },
  );
}
