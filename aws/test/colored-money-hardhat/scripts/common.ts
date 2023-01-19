import '@nomiclabs/hardhat-ethers';
import { UserConfig } from '../helper-hardhat-config';
import { RLN } from '../typechain-types/contracts/RLN';
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { AccountPrincipal } from 'aws-cdk-lib/aws-iam';

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
 * Get the balance of the token RLN for the account and the entityId
 * @param  {RLN} RLN Contract instance
 * @param  {string} account Account address
 * @param  {string} entityId Entity Id of the bank of the tokens
 * @return {BigNumber} Balance
 */
export async function getBalance(RLN: RLN, account: string, entityId: number) {
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
 */
export async function transferNative(hre: HardhatRuntimeEnvironment, account: string, amount: number) {
  let customerExists: boolean;
  customerExists = false;
  const signers = await hre.ethers.getSigners();
  let tx;

  const address = await signers[0].getAddress();
  await signers[0].sendTransaction({
    to: account,
    value: amount,
  });

  console.log(`Transferred ${amount} from ${address} to ${account}`);
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
    console.log("ERROR", error)
    if (error.message.includes('Already a customer')) {
      customerExists = true;
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