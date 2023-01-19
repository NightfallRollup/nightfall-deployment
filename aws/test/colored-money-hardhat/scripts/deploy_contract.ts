import '@nomiclabs/hardhat-ethers';
import { RLN } from '../typechain-types/contracts/RLN';
import hre from 'hardhat';

async function deploy() {
  //1. Get the contract factory
  const RLNFactory = await hre.ethers.getContractFactory('RLN');

  //2. It will create a json request, json-rpc request over to eth network, and the network will call a process to begin a transaction
  const RLN = (await RLNFactory.deploy('https://test.coloredmoney.com/entities/')) as RLN;

  //3. When the process before done, we will deployed the contract
  await RLN.deployed();

  return RLN;
}

// @ts-ignore
async function checkDeploy(RLN: RLN) {
  console.log('RLN address:', await RLN.address);
}

deploy().then(checkDeploy);
