/* Lauch process periodically to check if there has been any update to DocumentDb OPTIMIST_DB.
   If there have been changes (update, insert, delete), those changes will be notified to xxx
*/

import mongo from 'mongodb';
import AWS from 'aws-sdk';
import { app, setStats } from './app.mjs';
import Web3 from 'web3';

const { MongoClient, ReadPreference } = mongo;
const {
  MONGO_INITDB_ROOT_PASSWORD,
  MONGO_INITDB_ROOT_USERNAME,
  OPTIMIST_DB,
  PUBLISHER_PORT,
  CHECKPOINT_COLLECTION,
  // Polling period to check if there have been modifications to documentDb
  PUBLISHER_POLLING_INTERVAL_SECONDS,
  // Time stream is open capturing modifications to documentDb
  PUBLISHER_MAX_WATCH_SECONDS,
  DYNAMODB_DOCUMENTDB_TABLE,
  DYNAMODB_WS_TABLE,
  SUBMITTED_BLOCKS_COLLECTION,
  TRANSACTIONS_COLLECTION,
  TIMBER_COLLECTION,
  API_HTTPS_SEND_ENDPOINT,
  REGION,
  DOMAIN_NAME,
  BLOCKCHAIN_PATH,
} = process.env;

const WEB3_PROVIDER_OPTIONS = {
  clientConfig: {
    // Useful to keep a connection alive
    keepalive: true,
    // Keep keepalive interval small so that socket doesn't die
    keepaliveInterval: 1500,
  },
  timeout: 3600000,
  reconnect: {
    auto: true,
    delay: 5000, // ms
    maxAttempts: 120,
    onTimeout: false,
  },
};

const maxRetryCount = 6;
const maxRetryExceptionCount = 6;

var connection = null;
var client = null;

const stats = {
  timeStart: 0.0,
  timePost: 0.0,
  timeDocDb: 0.0,
  timeDynamoDb: 0.0,
  timeFn: 0.0,
  blockNumberL2: -1,
  nProcessedBlocks: 0,
  nConnections: 0,
  blockPerSecond: 0.0,
  nErrors: {
    error429: 0,
    error410: 0,
    errorOther: 0,
  },
};

const getConnections = async docClient => {
  return docClient.scan({ TableName: `${DYNAMODB_WS_TABLE}` }).promise();
};

function initStats() {
  stats.nProcessedBlocks = 0;
  stats.nConnections = 0;
  stats.timeStart = 0.0;
  stats.imePost = 0.0;
  stats.timeDocDb = 0.0;
  stats.timeDynamoDb = 0.0;
  stats.timeFn = 0.0;
}

async function pollDocumentDb() {
  const provider = new Web3.providers.WebsocketProvider(
    `wss://web3-ws.${DOMAIN_NAME}${BLOCKCHAIN_PATH}`,
    WEB3_PROVIDER_OPTIONS,
  );
  const web3 = new Web3(provider);
  var lastProcessedToken = null;
  connection = await client.connect();
  const db = await connection.db(OPTIMIST_DB);
  console.log('Connected to DocumentDB and initialized. Fetching the resume token');
  var myDocument;
  try {
    myDocument = await db.collection(`${CHECKPOINT_COLLECTION}`, ReadPreference.PRIMARY).findOne();
    console.log('Resuming from token: ' + JSON.stringify(myDocument.checkpoint));
  } catch (err) {
    console.log('Couldnt open checkpoint document');
    setTimeout(() => pollDocumentDb(), PUBLISHER_POLLING_INTERVAL_SECONDS * 1000);
    return;
  }

  console.log(`API https endpoint_ ${API_HTTPS_SEND_ENDPOINT}`);
  AWS.config.update({
    region: REGION,
  });
  const docClient = new AWS.DynamoDB.DocumentClient();
  const api = new AWS.ApiGatewayManagementApi({ endpoint: `${API_HTTPS_SEND_ENDPOINT}` });

  let options = null;
  if (myDocument.checkpoint == 0) {
    options = {
      fullDocument: 'updateLookup',
    };
  } else {
    options = {
      resumeAfter: myDocument.checkpoint,
      fullDocument: 'updateLookup',
    };
  }
  const changeStream = db
    .collection(`${TIMBER_COLLECTION}`, ReadPreference.PRIMARY)
    .watch([], options);

  setTimeout(() => {
    console.log('Closing the change stream');
    changeStream.close();
  }, PUBLISHER_MAX_WATCH_SECONDS * 1000);

  console.log(`Waiting for changes in ${SUBMITTED_BLOCKS_COLLECTION}`);
  const transactionsCollection = db.collection(`${TRANSACTIONS_COLLECTION}`);
  const blocksCollection = db.collection(`${SUBMITTED_BLOCKS_COLLECTION}`);

  initStats();

  try {
    while (await changeStream.hasNext()) {
      var startFn = new Date().getTime();
      const change = await changeStream.next();
      lastProcessedToken = changeStream.resumeToken;
      if (change !== null) {
        //lastProcessedToken = changeStream.resumeToken;
        if (change.operationType === 'insert' || change.operationType === 'update') {
          // eslint-disable-next-line no-unused-vars
          const { _id, ...timber } = change.fullDocument;
          const block = await blocksCollection.findOne({ blockNumberL2: timber.blockNumberL2 });

          if (block === null) {
            console.log(
              `ERROR block ${timber.blockNumberL2} not found in ${SUBMITTED_BLOCKS_COLLECTION}`,
            );
            continue;
          }

          const {
            blockHash = '',
            blockNumber = 0,
            transactionHashes = [],
            blockNumberL2 = 0,
          } = block;
          if (transactionHashes.length === 0) continue;
          // TODO : Pending block deletions (rollback) and updates (Block remined due to a reorg).
          //      Transaction collection is not modified.
          // https://stackoverflow.com/questions/56939610/how-to-get-fulldocument-from-mongodb-changestream-when-a-document-is-deleted
          if (change.operationType !== 'insert') {
            if (change.fullDocument.rollback == true) {
              stats.nProcessedBlocks++;
              // remove blocks affected by rollback from dynamodb

              let batchBlocks = await getBatchBlocks(docClient, change.fullDocument.blockNumberL2);

              let retryCount = 2;
              for (let batch of batchBlocks) {
                let batchWriteParams = {
                  RequestItems: {
                    [DYNAMODB_DOCUMENTDB_TABLE]: batch,
                  },
                };

                let res = await batchDeleteBlocks(docClient, batchWriteParams, 0);
                if (res.unprocessed) {
                  if (retryCount >= maxRetryCount) {
                    // if retry the batch operation immediately,
                    // the underlying read or write requests can still fail due to throttling on the individual tables
                    batchBlocks[batchBlocks.length] = res.unprocessedItems;
                    await delay(retryCount);
                    retryCount++;
                  } else {
                    console.log('error in batch write', res.unprocessedItems);
                  }
                }
              }

              // send rollback event to the wallet
              const postParams = JSON.stringify({
                type: 'rollback',
                data: {
                  blockNumberL2,
                },
              });

              await sendToWs(postParams, new Date().getTime(), docClient, api, block);
            }
          } else {
            stats.nProcessedBlocks++;
            var startDocDb = new Date().getTime();
            console.log(`Start ${change.operationType} L2Block ${block.blockNumberL2}`);
            const returnedTransactions = await transactionsCollection
              .find({ transactionHash: { $in: transactionHashes } })
              .toArray();

            // Create a dictionary where we will store the correct position ordering
            const positions = {};
            // Use the ordering of txHashes in the block to fill the dictionary-indexed by txHash
            // eslint-disable-next-line no-return-assign
            transactionHashes.forEach((t, index) => (positions[t] = index));
            const transactions = returnedTransactions.sort(
              (a, b) => positions[a.transactionHash] - positions[b.transactionHash],
            );

            const blockInfo = await web3.eth.getBlock(blockNumber);
            const blockTimestamp = blockInfo.timestamp;

            stats.timeDocDb += new Date().getTime() - startDocDb;
            const putParams = {
              TableName: DYNAMODB_DOCUMENTDB_TABLE,
              Item: {
                blockType: 'blockProposed',
                blockHash,
                blockNumberL2,
                block,
                transactions,
                blockNumber,
                blockTimestamp,
                transactionHashes,
              },
            };
            console.log(
              `Finished ${change.operationType} L2Block ${block.blockNumberL2} Block number ${blockNumber} at ${blockTimestamp}`,
            );
            try {
              await docClient.put(putParams).promise();
            } catch (e) {
              console.log('ERROR ', JSON.stringify(e));
              console.log(
                'ERROR - Item: ',
                blockHash,
                block,
                transactions,
                blockNumber,
                transactionHashes,
              );
            }
            const putParamsTimber = {
              TableName: DYNAMODB_DOCUMENTDB_TABLE,
              Item: {
                blockType: 'timberProposed',
                blockNumberL2,
                timber,
              },
            };
            try {
              await docClient.put(putParamsTimber).promise();
            } catch (e) {
              console.log('ERROR ', JSON.stringify(e));
            }

            const postParams = JSON.stringify({
              type: 'blockProposed',
              data: {
                blockHash,
                block,
                transactions,
                blockNumber,
                blockTimestamp,
                transactionHashes,
              },
            });

            await sendToWs(postParams, new Date().getTime(), docClient, api, block);
          }
        } else {
          console.log(`Operation type ${change.operationType}`);
        }
      } else {
        console.log('Change is null');
      }
      stats.timeFn += new Date().getTime() - startFn;
    } //while
  } catch (err) {
    //console.log("ERROR",err)
    console.log('Stop change stream', err);
  }
  //watch is over. Checkpoint the resume point.
  if (lastProcessedToken != null) {
    console.log('Update checkpoint: ' + JSON.stringify(lastProcessedToken));
    const updateDoc = {
      $set: {
        checkpoint: lastProcessedToken,
      },
    };
    await db
      .collection(`${CHECKPOINT_COLLECTION}`)
      .updateOne({ _id: 1 }, updateDoc, { upsert: false });
  }
  setTimeout(() => pollDocumentDb(), PUBLISHER_POLLING_INTERVAL_SECONDS * 1000);

  // Update stats
  const timeNow = new Date().getTime();
  stats.blockPerSecond = (stats.nProcessedBlocks * 1000) / (timeNow - stats.timeStart);
  setStats(stats);
  console.log(
    'timePost: ',
    stats.timePost / 1000,
    (stats.timePost / stats.timeFn) * 100,
    stats.timePost / (stats.nProcessedBlocks * 1000),
  );
  console.log(
    'timeDoc: ',
    stats.timeDocDb / 1000,
    (stats.timeDocDb / stats.timeFn) * 100,
    stats.timeDocDb / (stats.nProcessedBlocks * 1000),
  );
  console.log(
    'timeDynamo: ',
    stats.timeDynamoDb / 1000,
    (stats.timeDynamoDb / stats.timeFn) * 100,
    stats.timeDynamoDb / (stats.nProcessedBlocks * 1000),
  );
  console.log('timeFn: ', stats.timeFn / 1000, (stats.nProcessedBlocks * 1000) / stats.timeFn);
  console.log('time blockNumberL2', stats.blockNumberL2);
}

const delay = retryCount => new Promise(resolve => setTimeout(resolve, 10 ** retryCount));

async function sendToWs(postParams, startDynamoDb, docClient, api, block) {
  stats.timeDynamoDb += new Date().getTime() - startDynamoDb;

  var startPost = new Date().getTime();
  // Send blocks to WS
  const connectionsIdx = await getConnections(docClient);
  stats.nConnections += connectionsIdx.length;

  const postCalls = connectionsIdx.Items.map(async ({ connectionID }) => {
    try {
      // TODO get rid of this await...
      await api
        .postToConnection({
          ConnectionId: connectionID,
          Data: postParams,
        })
        .promise();
    } catch (err) {
      if (err.statusCode === 410) {
        stats.nErrors.error410++;
        //console.log("Socket error 410 - Removing socket", connectionID);
        // TODO get rid of this await...
        await docClient.delete(
          {
            TableName: `${DYNAMODB_WS_TABLE}`,
            Key: {
              connectionID: 'connectionID',
            },
          },
          function (err) {
            if (err) console.log('Error deleting socket', err);
          },
        );
      } else if (err.statusCode === 429) {
        //console.log("Socket error 429");
        stats.nErrors.error429++;
      } else {
        stats.nErrors.errorOther++;
        console.log('Socket Error', err.statusCode);
      }
    }
  });

  try {
    // eslint-disable-next-line no-undef
    await Promise.all(postCalls);
    console.log(`Sent ${postCalls.length} Post Calls`);
  } catch (e) {
    console.log('Error Post Calls', e);
  }
  stats.timePost += new Date().getTime() - startPost;
  stats.blockNumberL2 = block.blockNumberL2;
}

async function stop() {
  connection.close();
  connection = null;
}

async function start(url) {
  try {
    // start dB connection
    console.log('connecting to DocumentDb');
    if (connection) return connection;
    client = await new MongoClient(
      //`mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@${url}:27017/?replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false`,
      `mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@${url}:27017/?replicaSet=rs0&readPreference=primaryPreferred&retryWrites=false`,
      {
        useUnifiedTopology: true,
      },
    );
    console.log('connected to DocumentDb');

    // Start API
    app.listen(PUBLISHER_PORT);

    // enable polling function
    stats.timeStart = new Date().getTime();
    setTimeout(() => pollDocumentDb(), PUBLISHER_POLLING_INTERVAL_SECONDS * 1000);
  } catch (err) {
    console.log(err.stack);
  } finally {
    connection && (await stop());
  }
}

async function batchDeleteBlocks(docClient, batchWriteParams, counter = maxRetryExceptionCount) {
  let unprocessedStructure = {
    unprocessed: false,
    unprocessedItems: {},
  };
  try {
    let res = await docClient.batchWrite(batchWriteParams).promise();
    if (res.UnprocessedItems && res.UnprocessedItems.length > 0) {
      unprocessedStructure.unprocessed = true;
      unprocessedStructure.unprocessedItems = res.UnprocessedItems;
    }
  } catch (e) {
    if (counter < maxRetryExceptionCount) {
      await batchDeleteBlocks(docClient, batchWriteParams, counter + 1);
    } else {
      console.log('ERROR ', JSON.stringify(e));
    }
  }
  return unprocessedStructure;
}

async function getBatchBlocks(docClient, blockNumberL2) {
  let val = await docClient.scan({ TableName: `${DYNAMODB_DOCUMENTDB_TABLE}` }).promise();
  let batchBlocks = [];
  let blocksToDelete = [];
  for (let element of val.Items) {
    if (element.blockNumberL2 >= blockNumberL2) {
      blocksToDelete.push({
        DeleteRequest: {
          Key: {
            blockType: element.blockType,
            blockNumberL2: element.blockNumberL2,
          },
        },
      });
    }

    // if there are more than 25 requests in the batch, DynamoDB rejects the entire batch write operation
    if (blocksToDelete.length % 25 == 0 && blocksToDelete.length > 0) {
      batchBlocks[batchBlocks.length] = blocksToDelete;
      blocksToDelete = [];
    }
  }

  if (blocksToDelete.length > 0) {
    batchBlocks[batchBlocks.length] = blocksToDelete;
  }

  return batchBlocks;
}

export { start, stop };
