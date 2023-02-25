/* eslint import/no-extraneous-dependencies: "off" */
/* ignore unused exports */

/**
Mongo database functions
*/

import mongo from 'mongodb';

const { MongoClient } = mongo;
const connection = {};
const db = {};
const coll = {};

const { MONGO_INITDB_ROOT_USERNAME, MONGO_INITDB_ROOT_PASSWORD, MONGO_URL } = process.env;
const MONGO_CONNECTION_STRING = `mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@${MONGO_URL}:27017/?replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false`;
export default {
  async connection(url) {
    if (connection[url]) return connection[url];
    // Check if we are connecting to MongoDb or DocumentDb
    if (MONGO_INITDB_ROOT_USERNAME !== '') {
      const client = await new MongoClient(`${MONGO_CONNECTION_STRING}`, {
        useUnifiedTopology: true,
      });
      connection[url] = await client.connect();
    } else {
      const client = await new MongoClient(url, { useUnifiedTopology: true });
      connection[url] = await client.connect();
    }
    return connection[url];
  },
  db(url, document) {
    if (db[document]) return db[document];
    db[document] = connection[url].db(document);
    return db[document];
  },
  collection(url, document, collection) {
    if (coll[collection]) {
      return coll[collection];
    }
    if (db[document]) {
      coll[collection] = db[document].collection(collection);
      return coll[collection];
    }
    db[document] = connection[url].db(document);
    coll[collection] = db[document].collection(collection);
    return coll[collection];
  },
  async disconnect(url) {
    connection[url].close();
    delete connection[url];
  },
};
