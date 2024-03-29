/**
Module that runs up as a user
*/

/* eslint-disable no-await-in-loop */

import config from 'config';
import axios from 'axios';
import logger from '@polygon-nightfall/common-files/utils/logger.mjs';
import Nf3 from '../../cli/lib/nf3.mjs';
import {
  waitForSufficientBalance,
  retrieveL2Balance,
  Web3Client,
  waitForTimeout,
} from '../utils.mjs';

const { mnemonics, signingKeys, zkpPublicKeys } = config.TEST_OPTIONS;

const txPerBlock = 2;

const { TX_WAIT = 1000, TEST_ERC20_ADDRESS } = process.env;

const TEST_LENGTH = 4;

/**
Does the preliminary setup and starts listening on the websocket
*/
export default async function localTest(IS_TEST_RUNNER, environment, regulatorUrl, regulatorBpUrl) {
  logger.info({msg:'Starting local test...'});
  const tokenType = 'ERC20';
  const depositValue = 100;
  const transferValue = 10;
  const tokenId = '0x0000000000000000000000000000000000000000000000000000000000000000';
  const nf3 = new Nf3(IS_TEST_RUNNER ? signingKeys.user1 : signingKeys.user2, environment);
  const eventLogs = [];

  await nf3.init(IS_TEST_RUNNER ? mnemonics.user1 : mnemonics.user2);
  if (await nf3.healthcheck('client')) logger.info('Healthcheck passed');
  else throw new Error('Healthcheck failed');

  let ercAddress;
  try {
    ercAddress = await nf3.getContractAddress('ERC20Mock');
  } catch {
    console.log('Couldnt retrieve ERC20Mock address!!! Using default');
    ercAddress = TEST_ERC20_ADDRESS;
  }
  const stateAddress = await nf3.stateContractAddress;
  const web3Client = new Web3Client();
  web3Client.subscribeTo('logs', eventLogs, { address: stateAddress });

  const startBalance = await retrieveL2Balance(nf3, ercAddress);
  console.log('start balance', startBalance);
  console.log('Regulator Urls', regulatorUrl, regulatorBpUrl);

  let offchainTx = !!IS_TEST_RUNNER;
  // Create a block of deposits
  for (let i = 0; i < txPerBlock; i++) {
    try {
      await nf3.deposit(ercAddress, tokenType, depositValue, tokenId, 0);
      await new Promise(resolve => setTimeout(resolve, TX_WAIT)); // this may need to be longer on a real blockchain
    } catch (err) {
      logger.warn(`Error in deposit 1 ${err}`);
    }
  }
  /*
  const regulatorCommitmentsBefore = (await axios.get(`${regulatorUrl}/commitment/`)).data
    .allCommitments.length;
    */
  // Create a block of transfer and deposit transactions
  for (let i = 0; i < TEST_LENGTH; i++) {
    await waitForSufficientBalance({
      nf3User: nf3,
      value: transferValue,
      ercAddress,
    });
    for (let j = 0; j < txPerBlock - 1; j++) {
      try {
        await nf3.transfer(
          offchainTx,
          ercAddress,
          tokenType,
          transferValue,
          tokenId,
          IS_TEST_RUNNER ? zkpPublicKeys.user2 : zkpPublicKeys.user1,
          0,
          [],
          [],
          IS_TEST_RUNNER ? regulatorBpUrl : '', // only regulator2 active
        );
      } catch (err) {
        if (err.message.includes('No suitable commitments')) {
          // if we get here, it's possible that a block we are waiting for has not been proposed yet
          // let's wait 10x normal and then try again
          logger.warn(
            `No suitable commitments were found for transfer. I will wait ${
              0.01 * TX_WAIT
            } seconds and try one last time`,
          );
          await new Promise(resolve => setTimeout(resolve, 10 * TX_WAIT));
          await nf3.transfer(
            offchainTx,
            ercAddress,
            tokenType,
            transferValue,
            tokenId,
            IS_TEST_RUNNER ? zkpPublicKeys.user2 : zkpPublicKeys.user1,
            0,
            [],
            [],
            IS_TEST_RUNNER ? regulatorBpUrl : '', // only regulator2 active
          );
        }
      }
      offchainTx = !offchainTx;
    }
    try {
      await nf3.deposit(ercAddress, tokenType, depositValue, tokenId, 0);
      await new Promise(resolve => setTimeout(resolve, TX_WAIT)); // this may need to be longer on a real blockchain
      console.log(`Completed ${i + 1} pings`);
    } catch (err) {
      console.warn('Error deposit 2', err);
    }
  }

  // Wait for sometime at the end to retrieve balance to include any transactions sent by the other use
  // This needs to be much longer than we may have waited for a transfer
  let loop = 0;
  let loopMax = 10000;
  if (IS_TEST_RUNNER) loopMax = 100; // the TEST_RUNNER must finish first so that its exit status is returned to the tester
  do {
    const endBalance = await retrieveL2Balance(nf3, ercAddress);
    /*
    const regulatorCommitmentsAfter = (await axios.get(`${regulatorUrl}/commitment/`)).data
      .allCommitments.length;
      */
    if (
      endBalance - startBalance === txPerBlock * depositValue + depositValue * TEST_LENGTH &&
      //regulatorCommitmentsAfter === regulatorCommitmentsBefore + TEST_LENGTH &&
      IS_TEST_RUNNER
    ) {
      logger.info('Test passed');
      logger.info(
        `Balance of User (txPerBlock*value (txPerBlock*1) + value received) :
        ${endBalance - startBalance}`,
      );
      /*
      logger.info({
        msg: 'Balance of Regulator :',
        expected: regulatorCommitmentsBefore + TEST_LENGTH,
        actual: regulatorCommitmentsAfter,
      });
      */
      logger.info(`Amount sent to other User: ${transferValue * TEST_LENGTH}`);
      nf3.close();
      process.exit(0);
    } else {
      logger.info(
        `The test has not yet passed because the L2 balance has not increased, or I am not the test runner - waiting:
        Current Transacted Balance is: ${endBalance - startBalance} - Expecting: ${
          txPerBlock * depositValue + depositValue * TEST_LENGTH
        }`,
      );
      /*
      if (IS_TEST_RUNNER) {
        logger.info({
          msg: 'Balance of Regulator :',
          expected: regulatorCommitmentsBefore + TEST_LENGTH,
          actual: regulatorCommitmentsAfter,
        });
      }
        */
      await new Promise(resolving => setTimeout(resolving, 20 * TX_WAIT)); // TODO get balance waiting working well
      loop++;
    }
  } while (loop < loopMax);
  process.exit(1);
}
