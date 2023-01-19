'use strict';
const AWS = require('aws-sdk');
const docClient = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  const connectionId = event.requestContext.connectionId;
  const deployment = event.stageVariables.deployment
  
  const deleteParams = {
    TableName: `PNF3_Connections_WS_${deployment}`,
    Key: {
      "connectionID": connectionId
    }
  };

  try {
    const deleteRes = await docClient.delete(deleteParams).promise();
    console.log("RES ", deleteRes)
    return {
      statusCode: 200,
      body: JSON.stringify(deleteRes)
    };
  } catch (e) {
    return {
      body: JSON.stringify(e),
    };
  }
};