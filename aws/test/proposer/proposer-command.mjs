/**
Module that runs up as a proposer
*/
import Nf3 from '../lib/nf3.mjs';

const {
  BOOT_PROPOSER_KEY,
  OPTIMIST_SERVICE,
  BLOCKCHAIN_WS_HOST,
  PROPOSER_COMMAND,
  INSTANCE_INDEX = '',
  OPTIMIST_HTTP_SERVICE,
  DOMAIN_NAME,
  PROPOSER_URL,
} = process.env;

/**
Does the preliminary setup and starts listening on the websocket
*/
async function proposerCommand() {
  const nf3 = new Nf3(BOOT_PROPOSER_KEY, {
    web3WsUrl: `wss://${BLOCKCHAIN_WS_HOST}`,
    optimistApiUrl: `https://${OPTIMIST_HTTP_SERVICE}${INSTANCE_INDEX}.${DOMAIN_NAME}`,
    optimistWsUrl: `wss://${OPTIMIST_SERVICE}${INSTANCE_INDEX}.${DOMAIN_NAME}`,
  });
  await nf3.init(undefined, 'optimist');

  if (PROPOSER_COMMAND === 'change') {
    console.log('Command: Change Proposer', INSTANCE_INDEX);
    await nf3.changeCurrentProposer();
  } else if (PROPOSER_COMMAND === 'register') {
    const minStake = await nf3.getMinimumStake();
    console.log('Command: Register Proposer', INSTANCE_INDEX, PROPOSER_URL, minStake);
    await nf3.registerProposer(PROPOSER_URL, minStake);
  } else if (PROPOSER_COMMAND === 'deregister') {
    console.log('Command: Deregister Proposer', INSTANCE_INDEX);
    await nf3.deregisterProposer();
  } else {
    console.log(`Undefined command ${PROPOSER_COMMAND}`);
  }

  process.exit(0);
}

proposerCommand();
