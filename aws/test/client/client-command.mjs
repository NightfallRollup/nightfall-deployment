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
  CLIENT_BP_WORKER_URL,
  MNEMONIC = '',
} = process.env;

async function clientCommand() {
  const nf3 = new Nf3(ETHEREUM_SIGNING_KEY, {
    web3WsUrl: `wss://${BLOCKCHAIN_WS_HOST}`,
    optimistApiUrl: `https://${OPTIMIST_HTTP_HOST}`,
    optimistWsUrl: `wss://${OPTIMIST_HOST}`,
    clientApiUrl: CLIENT_API_URL,
    clientApiBpUrl: CLIENT_BP_WORKER_URL,
  });

  if (CLIENT_COMMAND === 'mnemonic') {
    const mnemonic = MNEMONIC === '' ? generateMnemonic() : MNEMONIC;
    await nf3.init(mnemonic, 'client');
    console.log(`mnemonic: ${mnemonic}`);
    console.log(`Compressed Zkp Public Key: ${nf3.zkpKeys.compressedZkpPublicKey}`);
    console.log(`Zkp Private Key: ${nf3.zkpKeys.zkpPrivateKey}`);
  } else {
    console.log(`Undefined command ${CLIENT_COMMAND}`);
  }

  process.exit(0);
}

clientCommand();
