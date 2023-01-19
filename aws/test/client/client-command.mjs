/**
Module that runs up as a proposer
*/
import Nf3 from '../lib/nf3.mjs';
import { generateMnemonic } from 'bip39';

const {
  ETHEREUM_SIGNING_KEY,
  OPTIMIST_HOST,
  OPTIMIST_HTTP_HOST,
  BLOCKCHAIN_WS_HOST,
  CLIENT_API_URL,
  CLIENT_COMMAND,
  MNEMONIC = '',
} = process.env;

async function clientCommand() {
  const nf3 = new Nf3(ETHEREUM_SIGNING_KEY, {
    web3WsUrl: `wss://${BLOCKCHAIN_WS_HOST}`,
    optimistApiUrl: `https://${OPTIMIST_HTTP_HOST}`,
    optimistWsUrl: `wss://${OPTIMIST_HOST}`,
    clientApiUrl: CLIENT_API_URL,
  });

  if (CLIENT_COMMAND === 'mnemonic') {
    const mnemonic = MNEMONIC === '' ? generateMnemonic() : MNEMONIC;
    await nf3.init(mnemonic, 'client');
    console.log(`mnemonic: ${mnemonic}`);
    console.log(`Compressed Zkp Public Key: ${nf3.zkpKeys.compressedZkpPublicKey}`);
  } else {
    console.log(`Undefined command ${CLIENT_COMMAND}`);
  }

  process.exit(0);
}

clientCommand();
