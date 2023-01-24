'use strict';

const DynamoDB = require('aws-sdk/clients/dynamodb');
const ApiGatewayManagementApi = require('aws-sdk/clients/apigatewaymanagementapi');

const docClient = new DynamoDB.DocumentClient();
const sendEndpoint = process.env.SEND_ENDPOINT;
const MAX_L2_BLOCKS = 1;
const TYPE_TIMBER = 'timberProposed';
const TYPE_BLOCK = 'blockProposed';

exports.handler = async event => {
  const connectionId = event.requestContext.connectionId;
  const deployment = event.stageVariables.deployment;

  const eventBody = JSON.parse(event.body);
  console.log('Body', eventBody);

  const lastBlock = Number(eventBody.lastBlock);
  const type = eventBody.syncInfo || 'sync';
  const api = new ApiGatewayManagementApi({
    endpoint: `${sendEndpoint}${deployment.toLowerCase()}/`,
  });

  const paramsBlockLast = {
    TableName: `PNF3_DocumentDB_${deployment}`,
    Key: {
      blockType: type === 'sync-timber' ? TYPE_TIMBER : TYPE_BLOCK,
      blockNumberL2: lastBlock,
    },
  };
  const paramsBlockNext = {
    TableName: `PNF3_DocumentDB_${deployment}`,
    Key: {
      blockType: type === 'sync-timber' ? TYPE_TIMBER : TYPE_BLOCK,
      blockNumberL2: lastBlock + 1,
    },
  };

  const [dataBlockLast, dataBlockNext] = await Promise.all([
    docClient.get(paramsBlockLast).promise(),
    docClient.get(paramsBlockNext).promise(),
  ]);

  const filteredData = [];

  let maxBlock = 1;
  if (dataBlockNext.Item) {
    const { blockType, ...dataItem } = dataBlockNext.Item;
    filteredData.push(dataItem);
    maxBlock = 0;
  }

  console.log('filteredData', filteredData.length);

  try {
    await api
      .postToConnection({
        ConnectionId: connectionId,
        Data: JSON.stringify({
          type,
          historicalData: filteredData.slice(0, Math.min(MAX_L2_BLOCKS, filteredData.length)),
          maxBlock,
          isLast: !dataBlockNext?.Item,
          rootBlockLast: dataBlockLast?.Item?.block?.root ?? null,
          rootBlockNext: dataBlockNext?.Item?.block?.root ?? null,
          numberBlockLast: dataBlockLast?.Item?.block?.blockNumberL2 ?? null,
          numberBlockNext: dataBlockNext?.Item?.block?.blockNumberL2 ?? null,
        }),
      })
      .promise();
    console.log('Sent');
    return {
      statusCode: 200,
      body: 'Sent',
    };
  } catch (e) {
    console.log(`error: ${e}`);
    return {
      body: JSON.stringify(e),
    };
  }
};
