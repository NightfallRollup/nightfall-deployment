/* Lauch process periodically to check if there has been any update to DocumentDb OPTIMIST_DB.
   If there have been changes (update, insert, delete), those changes will be notified to xxx
*/

import mongo from 'mongodb';
import axios from 'axios';
import WebSocket from 'ws';
import Web3 from 'web3';
import AWS from 'aws-sdk';
import app from './app.mjs';
import { ec2InstancesAttr, appsAttr } from './options.js';
import ERC20ABI from './abis/ERC20.mjs';
import {
  updateStatus,
  setCriticalStatus,
  clearStatus,
  updateDetailedStatus,
} from './services/status.mjs';

const { MongoClient } = mongo;
const {
  SLACK_TOKEN,
  MONGO_INITDB_ROOT_PASSWORD,
  MONGO_INITDB_ROOT_USERNAME,
  DOMAIN_NAME,
  BLOCKCHAIN_URL,
  ENVIRONMENT_NAME,
  BROADCAST_ALARM,
  PUBLISHER_URL,
  OPTIMIST_HTTP_URL,
  DYNAMODB_DOCUMENTDB_TABLE,
  DYNAMODB_WS_TABLE,
  REGION,
  DASHBOARD_PORT,
  DASHBOARD_POLLING_INTERVAL_SECONDS,
  OPTIMIST_DB,
  DASHBOARD_COLLECTION,
  ALARMS_COLLECTION,
  SUBMITTED_BLOCKS_COLLECTION,
  TRANSACTIONS_COLLECTION,
  INVALID_BLOCKS_COLLECTION,
  DASHBOARD_DB,
  BOOT_PROPOSER_ADDRESS,
  BOOT_CHALLENGER_ADDRESS,
  FARGATE_CHECK_PERIOD_MIN,
  FARGATE_STATUS_COUNT_ALARM,
  BLOCKCHAIN_CHECK_PERIOD_MIN,
  BLOCKCHAIN_BALANCE_COUNT_ALARM,
  ERC20_TOKEN_ADDRESS_LIST,
  ERC20_TOKEN_NAME_LIST,
  DOCDB_CHECK_PERIOD_MIN,
  DOCDB_PENDINGTX_COUNT_ALARM,
  DOCDB_PENDINGBLOCK_COUNT_ALARM,
  DOCDB_STATUS_COUNT_ALARM,
  EFS_CHECK_PERIOD_MIN,
  EFS_STATUS_COUNT_ALARM,
  DYNAMODB_CHECK_PERIOD_MIN,
  DYNAMODB_DATASTATUS_COUNT_ALARM,
  DYNAMODB_NBLOCKS_COUNT_ALARM,
  DYNAMODB_WSSTATUS_COUNT_ALARM,
  DYNAMODB_WS_COUNT_ALARM,
  PROPOSER_BALANCE_THRESHOLD,
  CHALLENGER_BALANCE_THRESHOLD,
  PROPOSER_MAX_BLOCK_PERIOD_MILIS,
  PUBLISHER_STATS_CHECK_PERIOD_MIN,
  PUBLISHER_STATS_STATUS_COUNT_ALARM,
  DASHBOARD_TEST_ENABLE,
  OPTIMIST_STATS_CHECK_PERIOD_MIN,
  OPTIMIST_STATS_STATUS_COUNT_ALARM,
  DASHBOARD_CLUSTERS,
} = process.env;

// If we are running test, limit refresh update
const MILITOMINUTES = DASHBOARD_TEST_ENABLE === 'true' ? 1000 * 1 : 1000 * 60;
var connection = null;
var client = null;
var docClient = null;

/*
  Open web socket connection
*/
const waitForOpenConnection = socket => {
  return new Promise((resolve, reject) => {
    const maxNumberOfAttempts = 10;
    const intervalTime = 200; //ms

    let currentAttempt = 0;
    const interval = setInterval(() => {
      if (currentAttempt > maxNumberOfAttempts - 1) {
        clearInterval(interval);
        reject(new Error('Maximum number of attempts exceeded'));
      } else if (socket.readyState === socket.OPEN) {
        clearInterval(interval);
        resolve();
      }
      currentAttempt++;
    }, intervalTime);
  });
};

function sortObj(obj) {
  return Object.keys(obj)
    .sort()
    .reduce(function (result, key) {
      result[key] = obj[key];
      return result;
    }, {});
}

/*
  Check if Fargate tasks' health check can be accessed
*/
async function checkFargateStatus(appsAttr, clusterNames, lastRecord) {
  const fargateStatus = typeof lastRecord === 'undefined' ? {} : { ...lastRecord.fargateStatus };
  fargateStatus.timestamp = Date.now();
  for (const clusterName of clusterNames) {
    for (const appAttr of appsAttr) {
      const attr = appAttr(clusterName);
      if (!attr.enable) continue;
      const containerInfo =
        typeof attr.containerInfo === 'undefined' ? [attr] : attr.containerInfo.portInfo;
      for (const containerAttr of containerInfo) {
        const { hostname, healthcheck } = containerAttr;
        if (typeof hostname === 'undefined') continue;
        const taskStatus =
          typeof lastRecord === 'undefined' ||
          typeof lastRecord.fargateStatus[hostname] === 'undefined'
            ? { statusCountError: 0 }
            : lastRecord.fargateStatus[hostname];
        const { path = '' } = healthcheck;
        try {
          taskStatus.hostname = hostname;
          if (hostname.includes('web3-ws')) {
            const socket = new WebSocket(BLOCKCHAIN_URL);
            await waitForOpenConnection(socket);
            taskStatus.status = socket.readyState === WebSocket.OPEN ? 'OK' : 'KO';
          } else if (hostname.includes('ws')) {
            const socket = new WebSocket(`wss://${hostname}.${DOMAIN_NAME}`);
            await waitForOpenConnection(socket);
            taskStatus.status = socket.readyState === WebSocket.OPEN ? 'OK' : 'KO';
          } else {
            const res = await axios.get(`https://${hostname}.${DOMAIN_NAME}${path}`);
            taskStatus.status = res.status === 200 ? 'OK' : 'KO';
          }
        } catch (err) {
          taskStatus.status = 'KO';
          taskStatus.statusError = err.message;
        }
        if (taskStatus.status === 'KO') {
          taskStatus.statusCountError++;
        } else {
          taskStatus.statusCountError = 0;
          taskStatus.statusError = '';
        }
        fargateStatus[hostname] = taskStatus;
      }
    }
  }
  return fargateStatus;
}

/*
 Convert from Wei
*/
function fromBaseUnit(value, decimals) {
  function isString(s) {
    return typeof s === 'string' || s instanceof String;
  }

  if (!isString(value)) {
    throw new Error('Pass strings to prevent floating point precision issues.');
  }

  const { unitMap } = Web3.utils;
  const factor = 10 ** decimals;
  const unit = Object.keys(unitMap).find(key => unitMap[key] === factor.toString());

  return Web3.utils.fromWei(value, unit);
}

/*
  record fargate alarms
*/
async function setAlarmsFargate(currentStatus) {
  const alarm = {};
  for (let task in currentStatus.fargateStatus) {
    if (task === 'timestamp') continue;
    if (
      currentStatus.fargateStatus[task].status === 'KO' &&
      currentStatus.fargateStatus[task].statusCountError >= FARGATE_STATUS_COUNT_ALARM
    ) {
      alarm[task] = `${task} not reachable`;
      setCriticalStatus();
    }
  }
  return alarm;
}

/*
  Record balances (proposer, challenger and shield contract)
*/
async function checkBlockchainStatus(shieldAddress, lastRecord) {
  const blockchainStatus =
    typeof lastRecord === 'undefined'
      ? {
          proposerBalanceCount: 0,
          challengerBalanceCount: 0,
          blockNumberCount: 0,
        }
      : { ...lastRecord.blockchainStatus };
  blockchainStatus.timestamp = Date.now();
  const web3 = new Web3(BLOCKCHAIN_URL);
  blockchainStatus.blockNumber = await web3.eth.getBlockNumber();

  blockchainStatus.proposerBalance = await web3.utils.fromWei(
    await web3.eth.getBalance(BOOT_PROPOSER_ADDRESS),
    'ether',
  );

  blockchainStatus.challengerBalance = await web3.utils.fromWei(
    await web3.eth.getBalance(BOOT_CHALLENGER_ADDRESS),
    'ether',
  );

  if (shieldAddress) {
    blockchainStatus.shieldAddressBalance = {};
    blockchainStatus.shieldAddressBalance.etherBalance = await web3.utils.fromWei(
      await web3.eth.getBalance(shieldAddress),
      'ether',
    );
  }

  // Get shield contract balance
  const tokenAddresses = ERC20_TOKEN_ADDRESS_LIST.split(',');
  const tokenNames = ERC20_TOKEN_NAME_LIST.split(',');
  for (var tokenIdx = 0; tokenIdx < tokenNames.length; tokenIdx++) {
    try {
      const ercContract = new web3.eth.Contract(
        ERC20ABI,
        tokenAddresses[tokenIdx].replace(/\s/g, ''),
      );
      const decimals = await ercContract.methods.decimals().call();
      const balance = await ercContract.methods.balanceOf(shieldAddress).call();
      blockchainStatus.shieldAddressBalance[tokenNames[tokenIdx].replace(/\s/g, '')] = fromBaseUnit(
        balance,
        decimals,
      );
    } catch (err) {
      console.log(`Error accessing token ${tokenNames[tokenIdx]} ${err}`);
    }
  }

  return blockchainStatus;
}

/*
  Raise alarms if challenger or proposer balances below the threshold
*/
async function setAlarmsBlockchain(currentStatus, prevStatus) {
  const alarm = {};
  if (currentStatus.blockchainStatus.proposerBalance < Number(PROPOSER_BALANCE_THRESHOLD)) {
    currentStatus.blockchainStatus.proposerBalance++;
    if (
      currentStatus.blockchainStatus.proposerBalanceCount >= Number(BLOCKCHAIN_BALANCE_COUNT_ALARM)
    ) {
      alarm.proposerEth = currentStatus.blockchainStatus.proposerBalance;
    }
  } else {
    currentStatus.blockchainStatus.proposerBalanceCount = 0;
  }
  if (currentStatus.blockchainStatus.challangerBalance < Number(CHALLENGER_BALANCE_THRESHOLD)) {
    currentStatus.blockchainStatus.challengerBalance++;
    if (currentStatus.blockchainStatus.challengerBalanceCount >= BLOCKCHAIN_BALANCE_COUNT_ALARM) {
      alarm.proposerEth = currentStatus.blockchainStatus.challengerBalance;
    }
  } else {
    currentStatus.blockchainStatus.challengerBalanceCount = 0;
  }
  if (
    typeof prevStatus === 'undefined' ||
    currentStatus.blockchainStatus.blockNumber === prevStatus.blockchainStatus.blockNumber
  ) {
    currentStatus.blockchainStatus.blockNumberCount++;
    if (currentStatus.blockchainStatus.blockNumberCount >= 3) {
      alarm.blockNumber = `L1 block number did not increase ${currentStatus.blockchainStatus.blockNumber}`;
      setCriticalStatus();
    }
  } else if (
    typeof prevStatus !== 'undefined' &&
    currentStatus.blockchainStatus.blockNumber !== prevStatus.blockchainStatus.blockNumber
  ) {
    currentStatus.blockchainStatus.blockNumberCount = 0;
  }
  return alarm;
}

/*
  Record DocDb status, number of L2Blcks and number of transactions
*/
async function checkDocumentDbStatus(lastRecord) {
  const documentDbStatus =
    typeof lastRecord === 'undefined'
      ? {
          statusCountError: 0,
          pendingTxCountError: 0,
          pendingL2BlockError: 0,
          pendingL2TxTimeStamp: 0,
        }
      : { ...lastRecord.documentDbStatus };
  documentDbStatus.timestamp = Date.now();
  const db = connection.db(OPTIMIST_DB);
  try {
    const blocksCollection = db.collection(SUBMITTED_BLOCKS_COLLECTION);
    const transactionsCollection = db.collection(TRANSACTIONS_COLLECTION);

    documentDbStatus.nL2Blocks = await blocksCollection.estimatedDocumentCount();
    documentDbStatus.nL2Tx = await transactionsCollection.estimatedDocumentCount();
    const transactionTypes = await transactionsCollection.distinct('circuitHash');
    documentDbStatus.nL2TxType = {};
    for (const txType of transactionTypes) {
      documentDbStatus.nL2TxType[txType] = await transactionsCollection.countDocuments({
        circuitHash: txType,
      });
    }
    documentDbStatus.pendingL2Tx = await transactionsCollection.countDocuments({ mempool: true });
    documentDbStatus.statusCountError = 0;

    if (documentDbStatus.pendingL2Tx > 0 && documentDbStatus.pendingL2TxTimeStamp === 0) {
      documentDbStatus.pendingL2TxTimeStamp = Date.now();
    } else {
      documentDbStatus.pendingL2TxTimeStamp = 0;
    }

    const invalidBlocksCollection = db.collection(INVALID_BLOCKS_COLLECTION);
    documentDbStatus.nL2ChallengedBlocks = await invalidBlocksCollection.countDocuments();
  } catch (err) {
    documentDbStatus.status = 'KO';
    documentDbStatus.statusCountError++;
  }

  return documentDbStatus;
}

/*
  Trigger alarm if DocDb status, number of L2Blcks and number of transactions don't match with expectations
*/
async function setAlarmsDocumentDb(currentStatus, prevStatus) {
  const alarm = {};
  const TRANSACTIONS_PER_BLOCK = 60;
  if (currentStatus.documentDbStatus.pendingL2Tx > 1.5 * Number(TRANSACTIONS_PER_BLOCK)) {
    currentStatus.documentDbStatus.pendingTxCountError++;
    if (currentStatus.documentDbStatus.pendingTxCountError >= Number(DOCDB_PENDINGTX_COUNT_ALARM)) {
      alarm.pendingTxTooHigh = `Pending L2 Tx ${currentStatus.documentDbStatus.pendingL2Tx} should not be higher than ${TRANSACTIONS_PER_BLOCK}`;
      setCriticalStatus();
    }
  } else {
    currentStatus.documentDbStatus.pendingTxCountError = 0;
  }

  if (
    currentStatus.documentDbStatus.nL2ChallengedBlocks >
    prevStatus.documentDbStatus.nL2ChallengedBlocks
  ) {
    alarm.challengedBlocks = `New block challenged. Total challenged blocks: ${currentStatus.documentDbStatus.nL2ChallengedBlocks}`;
  }
  if (
    currentStatus.documentDbStatus.pendingL2TxTimeStamp &&
    Date.now() - currentStatus.documentDbStatus.pendingL2TxTimeStamp >=
      2 *
        Math.max(
          Number(PROPOSER_MAX_BLOCK_PERIOD_MILIS),
          Number(DASHBOARD_POLLING_INTERVAL_SECONDS) * 1000,
        )
  ) {
    alarm.blockFrequency = `${currentStatus.documentDbStatus.pendingL2Tx} pending transactions are not being processed`;
    setCriticalStatus();
  }
  if (
    currentStatus.documentDbStatus.status === 'KO' &&
    currentStatus.documentDbStatus.statusCountError >= Number(DOCDB_STATUS_COUNT_ALARM)
  ) {
    alarm.status = `docDb not reachable`;
    setCriticalStatus();
  }
  return alarm;
}

async function checkEfsStatus(lastRecord) {
  const efsStatus =
    typeof lastRecord === 'undefined' ? { statusCountError: 0 } : { ...lastRecord.efsStatus };
  efsStatus.timestamp = Date.now();

  try {
    const res = await axios.get(`${OPTIMIST_HTTP_URL}/contract-address/Shield`);
    efsStatus.status = res.status === 200 ? 'OK' : 'KO';
    efsStatus.shieldAddress = res.data.address;
  } catch (err) {
    efsStatus.status = 'KO';
    efsStatus.statusError = err.meesage;
  }
  if (efsStatus.status === 'KO') {
    efsStatus.statusCountError++;
  } else {
    efsStatus.statusCountError = 0;
    efsStatus.statusError = '';
  }

  return efsStatus;
}

async function setAlarmsEfs(currentStatus) {
  const alarm = {};
  if (
    currentStatus.efsStatus.status === 'KO' &&
    currentStatus.efsStatus.statusCountError >= Number(EFS_STATUS_COUNT_ALARM)
  ) {
    alarm.efs = `EFS not reachable`;
    setCriticalStatus();
  }
  return alarm;
}

async function checkDynamoDbStatus(lastRecord) {
  const dynamoDbStatus =
    typeof lastRecord === 'undefined'
      ? {
          statusWSCountError: 0,
          statusDataCountError: 0,
          expectedBlocksCountError: 0,
          nWsItemsCount: 0,
        }
      : { ...lastRecord.dynamoDbStatus };
  dynamoDbStatus.timestamp = Date.now();
  try {
    const wsTable = await docClient.scan({ TableName: `${DYNAMODB_WS_TABLE}` }).promise();
    dynamoDbStatus.nWsItems = wsTable.Count;
    dynamoDbStatus.statusWSCountError = 0;
  } catch (err) {
    dynamoDbStatus.wsError = err.message;
    dynamoDbStatus.statusWSCountError++;
  }
  // Params : Get Last item stored for maxL2Block
  const params = {
    TableName: `${DYNAMODB_DOCUMENTDB_TABLE}`,
    KeyConditionExpression: 'blockType = :bt',
    ExpressionAttributeValues: {
      ':bt': 'blockProposed',
    },
    ScanIndexForward: false,
    Limit: 1,
  };
  try {
    const dataTable = await docClient.query(params).promise();
    dynamoDbStatus.nL2Blocks =
      dataTable.Items.length === 0 ? 0 : Number(dataTable.Items[0].blockNumberL2) + 1;
    dynamoDbStatus.statusDataCountError = 0;
  } catch (err) {
    dynamoDbStatus.docError = err.message;
    dynamoDbStatus.statusDataCountError++;
  }
  return dynamoDbStatus;
}

async function setAlarmsDynamoDb(currentStatus, prevStatus) {
  const alarm = {};
  if (
    currentStatus.dynamoDbStatus.nL2Blocks !== currentStatus.documentDbStatus.nL2Blocks &&
    currentStatus.dynamoDbStatus.nL2Blocks === prevStatus.dynamoDbStatus.nL2Blocks
  ) {
    currentStatus.dynamoDbStatus.expectedBlocksCountError++;
    if (
      currentStatus.dynamoDbStatus.expectedBlocksCountError >= Number(DYNAMODB_NBLOCKS_COUNT_ALARM)
    ) {
      alarm.nL2TxDynamo = `Expected nL2Blocks ${currentStatus.documentDbStatus.nL2Blocks}. Actual nL2Blocks ${currentStatus.dynamoDbStatus.nL2Blocks}`;
    }
  } else {
    currentStatus.dynamoDbStatus.expectedBlocksCountError = 0;
  }
  if (currentStatus.dynamoDbStatus.statusWSCountError >= Number(DYNAMODB_WSSTATUS_COUNT_ALARM)) {
    alarm.statusWsTable = 'Ws Table not reachable';
    setCriticalStatus();
  }
  if (currentStatus.dynamoDbStatus.nWsItems >= Number(DYNAMODB_WSSTATUS_COUNT_ALARM)) {
    currentStatus.dynamoDbStatus.nWsItemsCount++;
    if (currentStatus.dynamoDbStatus.nWsItemsCount >= Number(DYNAMODB_WS_COUNT_ALARM)) {
      alarm.itemsWsTable = `There are ${currentStatus.dynamoDbStatus.nWsItems} wallets connected`;
    }
  } else {
    currentStatus.dynamoDbStatus.nWsItemsCount = 0;
  }

  if (
    currentStatus.dynamoDbStatus.statusDataCountError >= Number(DYNAMODB_DATASTATUS_COUNT_ALARM)
  ) {
    alarm.statusDataTable = 'Data Table not reachable';
    setCriticalStatus();
  }
  return alarm;
}

async function checkPublisherStats(lastRecord) {
  const publisherStats =
    typeof lastRecord === 'undefined'
      ? { statusStatsCountError: 0, partialL2Blocks: 0, partialL2BlocksError: 0 }
      : { ...lastRecord.publisherStats };
  publisherStats.timestamp = Date.now();
  try {
    const res = await axios.get(`${PUBLISHER_URL}/stats`);
    if (res.status !== 200) {
      publisherStats.statusStatsCountError++;
    } else {
      const firstBatch = typeof publisherStats.lastBatchStats === 'undefined' ? true : false;
      const lastBatchStats = {
        timeFn: firstBatch
          ? res.data.timeFn
          : res.data.timeFn - publisherStats.aggregatedStats.timeFn,
        timePost: firstBatch
          ? res.data.timePost
          : res.data.timePost - publisherStats.aggregatedStats.timePost,
        timeDocDb: firstBatch
          ? res.data.timeDocDb
          : res.data.timeDocDb - publisherStats.aggregatedStats.timeDocDb,
        timeDynamoDb: firstBatch
          ? res.data.timeDynamoDb
          : res.data.timeDynamoDb - publisherStats.aggregatedStats.timeDynamoDb,
        nErrors429: firstBatch
          ? res.data.nErrors.error429
          : res.data.nErrors.error429 - publisherStats.aggregatedStats.nErrors.error429,
        nErrors410: firstBatch
          ? res.data.nErrors.error410
          : res.data.nErrors.error410 - publisherStats.aggregatedStats.nErrors.error410,
        nErrorsOther: firstBatch
          ? res.data.nErrors.errorOther
          : res.data.nErrors.errorOther - publisherStats.aggregatedStats.nErrors.errorOther,
        nProcessedBlocks: firstBatch
          ? res.data.nProcessedBlocks
          : res.data.nProcessedBlocks - publisherStats.aggregatedStats.nProcessedBlocks,
        nConnections: firstBatch
          ? res.data.nConnections
          : res.data.nConnections - publisherStats.aggregatedStats.nConnections,
      };
      lastBatchStats.bps =
        lastBatchStats.timeFn === 0
          ? 0
          : (lastBatchStats.nProcessedBlocks * 1000) / lastBatchStats.timeFn;
      lastBatchStats.timePostPerBlock =
        lastBatchStats.nProcessedBlocks === 0
          ? 0
          : lastBatchStats.timePost / lastBatchStats.nProcessedBlocks;
      lastBatchStats.timeDocDbPerBlock =
        lastBatchStats.nProcessedBlocks === 0
          ? 0
          : lastBatchStats.timeDocDb / lastBatchStats.nProcessedBlocks;
      lastBatchStats.timeDynamoDbPerBlock =
        lastBatchStats.nProcessedBlocks === 0
          ? 0
          : lastBatchStats.timeDynamoDb / lastBatchStats.nProcessedBlocks;
      lastBatchStats.nConnectionsPerBlock =
        lastBatchStats.nProcessedBlocks === 0
          ? 0
          : lastBatchStats.nConnections / lastBatchStats.nProcessedBlocks;
      // initialize lastBlockTimestamp
      if (typeof publisherStats.aggregatedStats === 'undefined') {
        publisherStats.aggregatedStats = {
          ...res.data,
          lastBlockTimestamp: publisherStats.timestamp,
        };
      } else {
        publisherStats.aggregatedStats = {
          ...res.data,
          lastBlockTimestamp: publisherStats.aggregatedStats.lastBlockTimestamp,
        };
      }
      // update lastblock timestamp
      if (lastBatchStats.nProcessedBlocks) {
        publisherStats.aggregatedStats.lastBlockTimestamp = publisherStats.timestamp;
      }

      publisherStats.lastBatchStats = lastBatchStats;
      publisherStats.statusStatsCountError = 0;
    }
  } catch (err) {
    publisherStats.statusStatsCountError++;
  }

  return publisherStats;
}

async function setAlarmsPublisherStats(currentStatus, prevStatus) {
  const alarm = {};
  if (
    currentStatus.publisherStats.status === 'KO' &&
    currentStatus.publisherStats.statusStatsCountError >= Number(PUBLISHER_STATS_STATUS_COUNT_ALARM)
  ) {
    alarm.publisherStats = `Publisher Stats not reachable`;
    setCriticalStatus();
  }
  if (
    currentStatus.publisherStats.partialL2BlocksError !==
    prevStatus.publisherStats.partialL2BlocksError
  ) {
    alarm.blockGenerator = `make block failed`;
    setCriticalStatus();
  }
  // Raise alarm is block not generated in twice the time a block is expected
  if (
    Date.now() - currentStatus.publisherStats.aggregatedStats.lastBlockTimestamp >=
      2 *
        Math.max(
          Number(PROPOSER_MAX_BLOCK_PERIOD_MILIS),
          Number(DASHBOARD_POLLING_INTERVAL_SECONDS) * 1000,
        ) &&
    currentStatus.documentDbStatus.pendingL2Tx
  ) {
    currentStatus.documentDbStatus.pendingL2BlockError++;
    if (
      currentStatus.documentDbStatus.pendingL2BlockError >= Number(DOCDB_PENDINGBLOCK_COUNT_ALARM)
    ) {
      const elapsedTime =
        (Date.now() - currentStatus.publisherStats.aggregatedStats.lastBlockTimestamp) /
        MILITOMINUTES;
      alarm.blockFrequency = `L2 Block expected every ${
        PROPOSER_MAX_BLOCK_PERIOD_MILIS / 6000
      } minutes and elapsed time was ${elapsedTime} minutes. Pending ${
        currentStatus.documentDbStatus.pendingL2Tx
      } transactions`;
    }
  } else {
    currentStatus.documentDbStatus.pendingL2BlockError = 0;
  }
  return alarm;
}

async function checkOptimistStats(lastRecord) {
  const optimistStats =
    typeof lastRecord === 'undefined' ? { statusStatsCountError: 0 } : lastRecord.optimistStats;
  optimistStats.timestamp = Date.now();
  try {
    const res = await axios.get(`${OPTIMIST_HTTP_URL}/debug/counters`);
    if (res.status !== 200) {
      optimistStats.statusStatsCountError++;
    } else {
      optimistStats.statusStatsCountError = 0;
      optimistStats.debugCounters = res.data.counters;
    }
  } catch (err) {
    optimistStats.statusStatsCountError++;
  }

  return optimistStats;
}

async function setAlarmsOptimistStats(currentStatus, prevStatus) {
  const alarm = {};
  if (
    currentStatus.optimistStats.statusStatsCountError >= Number(OPTIMIST_STATS_STATUS_COUNT_ALARM)
  ) {
    alarm.optimistStats = `Optimist Stats not reachable`;
  }

  if (
    JSON.stringify(sortObj(currentStatus.optimistStats)) !==
    JSON.stringify(sortObj(prevStatus.optimistStats))
  ) {
    alarm.optimistStats.debugCounters = currentStatus.optimistStats.debugCounters;
  }

  return alarm;
}

async function computeAlarm(prevAlarm, currentAlarm) {
  if (
    prevAlarm === null ||
    JSON.stringify(sortObj(prevAlarm)) !== JSON.stringify(sortObj(currentAlarm))
  ) {
    return true;
  }
  return false;
}
async function pollAlarms() {
  docClient = new AWS.DynamoDB.DocumentClient();

  connection = await client.connect();
  // enable polling function
  const db = await connection.db(DASHBOARD_DB);
  const dashboardCollection = db.collection(DASHBOARD_COLLECTION);
  const alarmsCollection = db.collection(ALARMS_COLLECTION);

  const status = {};
  const alarms = {
    environment: DOMAIN_NAME,
    blockchain: {},
    efs: {},
    fargateAlarm: {},
    documentDb: {},
    dynamoDb: {},
    publisherStats: {},
  };

  var lastRecord = null;
  const now = Date.now();
  clearStatus();

  lastRecord = (
    await dashboardCollection.find().sort({ 'fargateStatus.timestamp': -1 }).limit(1).toArray()
  )[0];
  const clusterNames = DASHBOARD_CLUSTERS === '' ? [] : DASHBOARD_CLUSTERS.split(',');
  // Check fargate tasks
  if (
    typeof lastRecord === 'undefined' ||
    now - lastRecord.fargateStatus.timestamp >= FARGATE_CHECK_PERIOD_MIN * MILITOMINUTES
  ) {
    status.fargateStatus = await checkFargateStatus(
      [...appsAttr, ...ec2InstancesAttr],
      clusterNames,
      lastRecord,
    );
    alarms.fargateAlarm = await setAlarmsFargate(status);
  } else {
    status.fargateStatus = lastRecord.fargateStatus;
  }

  // TODO - these items below are not currently logged
  // - alive
  // - uptime
  // - mem used
  // - cpu used
  // - reboots

  // Check EFS
  if (
    typeof lastRecord === 'undefined' ||
    now - lastRecord.efsStatus.timestamp >= Number(EFS_CHECK_PERIOD_MIN) * MILITOMINUTES
  ) {
    status.efsStatus = await checkEfsStatus(lastRecord);
  } else {
    status.efsStatus = lastRecord.efsStatus;
  }
  alarms.efs = await setAlarmsEfs(status);
  // - access

  // Check blockchain
  if (
    typeof lastRecord === 'undefined' ||
    now - lastRecord.blockchainStatus.timestamp >=
      Number(BLOCKCHAIN_CHECK_PERIOD_MIN) * MILITOMINUTES
  ) {
    status.blockchainStatus = await checkBlockchainStatus(
      status.efsStatus.shieldAddress,
      lastRecord,
    );
    alarms.blockchain = await setAlarmsBlockchain(status, lastRecord);
  } else {
    status.blockchainStatus = lastRecord.blockchainStatus;
  }

  // - last block
  // - proposer account eth
  // - challenger account eth
  // - liq provider account eth

  // Check Db
  if (
    typeof lastRecord === 'undefined' ||
    now - lastRecord.documentDbStatus.timestamp >= Number(DOCDB_CHECK_PERIOD_MIN) * MILITOMINUTES
  ) {
    status.documentDbStatus = await checkDocumentDbStatus(lastRecord);
    if (typeof lastRecord !== 'undefined') {
      alarms.documentDb = await setAlarmsDocumentDb(status, lastRecord);
    }
  } else {
    status.documentDbStatus = lastRecord.documentDbStatus;
  }

  // - last block
  // - transaction
  // - check if new block should have been proposed
  // - Challenges

  // Check DynamoDb
  if (
    Number(DYNAMODB_CHECK_PERIOD_MIN) &&
    (typeof lastRecord === 'undefined' ||
      now - lastRecord.dynamoDbStatus.timestamp >=
        Number(DYNAMODB_CHECK_PERIOD_MIN) * MILITOMINUTES)
  ) {
    status.dynamoDbStatus = await checkDynamoDbStatus(lastRecord);
    if (typeof lastRecord !== 'undefined') {
      alarms.dynamoDb = await setAlarmsDynamoDb(status, lastRecord);
    }
  } else {
    status.dynamoDbStatus = lastRecord.dynamoDbStatus;
  }

  // Check Publisher Stats
  if (
    Number(PUBLISHER_STATS_CHECK_PERIOD_MIN) &&
    (typeof lastRecord === 'undefined' ||
      typeof lastRecord.publisherStats === 'undefined' ||
      now - lastRecord.publisherStats.timestamp >=
        Number(PUBLISHER_STATS_CHECK_PERIOD_MIN) * MILITOMINUTES)
  ) {
    status.publisherStats = await checkPublisherStats(lastRecord);
    if (typeof lastRecord !== 'undefined') {
      alarms.publisherStats = await setAlarmsPublisherStats(status, lastRecord);
    }
  } else {
    status.publisherStats = lastRecord.publisherStats;
  }

  // Check Optimist Stats
  if (
    typeof lastRecord === 'undefined' ||
    typeof lastRecord.optimistStats === 'undefined' ||
    now - lastRecord.optimistStats.timestamp >=
      Number(OPTIMIST_STATS_CHECK_PERIOD_MIN) * MILITOMINUTES
  ) {
    status.optimistStats = await checkOptimistStats(lastRecord);
    if (typeof lastRecord !== 'undefined') {
      alarms.optimistStats = await setAlarmsOptimistStats(status, lastRecord);
    }
  } else {
    status.optimistStats = lastRecord.optimistStats;
  }

  // Logs errors
  // TODO - add some tracing for logs

  // Add status entry
  await dashboardCollection.insertOne({ ...status });

  // Keep 1 week records only
  await dashboardCollection.deleteMany({
    'fargateStatus.timestamp': { $lt: new Date(now) - 7 * 24 * 60 * 60 * 1000 },
  });

  try {
    // eslint-disable-next-line no-unused-vars
    const { _id, ...lastAlarm } = await alarmsCollection.findOne({});
    // this public alarm needs to be publlised in Slack
    if ((await computeAlarm(lastAlarm, alarms)) && BROADCAST_ALARM === 'true') {
      try {
        const payload = {
          attachments: [{ text: JSON.stringify(alarms, null, 2), color: 'green' }],
        };
        const options = {
          method: 'post',
          url: `${SLACK_TOKEN}`,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          },
          data: payload,
        };
        await axios.request(options);
      } catch (err) {
        const status = err.response.status;
        console.error(`There was an error, HTTP status code: ${status}`);
      }
    }
  } catch (e) {
    console.log('No alarm found', e);
  }

  console.log('Alarm', alarms);
  console.log('Metric', status);

  await alarmsCollection.updateOne({ _id: 1 }, { $set: alarms }, { upsert: true });

  console.log(`Starting Dashboard in ${DASHBOARD_POLLING_INTERVAL_SECONDS} seconds...`);
  publishMetricsAws(status);
  updateStatus();
  updateDetailedStatus(alarms);
}

async function stop() {
  connection.close();
  connection = null;
}

/*
 Publish metrics to AWS CloudWatch
*/
function publishMetricsAws(status) {
  const {
    blockchainStatus,
    documentDbStatus,
    dynamoDbStatus,
    publisherStats,
    optimistStats,
  } = status;

  // Balances
  createCwMetric({
    MetricName: 'Balance-proposer',
    Unit: 'None',
    Value: Number(blockchainStatus.proposerBalance),
  });
  createCwMetric({
    MetricName: 'Balance-challenger',
    Unit: 'None',
    Value: Number(blockchainStatus.challengerBalance),
  });
  createCwMetric({
    MetricName: 'Balance-shield-ETH',
    Unit: 'None',
    Value: Number(blockchainStatus.shieldAddressBalance.etherBalance),
  });
  for (var tokenName in blockchainStatus.shieldAddressBalance) {
    createCwMetric({
      MetricName: `Balance-shield-${tokenName}`,
      Unit: 'None',
      Value: Number(blockchainStatus.shieldAddressBalance[tokenName]),
    });
  }

  // Nightfall Status
  createCwMetric({
    MetricName: 'NTRANSACTIONS_docDB',
    Unit: 'None',
    Value: Number(documentDbStatus.nL2Tx),
  });
  for (const [key, value] of Object.entries(documentDbStatus.nL2TxType)) {
    createCwMetric({
      MetricName: `NL2TX-${key}_docDB`,
      Unit: 'None',
      Value: Number(value),
    });
  }
  createCwMetric({
    MetricName: 'NPENDING_TRANSACTIONS_docDB',
    Unit: 'None',
    Value: Number(documentDbStatus.pendingL2Tx),
  });
  createCwMetric({
    MetricName: 'NBLOCKS_docDB',
    Unit: 'None',
    Value: Number(documentDbStatus.nL2Blocks),
  });
  createCwMetric({
    MetricName: 'NCHALLENGEDBLOCKS_docDB',
    Unit: 'None',
    Value: Number(documentDbStatus.nL2ChallengedBlocks),
  });
  if (Number(PUBLISHER_STATS_CHECK_PERIOD_MIN)) {
    if (
      Object.keys(publisherStats.aggregatedStats).length &&
      Number(publisherStats.aggregatedStats.blockNumberL2) !== -1
    ) {
      createCwMetric({
        MetricName: 'NBLOCKS_publisher',
        Unit: 'None',
        Value:
          Object.keys(publisherStats.aggregatedStats).length === 0
            ? 0
            : Number(publisherStats.aggregatedStats.blockNumberL2) + 1,
      });
    }
    createCwMetric({
      MetricName: 'AVG_WALLETS_publisher',
      Unit: 'None',
      Value: Number(publisherStats.lastBatchStats.nConnectionsPerBlock),
    });
    // Publisher Error metrics
    createCwMetric({
      MetricName: 'ERROR_429',
      Unit: 'None',
      Value:
        Object.keys(publisherStats.aggregatedStats).length === 0
          ? 0
          : Number(publisherStats.aggregatedStats.nErrors.error429),
    });
    createCwMetric({
      MetricName: 'ERROR_410',
      Unit: 'None',
      Value:
        Object.keys(publisherStats.aggregatedStats).length === 0
          ? 0
          : Number(publisherStats.aggregatedStats.nErrors.error410),
    });
    createCwMetric({
      MetricName: 'ERROR_OTHER',
      Unit: 'None',
      Value:
        Object.keys(publisherStats.aggregatedStats).length === 0
          ? 0
          : Number(publisherStats.aggregatedStats.nErrors.errorOther),
    });
  }

  if (Number(DYNAMODB_CHECK_PERIOD_MIN)) {
    createCwMetric({
      MetricName: 'NBLOCKS_dynamoDB',
      Unit: 'None',
      Value: Number(dynamoDbStatus.nL2Blocks),
    });
    // Wallet metrics
    createCwMetric({
      MetricName: 'MAX_WALLETS',
      Unit: 'None',
      Value: Number(dynamoDbStatus.nWsItems),
    });
    createCwMetric({
      MetricName: 'MIN_WALLETS',
      Unit: 'None',
      Value: Number(dynamoDbStatus.nWsItems),
    });
    createCwMetric({
      MetricName: 'AVG_WALLETS',
      Unit: 'None',
      Value: Number(dynamoDbStatus.nWsItems),
    });
  }

  // Optimist error metrics
  createCwMetric({
    MetricName: 'STATUS_STATS_ERROR',
    Unit: 'None',
    Value: Number(optimistStats.statusStatsCountError),
  });
  createCwMetric({
    MetricName: 'NBLOCKS_INVALID',
    Unit: 'None',
    Value: Number(optimistStats.debugCounters.nBlockInvalid),
  });
  createCwMetric({
    MetricName: 'PROPOSER_WS_CLOSED',
    Unit: 'None',
    Value: Number(optimistStats.debugCounters.proposerWsClosed),
  });
  createCwMetric({
    MetricName: 'PROPOSER_WS_FAILED',
    Unit: 'None',
    Value: Number(optimistStats.debugCounters.proposerWsFailed),
  });
  createCwMetric({
    MetricName: 'PROPOSER_BLOCK_NOT_SENT',
    Unit: 'None',
    Value: Number(optimistStats.debugCounters.proposerBlockNotSent),
  });
}

async function createCwMetric(metricParams) {
  const cw = new AWS.CloudWatch();

  const params = {
    MetricData: [metricParams],
    Namespace: `Nightfall/${ENVIRONMENT_NAME}`,
  };

  cw.putMetricData(params, function (err) {
    if (err) {
      console.log('Error', params, err);
    } else {
      console.log(
        `Metric ${params.MetricData[0].MetricName} - Value: ${params.MetricData[0].Value}`,
      );
    }
  });
}

async function start(url) {
  try {
    // start dB connection
    console.log('connecting to DocumentDb');
    if (connection) return connection;
    client = await new MongoClient(
      `mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@${url}:27017/?replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false`,
      {
        useUnifiedTopology: true,
      },
    );
    console.log('connected to DocumentDb');

    // Start API
    app.listen(DASHBOARD_PORT);

    AWS.config.update({
      region: REGION,
    });

    console.log(`Starting Dashboard in ${DASHBOARD_POLLING_INTERVAL_SECONDS} seconds...`);
    setInterval(() => pollAlarms(), DASHBOARD_POLLING_INTERVAL_SECONDS * 1000);
  } catch (err) {
    console.log(err.stack);
  } finally {
    connection && (await stop());
  }
}

export { start, stop };
