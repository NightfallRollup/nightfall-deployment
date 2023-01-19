import mongo from './mongo.mjs';
import fs from 'fs';

const {
  MONGO_URL,
  OPTIMIST_DB,
  SUBMITTED_BLOCKS_COLLECTION,
  TRANSACTIONS_COLLECTION,
  TIMBER_COLLECTION,
  COMMAND,
  LAST_BLOCK,
  DELETE_BLOCKS = [],
} = process.env;

const blocks = JSON.parse(fs.readFileSync('../data/blocks.json', 'utf-8'));
const transactions = JSON.parse(fs.readFileSync('../data/transactions.json', 'utf-8'));
const timber = JSON.parse(fs.readFileSync('../data/timber.json', 'utf-8'));

async function main() {
  const connection = await mongo.connection(MONGO_URL);
  //Specify the database to be used
  const db = connection.db(OPTIMIST_DB);

  //Specify the collection to be used
  const blocksCollection = db.collection(`${SUBMITTED_BLOCKS_COLLECTION}`);
  const transactionsCollection = db.collection(`${TRANSACTIONS_COLLECTION}`);
  const timberCollection = db.collection(`${TIMBER_COLLECTION}`);

  if (COMMAND === 'insert') {
    //await alarmsCollection.updateOne({ _id: 1 }, { $set: alarms },  { upsert: true });
    /*
    for (const block of blocks) {
      await blocksCollection.insertOne(block);
    }
    for (const transaction of transactions) {
      await transactionsCollection.insertOne(transaction);
    }
    */
    await blocksCollection.insertMany(blocks);
    await transactionsCollection.insertMany(transactions);
    await timberCollection.insertMany(timber);
  } else if (COMMAND === 'initialize') {
    // Initialize transactions collection with some initial data
    await transactionsCollection.deleteMany({});
    await transactionsCollection.insertOne(transactions[0]);
    await transactionsCollection.insertOne(transactions[1]);
    await transactionsCollection.insertOne(transactions[2]);
    const transactionsRes = await transactionsCollection.findOne(transactions[1]);
    console.log('TX RESULT', transactionsRes !== null);
  } else if (COMMAND === 'delete') {
    //await blocksCollection.deleteMany({});
    await blocksCollection.deleteOne(blocks[0]);
    const blocksRes = await blocksCollection.findOne({});

    console.log('BLOCK RESULT', blocksRes);
  } else if (COMMAND === 'list-blocks') {
    console.log('COMMAND: ', COMMAND, LAST_BLOCK);
    const query = { blockNumberL2: { $gt: Number(LAST_BLOCK) } };
    const blocks = await blocksCollection.find(query, { sort: { blockNumberL2: 1 } }).toArray();

    console.log('Blocks: ', blocks);
  } else if (COMMAND === 'update' || COMMAND === 'updateAndDelete') {
    let dblocks = DELETE_BLOCKS.split(' ');
    let updateBlocks = [];
    for(let block of dblocks){
      updateBlocks.push({"blockNumberL2": parseInt(block)});
    }
    await timberCollection.updateMany({$or: updateBlocks}, { $set: { rollback: true } });
    if (COMMAND === 'updateAndDelete') {
      // wait for the update to be applied. alternative to this solution is to wait for the changestream of the update and delete the block contained in the fulldocument
      await new Promise(resolve => setTimeout(() => resolve(), 1000));
      await timberCollection.deleteMany({blockNumberL2: {$gte: Math.min(dblocks)}})
    }
  } 
  connection.close();
}

main();
