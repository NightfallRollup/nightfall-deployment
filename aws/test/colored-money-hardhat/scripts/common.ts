import '@nomiclabs/hardhat-ethers';
import { UserConfig } from '../helper-hardhat-config';
import { RLN } from '../typechain-types/contracts/RLN';
import { HardhatRuntimeEnvironment } from "hardhat/types"
import erc20Abi from '../tokens/abis/ERC20.json';
import erc165Abi from '../tokens/abis/ERC165.json';
import erc721Abi from '../tokens/abis/ERC721.json';
import erc1155Abi from '../tokens/abis/ERC1155.json';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address'
import { ERC20, ERC721, ERC1155, ERC721_INTERFACE_ID } from '../tokens/constants';
import { UserFactory } from 'nightfall-sdk';

/**
 * Get contract instance
 * @param  {HardhatRuntimeEnvironment} hre Hardhat runtime
 * @return {Object}      Contract instance
 */
export async function getContract(hre: HardhatRuntimeEnvironment) {
  //1. Get the contract factory
  const RLNFactory = await hre.ethers.getContractFactory('RLN');
  //2. It will create a json request, json-rpc request over to the network, and the network will call a process to get contract
  const RLN = (await RLNFactory.attach(UserConfig.CONTRACT_ADDRESS)) as RLN;
  return RLN;
}

/**
 * Creates a bank in the system
 * @param  {RLN} RLN Contract instance
 * @param  {string} bankName Name of the bank
 * @param  {string} bankAddress Address of the bank
 */
export async function addBank(RLN: RLN, bankName: string, bankAddress: string) {
  console.log(`Adding ${bankName} as entity...`);
  await RLN.addEntity(bankName, bankAddress);
  console.log(`${bankName} added!`);
}

/**
 * Gets the list of banks in the system
 * @param  {RLN} RLN Contract instance
 */
export async function getBanks(RLN: RLN) {
  const entities = await RLN.getEntities();

  for (let i = 0; i < entities.length; i++) {
    console.log(`IdentityId: ${i}, Bank name: ${entities[i][0]}, Bank address: ${entities[i][1]}`);
  }
}

/**
 * Get the balance of the native token of the network for the account
 * @param  {HardhatRuntimeEnvironment} hre Hardhat runtime
 * @param  {SignerWithAddress} signer Signer for getting information of the contract
 * @param  {string} account Account address
 * @return {BigNumber} Balance
 */
async function whichTokenStandard(hre: HardhatRuntimeEnvironment, signer: SignerWithAddress, contractAddress: string): Promise<string> {
  try {
    const funcSelector = hre.ethers.utils.keccak256(hre.ethers.utils.toUtf8Bytes('supportsInterface(bytes4)')).slice(2,10);
    const provider = signer.provider;
    const bytecode = await provider?.getCode(contractAddress);
    if (!bytecode?.includes(funcSelector)) return ERC20;
    const erc165 = new hre.ethers.Contract(contractAddress, erc165Abi, signer);
    const interface721 = await erc165.supportsInterface(ERC721_INTERFACE_ID);
    if (interface721) {
      return ERC721;
    }
    return ERC1155;
  } catch (err) {
    console.log(err);
    return ERC20;
  }
}

/**
 * Get the balance of the token for the account and the entityId
 * @param  {RLN} RLN Contract instance
 * @param  {HardhatRuntimeEnvironment} hre Hardhat runtime
 * @param  {string} account Account address
 * @param  {string} token Token to be transferred (empty, 'RLN' or contract address)
 * @param  {string} entityId Entity Id of the bank of the tokens
 * @return {BigNumber} Balance
 */
export async function getBalanceToken(RLN: RLN, hre: HardhatRuntimeEnvironment, account: string, token: string, tokenId: number) { 
  if (!token) return getBalanceNative(hre, account);
  if (token === 'RLN') return getBalanceRLN(RLN, account, tokenId);

  const signers = await hre.ethers.getSigners();
  const tokenType = await whichTokenStandard(hre, signers[0], token);

  let balance = 0;
  switch(tokenType) {
    case ERC20:
      const erc20Contract = new hre.ethers.Contract(token, erc20Abi, signers[0]);
      balance = await erc20Contract.balanceOf(account);
      console.log(`Balance of token ${tokenType} ${token} for ${account} is ${balance}`);
      break;
    case ERC721:
      const erc721Contract = new hre.ethers.Contract(token, erc721Abi, signers[0]);
      balance = await erc721Contract.balanceOf(account);
      console.log(`Balance of token ${tokenType} ${token} and tokenId ${tokenId} for ${account} is ${balance}`);
      break;
    case ERC1155:
      const erc1155Contract = new hre.ethers.Contract(token, erc1155Abi, signers[0]);
      balance = await erc1155Contract.balanceOf(account, tokenId);
      console.log(`Balance of token ${tokenType} ${token} and tokenId ${tokenId} for ${account} is ${balance}`);
      break;
    default:
      console.log(`Can't find ERC token type for token with address ${token}`);
  }
  return balance;
}

/**
 * Get the balance of the token RLN for the account and the entityId
 * @param  {RLN} RLN Contract instance
 * @param  {string} account Account address
 * @param  {string} entityId Entity Id of the bank of the tokens
 * @return {BigNumber} Balance
 */
export async function getBalanceRLN(RLN: RLN, account: string, entityId: number) { 
  if (!entityId) {
    console.log(
      `The '--entityid' parameter of task 'balance' expects a value, but none was passed.`,
    );
    return 0;
  }
  const balance = await RLN.balanceOf(account, entityId);
  console.log(`Balance of token RLN from bank with entityId ${entityId} for ${account} is ${balance} RLN`);
  return balance;
}

/**
 * Get the balance of the native token of the network for the account
 * @param  {HardhatRuntimeEnvironment} hre Hardhat runtime
 * @param  {string} account Account address
 * @return {BigNumber} Balance
 */
export async function getBalanceNative(hre: HardhatRuntimeEnvironment, account: string) {
  const balance = await hre.ethers.provider.getBalance(account)
  console.log(`Balance of native token for ${account} is ${balance}`);
  // return hre.ethers.utils.formatEther(balance)
  return balance;
}

/**
 * Transfer native tokens to the account
 * @param  {HardhatRuntimeEnvironment} hre Hardhat runtime
 * @param  {string} account Account address
 * @param  {number} amount Amount of tokens to transfer
 * @param  {string} token Token address (optional)
 */
export async function transfer(hre: HardhatRuntimeEnvironment, accounts: string, amount: number, token: string, tokenid: string) {
  const signers = await hre.ethers.getSigners();

  const accountList = accounts.split(',');
  const address = await signers[0].getAddress();
  let tokenType = ERC20;

  if (token) {
    tokenType = await whichTokenStandard(hre, signers[0], token);
  }

  for (const account of accountList) {
    if (token) {
      switch(tokenType) {
        case ERC20:
          const erc20Contract = new hre.ethers.Contract(token, erc20Abi, signers[0]);
          const allowance = await erc20Contract.allowance(address, account);
          const allowanceBN = hre.ethers.BigNumber.from(allowance);
          const valueBN =  hre.ethers.BigNumber.from(amount);
      
          if (!allowanceBN.gt(valueBN)) {
            await erc20Contract.approve(account, amount);
          }
          await erc20Contract.transfer(account, amount);
          break;
        case ERC721:
          const erc721Contract = new hre.ethers.Contract(token, erc721Abi, signers[0]);
          const isApproved721 = erc721Contract.isApprovedForAll(address, account);
          if (!isApproved721) {
            await erc721Contract.setApprovalForAll(account, true);            
          }
          await erc721Contract.safeTransferFrom(address, account, tokenid);
          break;
        case ERC1155:
          const erc1155Contract = new hre.ethers.Contract(token, erc1155Abi, signers[0]);
          const isApproved1155 = erc1155Contract.isApprovedForAll(address, account);
          if (!isApproved1155) {
            await erc1155Contract.setApprovalForAll(account, true);
          }
          await erc1155Contract.safeTransferFrom(address, account, tokenid, amount, []);
          break;
        default:
          console.log(`Can't find ERC token type for token with address ${token}`);
      }
      console.log(`Transferred ${amount} token ${tokenType} (${token}) from ${address} to ${account}`);
    } else {
      await signers[0].sendTransaction({
        to: account,
        value: amount,
      });
      console.log(`Transferred ${amount} from ${address} to ${account}`);
    }
  }
}

/**
 * Generate mnemonics for Nightfall accounts
 * @param  {number} amount Amount of accounts to generate
 */
export async function generateNightfallMnemonics(amount: number) {
  for (let i = 0; i < amount; i++) {
    const user = await UserFactory.create({
      blockchainWsUrl: UserConfig.BLOCKCHAIN_WSS,
      clientApiUrl: UserConfig.CLIENT_API_URL,
      ethereumPrivateKey: UserConfig.PRIVATE_KEY,
    });

    const mnemonic = user.getNightfallMnemonic();
    const zkpPublicAddress = user.getNightfallAddress();

    console.log(mnemonic, zkpPublicAddress);
  }
}

/**
 * Mint RLN token to the sender
 * @param  {RLN} RLN Contract instance
 * @param  {HardhatRuntimeEnvironment} hre Hardhat runtime
 * @param  {string} entityId Entity Id of the bank of the tokens
 * @param  {number} amount Amount of tokens to transfer
 */
export async function mint(RLN: RLN, hre: HardhatRuntimeEnvironment, entityId: number, amount: number) {
  let customerExists: boolean;
  customerExists = false;
  const signers = await hre.ethers.getSigners();
  let tx;

  const bankAddress = await signers[0].getAddress();
  
  RLN.connect(signers[0]); // the signer should be the bank entityId private key specified in PRIVATE_KEY in .env
  tx = await RLN.mint(entityId, amount);
  await tx?.wait();  

  const balance = await RLN.balanceOf(bankAddress, entityId);
  console.log(`Balance of token RLN from bank with entityId ${entityId} for ${bankAddress} after minting is ${balance} RLN`);  
}

export async function addFunds(RLN: RLN, hre: HardhatRuntimeEnvironment, entityId: number, recipient: string, amount: number) {
  let customerExists: boolean;
  customerExists = false;
  const signers = await hre.ethers.getSigners();
  let tx;

  RLN.connect(signers[0]);
  try {
    tx = await RLN.acceptCustomer(recipient);
    await tx?.wait(); // we have to wait for tx to be mined to avoid nonce problems
    customerExists = true;
  } catch (error) {
    if (error.message.includes('Already a customer')) {
      customerExists = true;
    } else {
      console.log("ERROR", error)
    }
  }

  console.log("Accept customer ok")
  if (customerExists) {
    tx = await RLN.mint(entityId, amount);
    await tx?.wait();  
    tx = await RLN['safeTransferFrom(address,uint256,uint256,bytes)'](
      recipient,
      entityId,
      amount,
      [],
    );
    await tx?.wait();
  }

  const balance = await RLN.balanceOf(recipient, entityId);
  console.log(`Balance of token RLN from bank with entityId ${entityId} for ${recipient} after funding is ${balance} RLN`);
}