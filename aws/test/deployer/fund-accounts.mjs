import Web3 from 'web3';
import axios from 'axios';

const {
  BLOCKCHAIN_WS_HOST,
  BLOCKCHAIN_PATH,
  _DEPLOYER_ADDRESS,
  _DEPLOYER_KEY,
  CLIENT_HOST,
  COMMAND = '',
  GAS,
  GAS_PRICE,
  USER_ACCOUNTS,
  DEPLOYER_ETH_NETWORK,
} = process.env;
const { CLIENT_URL = `https://${CLIENT_HOST}` } = process.env;

const web3 = new Web3(`wss://${BLOCKCHAIN_WS_HOST}${BLOCKCHAIN_PATH}`);

async function submitRawTransaction(rawTransaction, contractAddress, value = 0) {
  if (!rawTransaction) throw Error('No tx data to sign');
  if (!contractAddress) throw Error('No contract address passed');
  if (!_DEPLOYER_KEY) throw Error('_DEPLOYER_KEY not set');

  const tx = {
    to: contractAddress,
    data: rawTransaction,
    value,
    gas: GAS || 8000000,
    gasPrice: GAS_PRICE || '20000000000',
  };

  const signed = await web3.eth.accounts.signTransaction(tx, _DEPLOYER_KEY);
  return web3.eth.sendSignedTransaction(signed.rawTransaction);
}

async function fundAccounts() {
  console.log(`BLOCKCHAIN PROVIDER: wss://${BLOCKCHAIN_WS_HOST}${BLOCKCHAIN_PATH}`);
  console.log(`DEPLOYER ADDRESS: ${_DEPLOYER_ADDRESS}`);
  console.log(`CLIENT URL: ${CLIENT_URL}`);

  // Get ERC20 token ABI
  const resErc20Abi = await axios.get(`${CLIENT_URL}/contract-abi/ERC20Mock`);
  const erc20Abi = resErc20Abi.data.abi;

  // Get ERC20 token address
  const resErc20Address = await axios.get(`${CLIENT_URL}/contract-address/ERC20Mock`);
  const erc20Address = resErc20Address.data.address;

  // Get ERC20 Token contract instance
  const erc20Contract = new web3.eth.Contract(erc20Abi, erc20Address);

  // Get unlocked accounts
  let accounts = [];
  // Edge doesn't have account manager, so we have to pass this accounts explicitly
  if (DEPLOYER_ETH_NETWORK === 'staging_edge') {
    accounts = USER_ACCOUNTS.split(',');
  } else {
    accounts = await web3.eth.getAccounts();
  }

  if (COMMAND === 'fund') {
    console.log('FUNDING accounts with ERC20 Mock...');
    if (DEPLOYER_ETH_NETWORK === 'staging_edge') {
      for (const account of accounts) {
        if (account !== _DEPLOYER_ADDRESS) {
          console.log(`Transferring ERC20 Mock from ${_DEPLOYER_ADDRESS} to ${account}...`);
          await submitRawTransaction(
            erc20Contract.methods.transfer(account, 100000000000).encodeABI(),
            erc20Contract.options.address,
          );
        }
      }
    } else {
      accounts.forEach(async account => {
        if (account !== _DEPLOYER_ADDRESS) {
          erc20Contract.methods.transfer(account, 100000000000).send({ from: _DEPLOYER_ADDRESS });
        }
      });
    }
  }

  for (const account of accounts) {
    const balanceErc20 = await erc20Contract.methods.balanceOf(account).call();
    console.log('ERC20 BALANCE', account, balanceErc20);
  }
  process.exit(0);
}

fundAccounts();
