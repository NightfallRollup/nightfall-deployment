'use strict';

const DynamoDB = require('aws-sdk/clients/dynamodb');
const ApiGatewayManagementApi = require('aws-sdk/clients/apigatewaymanagementapi');

// MAX_L2_BLOCKS : 20 -> 2 Tx per Blocka
//               : 1 -> 32
exports.handler = async (event) => {
  const docClient = new DynamoDB.DocumentClient();
  const sendEndpoint = process.env.SEND_ENDPOINT;
  const MAX_L2_BLOCKS = 1;
  const connectionId = event.requestContext.connectionId;
  const deployment = event.stageVariables.deployment;

  const eventBody = JSON.parse(event.body);
  console.log('Body', eventBody);
  const lastBlock = Number(eventBody.lastBlock);
  const type = eventBody.syncInfo || 'sync';
  const api = new ApiGatewayManagementApi({ endpoint: `${sendEndpoint}${deployment.toLowerCase()}/`});
  

  const params3 = {
    TableName: `PNF3_DocumentDB_${deployment}`,
    Key: {
      blockType: type === 'sync-timber'? 'timberProposed': 'blockProposed',
      blockNumberL2: Number(lastBlock)+1,
    },
  };
  
  const data = await docClient.get(params3).promise();

  const filteredData = [];
  
  var maxBlock = 1;
  if (data.Item){
    const {blockType, ...dataItem} = data.Item;
    filteredData.push(dataItem);
    maxBlock=0;
  }

  console.log('filteredData', filteredData.length);

  
  try {
    await api.postToConnection({
        ConnectionId: connectionId,
        Data: JSON.stringify({ type, historicalData: filteredData.slice(0,Math.min(MAX_L2_BLOCKS, filteredData.length)), maxBlock: maxBlock })
    }).promise();
    console.log('Sent');
    return {
      statusCode: 200,
      body: "Sent"
    };
  } catch (e) {
    console.log(`error: ${e}`);
    return {
      body: JSON.stringify(e),
    };
  }
};
