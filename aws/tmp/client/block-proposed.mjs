/* eslint-disable import/no-cycle */
import config from 'config';
import logger from '@polygon-nightfall/common-files/utils/logger.mjs';
import axios from 'axios';
import Timber from '@polygon-nightfall/common-files/classes/timber.mjs';
import constants from '@polygon-nightfall/common-files/constants/index.mjs';
import { getCircuitHash } from '@polygon-nightfall/common-files/utils/worker-calls.mjs';
import { getTimeByBlock } from '@polygon-nightfall/common-files/utils/block-utils.mjs';
import { waitForTimeout } from '@polygon-nightfall/common-files/utils/utils.mjs';
import gen from 'general-number';
import * as pm from '@polygon-nightfall/common-files/utils/stats.mjs';
import {
  markNullifiedOnChain,
  markOnChain,
  setSiblingsInfo,
  storeCommitments,
} from '../services/commitment-storage.mjs';
import { getProposeBlockCalldataPromise } from '../services/process-calldata.mjs';
import { zkpPrivateKeys, nullifierKeys } from '../services/keys.mjs';
import {
  getTreeByBlockNumberL2,
  saveTree,
  saveBlock,
  setTransactionsHashSiblingInfo,
  getNumberOfL2Blocks,
  saveTransactions,
} from '../services/database.mjs';
import {
  decryptCommitment,
  getLocalCommitments,
  getLocalNullifiers,
} from '../services/commitment-sync.mjs';
import { syncState } from '../services/state-sync.mjs';

const {
  TIMBER_HEIGHT,
  HASH_TYPE,
  TXHASH_TREE_HASH_TYPE,
  NIGHTFALL_REGULATOR_PRIVATE_KEY,
  CBDC_PUBLISHER_ENABLE,
} = config;
const { ZERO, WITHDRAW } = constants;

const { generalise } = gen;
let withdrawCircuitHash = null;

// Stores latest L1 block number correctly synchronized to speed possible resyncs
let lastInOrderL1BlockNumber = 'earliest';
// Counter to monitor resync attempts in case something is wrong we can force a
//   full resync
let consecutiveResyncAttempts = 0;

// promises to control that write to dB operations are finished on time
let storeTreeRes;
let saveBlockRes;
let markNullifiedOnChainRes;
let markOnChainRes;

async function updateWithdrawSiblingInfo(block, localWithdrawTransactionFlag, saveTxStatus) {
  // If this L2 block contains withdraw transactions known to this client,
  // the following needs to be saved for later to be used during finalise/instant withdraw
  // 1. Save sibling path for the withdraw transaction hash that is present in transaction hashes timber tree
  // 2. Save transactions hash of the transactions in this L2 block that contains withdraw transactions for this client
  // transactions hash is a linear hash of the transactions in an L2 block which is calculated during proposeBlock in
  // the contract

  // if any local withdwaw transaction in the current batch, we need to update the tree.
  if (localWithdrawTransactionFlag.size > 0) {
    let height = 1;
    while (2 ** height < block.transactionHashes.length) {
      ++height;
    }
    const transactionHashesTimber = new Timber(...[, , , ,], TXHASH_TREE_HASH_TYPE, height);
    const updatedTransactionHashesTimber = Timber.statelessUpdate(
      transactionHashesTimber,
      block.transactionHashes,
      TXHASH_TREE_HASH_TYPE,
      height,
    );

    // compute sibling path for all transactions
    const siblingPathTransactionHash = [];
    block.transactionHashes.map((transactionHash, i) => {
      if (localWithdrawTransactionFlag.has(transactionHash)) {
        const sp = updatedTransactionHashesTimber.getSiblingPath(transactionHash);
        siblingPathTransactionHash.push({
          updateOne: {
            // eslint-disable-next-line prettier/prettier
            filter: { transactionHash },
            // eslint-disable-next-line prettier/prettier
            update: {
              $set: {
                _id: transactionHash,
                transactionHashSiblingPath: sp,
                transactionHashLeafIndex: transactionHashesTimber.leafCount + i,
                transactionHashesRoot: updatedTransactionHashesTimber.root,
              },
            },
          },
        });
      }
      return null;
    });

    logger.info('Updating transactions hash sibling info');
    // ensure transactions are written first, and then move on to writing sibling path.
    saveTxStatus.then(async () => {
      // it requires some timeout to allow dB consolitdation
      await waitForTimeout(20);
      setTransactionsHashSiblingInfo(siblingPathTransactionHash);
    });
  }
}

// Function performs several checks and actions on received transactions:
//  - Decrypts transactions in block.
//  - Checks if transaction needs to be saved. Only transactions including a
//     local nonzero commitment/nullifier are saved. If any transaction in a block is saved,
//     the block is also saved.
//  - Signals which local commitments are included as the first commitment in transactions so
//     that sibling path can be computed.
//  - Signals which transactions known to us are withdrawals so that the sibling path can be
//     computed.
async function processTransactions(
  transactions,
  blockCommitments,
  block,
  timeBlockL2,
  transactionHashL1,
  blockNumber,
) {
  const { blockNumberL2 } = block;
  // filter all nonzero nullifiers from block
  const blockNullifiers = transactions
    .map(t => t.nullifiers.filter(n => n !== ZERO))
    .flat(Infinity);

  // Promise to save transactions
  pm.start('processTx - getCommNull');
  // retrieve local commitments and nullifiers from block and
  // store a true/false flag for each commitment/nulligier of every transaction included in a block
  // indicating if that commitment is local. True means is local. It's reused when
  // computing sibling path for local commitments
  const [localNonZeroCommitmentsFlag, localNonZeroNullifiersFlag] = await Promise.all([
    getLocalCommitments(blockCommitments),
    getLocalNullifiers(blockNullifiers),
  ]);
  pm.stop('processTx - getCommNull');
  // it is important to separate localNonZeroCommitments in two groups, onchain and pending
  // The reason is to avoid overwriting duplicated commitments
  // local pending commitments
  const localPendingNonZeroCommitmentsFlag = localNonZeroCommitmentsFlag[0];
  // local onchain commitments
  const localOnChainNonZeroCommitmentsFlag = localNonZeroCommitmentsFlag[1];
  // stores transaction hashes of transactions known to us. Its is cached for computing
  //  the sibling path for withdraw transactions later on
  const localWithdrawTransactionFlag = new Set();

  // check if we know withdraw hash. Else, retrieve it and cache it.
  if (withdrawCircuitHash === null) {
    withdrawCircuitHash = generalise(await getCircuitHash(WITHDRAW)).hex(5);
  }

  let saveTxStatus;
  let storeCommitmentsStatus;

  pm.start('processTx - AllTx');
  const transactionsAndCommitmentsPromises = transactions.map(async transaction => {
    pm.start('processTx - singleTx');
    let saveTxToDb = false;
    let isDecrypted = false;

    // filter out non zero commitments and nullifiers in transaction
    const nonZeroCommitmentsTx = transaction.commitments.filter(c => c !== ZERO);
    const nonZeroNullifiersTx = transaction.nullifiers.filter(n => n !== ZERO);
    const localPendingNonZeroCommitmentTx0Flag = localPendingNonZeroCommitmentsFlag.has(
      nonZeroCommitmentsTx[0],
    );
    const localOnChainNonZeroCommitmentTx0Flag = localOnChainNonZeroCommitmentsFlag.has(
      nonZeroCommitmentsTx[0],
    );
    const compressedSecretsFlag =
      transaction.compressedSecrets[0] !== ZERO || transaction.compressedSecrets[1] !== ZERO;
    logger.info({
      msg: 'Local nonzero commitments',
      pending: Array.from(localPendingNonZeroCommitmentsFlag),
      onchain: Array.from(localOnChainNonZeroCommitmentsFlag),
    });

    // In order to check if the transaction is a transfer, we check if the compressed secrets
    // are different than zero, and also that the first commitment is not known to us.
    let decryptedCommitment = {};
    if (
      // onchainCommitments have been already decrypted, so no need to decrypt again
      !localOnChainNonZeroCommitmentTx0Flag &&
      compressedSecretsFlag
    ) {
      pm.start('processTx - Decrypt');
      decryptedCommitment = await decryptCommitment(
        transaction,
        zkpPrivateKeys,
        nullifierKeys,
        nonZeroCommitmentsTx[0],
        blockNumberL2,
        blockNumber,
      );
      if (Object.keys(decryptedCommitment).length) {
        logger.info(`Decrypted Commitments...${nonZeroCommitmentsTx[0]}`);
        isDecrypted = true;
      }
      // this transaction wasnt intended any user managed by this client now. But
      // it can be in the future. So we flag transaction for saving.
      saveTxToDb = true;
      // Add new decrypted commitment to our list list of local commitments
      localPendingNonZeroCommitmentsFlag.add(nonZeroCommitmentsTx[0]);
      pm.stop('processTx - Decrypt');
    }
    // Check if received transaction includes local commitments or nullifiers, and if so
    //  transaction needs to be saved. Here we check commitments
    else if (localPendingNonZeroCommitmentTx0Flag) {
      saveTxToDb = true;
    }

    // Check if received tranaction includes nullifiers
    if (nonZeroNullifiersTx.some(n => localNonZeroNullifiersFlag.has(n))) {
      saveTxToDb = true;
      // Get all withdraw transactions known to this client
      if (transaction.circuitHash === withdrawCircuitHash) {
        localWithdrawTransactionFlag.add(transaction.transactionHash);
      }
    }

    pm.stop('processTx - singleTx');
    // transactions flagged to be saved are returned to be written in bulk
    const savedTransaction = {};
    if (saveTxToDb) {
      savedTransaction.updateOne = {
        // eslint-disable-next-line prettier/prettier
        filter: { transactionHash: transaction.transactionHash },
        // eslint-disable-next-line prettier/prettier
        update: {
          $set: {
            _id: transaction.transactionHash,
            transactionHashL1,
            blockNumber,
            blockNumberL2,
            timeBlockL2,
            isDecrypted,
            ...transaction,
          },
        },
        // eslint-disable-next-line prettier/prettier
        upsert: true,
      };
    }
    return { savedTransaction, decryptedCommitment };
  });

  pm.stop('processTx - AllTx');

  pm.start('processTx - saveTx');
  const transactionsAndCommitments = await Promise.all(transactionsAndCommitmentsPromises);
  const transactionsToSave = transactionsAndCommitments
    .map(tx => tx.savedTransaction)
    .filter(tx => Object.keys(tx).length);
  const commitmentsToSave = transactionsAndCommitments
    .map(c => c.decryptedCommitment)
    .filter(c => Object.keys(c).length);

  // Save transactions if necessary. withdaw path configuration requires transactions on dB
  logger.info({
    msg: 'Transaction summary',
    txToSave: transactionsToSave.length,
    txToDecrypt: commitmentsToSave.length,
    blockNumberL2,
  });
  if (transactionsToSave.length) {
    saveTxStatus = saveTransactions(transactionsToSave);
  }
  // Save decrypted commitments
  if (commitmentsToSave.length) {
    storeCommitmentsStatus = storeCommitments(commitmentsToSave);
  }

  pm.stop('processTx - saveTx');

  pm.start('processTx - markNullifierOnChain');
  const nullifiersToMark = Array.from(localNonZeroNullifiersFlag);
  // Mark block nullifiers on chain
  if (blockNullifiers.length) {
    logger.info({
      msg: 'Mark nullifiers on chain',
      blockNumberL2,
      localNullifiersSize: localNonZeroNullifiersFlag.size,
    });
    markNullifiedOnChainRes = markNullifiedOnChain(
      nullifiersToMark,
      blockNumberL2,
      blockNumber,
      transactionHashL1,
    );
  }
  pm.stop('processTx - markNullifierOnChain');

  pm.start('processTx - markOnChain');
  const commitmentsToMark = Array.from(localPendingNonZeroCommitmentsFlag);
  // Mark block commitments on chain
  if (blockCommitments.length) {
    logger.info({
      msg: 'Mark commitments on chain',
      blockNumberL2,
      localCommitmentsSize: localPendingNonZeroCommitmentsFlag.size,
    });
    markOnChainRes = markOnChain(commitmentsToMark, blockNumberL2, blockNumber, transactionHashL1);
  }
  pm.stop('processTx - markOnChain');

  return [
    transactionsToSave.length > 0,
    localPendingNonZeroCommitmentsFlag,
    localWithdrawTransactionFlag,
    saveTxStatus,
    storeCommitmentsStatus,
  ];
}

// Write updated sibling info to commitment
async function updateCommitmentSiblingInfo(
  blockCommitments,
  localPendingNonZeroCommitmentsFlag,
  latestTree,
  updatedTimberRoot,
  storeCommitmentsStatus,
  blockNumberL2,
  blockNumber,
  transactionHashCommittedL1,
) {
  // compute sibling path in stages. Init function initializes the new tree, and
  // computation is finalized in Complete step for every new leave added
  if (localPendingNonZeroCommitmentsFlag.size) {
    logger.debug('Updating commitments sibling info');
    const finalTree = Timber.statelessSiblingPathInit(
      latestTree,
      blockCommitments,
      HASH_TYPE,
      TIMBER_HEIGHT,
    );

    const updatedCommitments = [];
    blockCommitments.map((c, i) => {
      let sp = null;
      if (localPendingNonZeroCommitmentsFlag.has(c)) {
        sp =
          finalTree === null
            ? { siblingPath: { isMember: false, path: [] } }
            : Timber.statelessSiblingPathComplete(
                finalTree,
                blockCommitments[i],
                latestTree.leafCount + i,
              );
        // compute sibling info to be written to mongo in bulk write operation
        updatedCommitments.push({
          updateOne: {
            // eslint-disable-next-line prettier/prettier
            filter: { _id: c },
            // eslint-disable-next-line prettier/prettier
            update: {
              $set: {
                siblingPath: sp,
                leafIndex: latestTree.leafCount + i,
                root: updatedTimberRoot,
                isOnChain: Number(blockNumberL2),
                blockNumber,
                transactionHashCommittedL1,
              },
            },
            // eslint-disable-next-line prettier/prettier
            upsert: true, // upsert is needed in case we are storing sibling path for unknown commitments
          },
        });
      }
      return null;
    });
    // Add sibling info to dB after commitments are written.
    Promise.all([storeCommitmentsStatus]).then(async () => {
      // may require some timeout to allow consolidation of dB
      await waitForTimeout(20);
      setSiblingsInfo(updatedCommitments);
    });
  }
}

function buildTree(latestTree, blockCommitments) {
  // Build and save updated tree
  const updatedTimber = Timber.statelessUpdate(
    latestTree,
    blockCommitments,
    HASH_TYPE,
    TIMBER_HEIGHT,
  );
  return updatedTimber;
}

async function storeTree(updatedTimber, transactionHashL1, block, syncing) {
  logger.debug({
    msg: 'Saved tree for L2 block',
    blockNumberL2: block.blockNumberL2,
  });

  return saveTree(transactionHashL1, block.blockNumberL2, updatedTimber).catch(err => {
    // while initial syncing we avoid duplicates errors
    if (!syncing || !err.message.includes('duplicate key')) throw err;
  });
}

/**
 * This handler runs whenever a BlockProposed event is emitted by the blockchain
 */
async function blockProposedEventHandler(data, syncing = false) {
  pm.start('blockProposedEventHandler');
  const { blockNumber: currentBlockCount, transactionHash: transactionHashL1 } = data;
  let transactions;
  let block;
  pm.start('blockProposedEventHandler - calldata');
  try {
    // retrieve block and transaction from stored calldata
    [{ transactions, block }] = await Promise.all([getProposeBlockCalldataPromise(data)]);
  } catch (err) {
    logger.error(`Error retrieving ProposeBlockCalldata ${err}`);
    return;
  }
  pm.stop('blockProposedEventHandler - calldata');

  // ensure previous block and tree are stored
  // ensure commiments and nullifiers are marked
  await Promise.all([saveBlockRes, storeTreeRes, markNullifiedOnChainRes, markOnChainRes]);
  await waitForTimeout(20);

  pm.start('blockProposedEventHandler - getBlocks');
  const nextBlockNumberL2 = await getNumberOfL2Blocks();
  pm.stop('blockProposedEventHandler - getBlocks');

  pm.start('blockProposedEventHandler - sync');
  logger.info({
    msg: 'Received Block Proposed event with Layer 2 Block Number and Tx Hash',
    receivedBlockNumberL2: block.blockNumberL2,
    expectedBlockNumberL2: nextBlockNumberL2,
    transactionHashL1,
  });

  // Check resync attempts
  if (consecutiveResyncAttempts > 10) {
    lastInOrderL1BlockNumber = 'earliest';
    consecutiveResyncAttempts = 0;
  }

  // If an out of order L2 block is detected, we need to resync
  if (block.blockNumberL2 > nextBlockNumberL2) {
    consecutiveResyncAttempts++;
    // TODO set syncing state to true to disable endpoint temporarily
    await syncState(lastInOrderL1BlockNumber);
    return;
  }
  pm.stop('blockProposedEventHandler - sync');

  pm.start('blockProposedEventHandler - getTree');
  lastInOrderL1BlockNumber = currentBlockCount;
  const latestTree = await getTreeByBlockNumberL2(block.blockNumberL2 - 1);
  pm.stop('blockProposedEventHandler - getTree');

  // retrieve list of nonzero commitments in block
  const blockCommitments = transactions
    .map(t => t.commitments.filter(c => c !== ZERO))
    .flat(Infinity);

  pm.start('blockProposedEventHandler - getTime');
  let timeBlockL2 = await getTimeByBlock(transactionHashL1);
  timeBlockL2 = new Date(timeBlockL2 * 1000);
  pm.stop('blockProposedEventHandler - getTime');

  pm.start('blockProposedEventHandler - processTransactions');
  logger.info({ msg: 'processing transactions', blockNumberL2: block.blockNumberL2 });
  // process transactions in block
  const [
    dbUpdates,
    localPendingNonZeroCommitmentsFlag,
    localWithdrawTransactionFlag,
    saveTxStatus,
    storeCommitmentsStatus,
  ] = await processTransactions(
    transactions,
    blockCommitments,
    block,
    timeBlockL2,
    transactionHashL1,
    data.blockNumber,
  );
  pm.stop('blockProposedEventHandler - processTransactions');

  pm.start('blockProposedEventHandler - saveBlock');
  // store block and timber
  const updatedTimber = buildTree(latestTree, blockCommitments);
  storeTreeRes = storeTree(updatedTimber, transactionHashL1, block, syncing);
  if (dbUpdates) {
    saveBlockRes = saveBlock({
      blockNumber: currentBlockCount,
      transactionHashL1,
      timeBlockL2,
      ...block,
    });
  }
  pm.stop('blockProposedEventHandler - saveBlock');

  if (!NIGHTFALL_REGULATOR_PRIVATE_KEY) {
    pm.start('blockProposedEventHandler - updateCommitmentsSiblingInfo');
    // Update sibling information in commitments
    updateCommitmentSiblingInfo(
      blockCommitments,
      localPendingNonZeroCommitmentsFlag,
      latestTree,
      updatedTimber.root,
      storeCommitmentsStatus,
      block.blockNumberL2,
      data.blockNumber,
      data.transactionHash,
    );
    pm.stop('blockProposedEventHandler - updateCommitmentsSiblingInfo');
    pm.start('blockProposedEventHandler - updateWithdrawSiblingInfo');
    // update sibling information on withdraw transactions
    updateWithdrawSiblingInfo(block, localWithdrawTransactionFlag, saveTxStatus);
    pm.stop('blockProposedEventHandler - updateWithdrawSiblingInfo');

    if (CBDC_PUBLISHER_ENABLE) {
      //  call endpoint
      logger.info('Calling CBDC');
      axios
        .post('http://host.docker.internal:9001/settlement/block-proposed', {
          blockNumberL2: block.blockNumberL2,
          blockNumber: data.blockNumber,
          transactionHashL1,
          transactionHashes: block.transactionHashes,
        })
        .catch(error => {
          if (error.response) {
            console.log('error posting cbdc', error.response.data);
          }
        });
    }
  } else {
    // with regulator only store commitments and transactions. Not sibling info
    Promise.all([storeCommitmentsStatus, saveTxStatus]);
  }
  pm.stop('blockProposedEventHandler');
}

export default blockProposedEventHandler;
