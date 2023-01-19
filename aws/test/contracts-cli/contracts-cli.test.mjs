/* This test relies on nightfall_3/cli
 */

/* eslint-disable no-await-in-loop */
import chai from 'chai';
import chaiHttp from 'chai-http';
import config from 'config';
import chaiAsPromised from 'chai-as-promised';
import Nf3 from '../../cli/lib/nf3.mjs';

const { expect } = chai;
chai.use(chaiHttp);
chai.use(chaiAsPromised);

const environment = config.ENVIRONMENTS[process.env.ENVIRONMENT] || config.ENVIRONMENTS.localhost;

const {
  CLIENT_API_URL,
  RELEASE,
  BOOT_CHALLENGER_KEY,
  BOOT_CHALLENGER_MNEMONIC,
  USER_KEY,
  USER_MNEMONIC,
} = process.env;

const { MINIMUM_STAKE } = config.TEST_OPTIONS;

const getContractInstance = async (contractName, nf3) => {
  const abi = await nf3.getContractAbi(contractName);
  const contractAddress = await nf3.getContractAddress(contractName);
  const contractInstance = new nf3.web3.eth.Contract(abi, contractAddress);
  return { contractAddress, contractInstance };
};

describe(`Testing Polygon Nightfall in -> ${RELEASE}`, () => {
  let nf3User;
  let nf3bootChallenger;
  let challengesContractAddress;
  let challengesContractInstance;

  before(async () => {
    environment.clientApiUrl = CLIENT_API_URL;
    console.log('Environment: ', environment);
    nf3User = new Nf3(USER_KEY, environment);
    nf3bootChallenger = new Nf3(BOOT_CHALLENGER_KEY, environment);

    await nf3User.init(USER_MNEMONIC);
    await nf3bootChallenger.init(BOOT_CHALLENGER_MNEMONIC);

    if (!(await nf3User.healthcheck('optimist'))) throw new Error('Healthcheck failed');
    if (!(await nf3bootChallenger.healthcheck('optimist'))) throw new Error('Healthcheck failed');

    ({ contractAddress: challengesContractAddress, contractInstance: challengesContractInstance } =
      await getContractInstance('Challenges', nf3User));
    console.log(nf3User.ethereumAddress, nf3bootChallenger.ethereumAddress);
  });

  describe(`Basic tests`, () => {
    it('Be able to register proposer different than bootProposer', async () => {
      const res = await nf3User.registerProposer('http://test-proposer', MINIMUM_STAKE);
      // if not registered yet
      if (res) {
        expect(res).to.have.property('transactionHash');
      }
    });

    it('Be able to commit to challenge bootChallenger', async () => {
      let error = '';
      try {
        const txDataToSign = await challengesContractInstance.methods
          .commitToChallenge(nf3bootChallenger.web3.utils.randomHex(32))
          .encodeABI();
        await nf3bootChallenger.submitTransaction(txDataToSign, challengesContractAddress, 0);
      } catch (err) {
        error = err.message;
      }
      expect(error).to.equal('');
    });

    it('Be able to commit to challenge challenger different than bootChallenger', async () => {
      let error = '';
      try {
        const txDataToSign = await challengesContractInstance.methods
          .commitToChallenge(nf3User.web3.utils.randomHex(32))
          .encodeABI();
        await nf3User.submitTransaction(txDataToSign, challengesContractAddress, 0);
      } catch (err) {
        error = err.message;
      }
      expect(error).to.equal('');
    });
  });

  after(async () => {
    nf3User.deregisterProposer();
    nf3User.close();
    nf3bootChallenger.close();
  });
});
