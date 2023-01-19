'use strict'
const AWS = require('aws-sdk');
const docClient = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  const connectionId = event.requestContext.connectionId;
  const deployment = event.stageVariables.deployment
  
  console.log(connectionId, deployment);
  const expireTime = Math.floor( new Date(new Date().setFullYear(new Date().getFullYear() + 1)) / 1000); // 1 year TTL as a catch in-case disconnect fails.
  const putParams = { TableName: `PNF3_Connections_WS_${deployment}`, Item: {connectionID: connectionId, lastBlock: 0, expireTTL: expireTime } };
  try {
    const putRes = await docClient.put(putParams).promise();
    console.log('Success', putRes);
    return {
      statusCode: 200,
      body: JSON.stringify(putRes)
    };
  } catch (e) {
    console.log('Error', e);
    return {
      body: JSON.stringify(e),
    };
  }
};

