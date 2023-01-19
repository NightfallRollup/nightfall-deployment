/**
Module that runs up as a user
*/

/* eslint-disable no-await-in-loop */

/**
 * ERC721Mock : 0xE40fffc20789F8826E3d4eb978c3DCC16439B97d
 * ERC1155Mock: 0x49fD9Cc5ED2D556Ec3e615fC1BD4e5425b194c41
 * Deposited on Goerli 0x8d15165e92391F545A46872c2DC9c5D1746b9012(deployer) and 0xafd6e65bdb854732f39e2f577c67ea6e83a4c2c2 (user1)
 */

import Nf3 from '../lib/nf3.mjs';
import { getERCInfo } from '../lib/tokens.mjs';

const environment = {
  clientApiUrl: `http://${process.env.CLIENT_HOST}:${process.env.CLIENT_PORT}`,
  optimistApiUrl: `https://${process.env.OPTIMIST_HTTP_HOST}`,
  optimistWsUrl: `wss://${process.env.OPTIMIST_HOST}`,
  proposerBaseUrl: `https://${process.env.PROPOSER_HOST}`,
  web3WsUrl: `wss://${process.env.BLOCKCHAIN_WS_HOST}`,
};

const mnemonics = {
  user1: process.env.USER1_MNEMONIC,
  user2: process.env.USER2_MNEMONIC,
};
const signingKeys = {
  user1: process.env.USER1_KEY,
  user2: process.env.USER2_KEY,
};
const zkpPublicKeys = {
  user1: process.env.USER1_COMPRESSED_ZKP_PUBLIC_KEY.toLowerCase(),
  user2: process.env.USER2_COMPRESSED_ZKP_PUBLIC_KEY.toLowerCase(),
};

const tokenParams = {
  ercName: process.env.ERC_NAME,
  ercAddress: process.env.ERC_ADDRESS || '0x499d11e0b6eac7c0593d8fb292dcbbf815fb29ae',
  tokenType: 'ERC20',
  tokenId: process.env.TOKEN_ID || '0',
};

const txParams = {
  srcIdx: Number(process.env.SRC_IDX) || 0,
  // if ONCHAIN is defined, then tx is onchain. Else, tx is offchain
  offchainTx: process.env.ONCHAIN === '' || typeof process.env.ONCHAIN === 'undefined',
  value: Number(process.env.VALUE) || 1,
  txType: process.env.TX_TYPE || 'deposit',
  l2TxHash: process.env.L2TX_HASH,
  nTx: Number(process.env.N_TX) || 1,
};

const TX_WAIT = 5000;
/**
Does the preliminary setup and starts listening on the websocket
*/
async function localTest() {
  console.log('Starting local test...');
  console.log('ENVV', environment);

  const userParams = {
    srcSigningKey: txParams.srcIdx === 0 ? signingKeys.user1 : signingKeys.user2,
    srcMnemonic: txParams.srcIdx === 0 ? mnemonics.user1 : mnemonics.user2,
    dstPublicKey: txParams.srcIdx === 0 ? zkpPublicKeys.user2 : zkpPublicKeys.user1,
    ethereumAddress: '',
  };

  const nf3 = new Nf3(userParams.srcSigningKey, environment);

  await nf3.init(userParams.srcMnemonic);
  userParams.ethereumAddress = nf3.ethereumAddress;

  if (await nf3.healthcheck('client')) console.log('Healthcheck passed');
  else throw new Error('Healthcheck failed');

  tokenParams.ercAddress = tokenParams.ercName
    ? await nf3.getContractAddress(tokenParams.ercName)
    : tokenParams.ercAddress;
  tokenParams.ercAddress = tokenParams.ercAddress.toLowerCase();

  try {
    const ercInfo = await getERCInfo(tokenParams.ercAddress, userParams.ethereumAddress, nf3.web3, {
      toEth: true,
      details: true,
    });
    tokenParams.tokenType = ercInfo.tokenType;
    console.log('L1 user balance', ercInfo);
    if (tokenParams.tokenType === 'ERC721') txParams.value = 0;
  } catch (err) {
    console.log('Error retrieving token parms', err);
    tokenParams.tokenType = 'ERC20';
  }

  console.log('Token Params', tokenParams);
  console.log('Tx Params', txParams);
  console.log('User Params', userParams);

  let balances;
  let pendingDeposit;
  let pendingSpent;

  // Create a block of deposits
  switch (txParams.txType) {
    case 'deposit':
      for (let i = 0; i < txParams.nTx; i++) {
        try {
          let { transactionHash } = await nf3.deposit(
            tokenParams.ercAddress,
            tokenParams.tokenType,
            txParams.value,
            tokenParams.tokenId,
          );
          console.log('Transaction Hash', transactionHash);
          await new Promise(resolve => setTimeout(resolve, TX_WAIT));
        } catch (err) {
          console.log(`Error in deposit ${err}`);
          return;
        }
      }
      break;
    case 'transfer':
      for (let i = 0; i < txParams.nTx; i++) {
        try {
          let { transactionHash } = await nf3.transfer(
            txParams.offchainTx,
            tokenParams.ercAddress,
            tokenParams.tokenType,
            txParams.value,
            tokenParams.tokenId,
            userParams.dstPublicKey,
          );
          console.log('Transaction Hash', transactionHash);
          await new Promise(resolve => setTimeout(resolve, TX_WAIT));
        } catch (err) {
          console.log(`Error in transfer ${err}`);
        }
      }
      break;
    case 'withdraw':
      for (let i = 0; i < txParams.nTx; i++) {
        try {
          let { transactionHash } = await nf3.withdraw(
            txParams.offchainTx,
            tokenParams.ercAddress,
            tokenParams.tokenType,
            txParams.value,
            tokenParams.tokenId,
            userParams.ethereumAddress,
          );
          console.log('Transaction Hash', transactionHash);
          await new Promise(resolve => setTimeout(resolve, TX_WAIT));
        } catch (err) {
          console.log(`Error in withdraw ${err}`);
        }
      }
      break;
    case 'finalize_withdraw':
      try {
        let { transactionHash } = await nf3.finaliseWithdrawal(txParams.l2TxHash);
        console.log('Transaction Hash', transactionHash);
      } catch (err) {
        console.log(`Error in finaliseWithdraw ${err}`);
      }
      break;
    // get pending and settled L2 balances
    case 'balance':
      balances = await nf3.getLayer2Balances();
      pendingDeposit = await nf3.getLayer2PendingDepositBalances([], true);
      pendingSpent = await nf3.getLayer2PendingSpentBalances([], true);

      console.log('L2 Balance', balances);
      console.log('Pending Deposit', JSON.stringify(pendingDeposit));
      console.log('Pending Spent', JSON.stringify(pendingSpent));

      break;

    default:
      console.log(`Unknown request ${txParams.txType}`);
  }

  return;
}

localTest();
