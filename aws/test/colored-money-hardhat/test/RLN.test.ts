import { expect } from 'chai';
import { UserFactory } from 'nightfall-sdk';
import { UserConfig } from '../helper-hardhat-config';

describe('Test RLN functionality', async function () {
  let user: any;
  let user2: any;
  const valueDeposit = '10';
  const entityId = '1';

  before(async () => {
    user = await UserFactory.create({
      blockchainWsUrl: UserConfig.BLOCKCHAIN_WSS,
      clientApiUrl: UserConfig.CLIENT_API_URL,
      ethereumPrivateKey: UserConfig.PRIVATE_KEY,
      nightfallMnemonic: UserConfig.MNEMONIC,
    });
    user2 = await UserFactory.create({
      blockchainWsUrl: UserConfig.BLOCKCHAIN_WSS,
      clientApiUrl: UserConfig.CLIENT_API_URL,
      ethereumPrivateKey: UserConfig.PRIVATE_KEY,
    });
    console.log(`RLN contract address is ${UserConfig.CONTRACT_ADDRESS}`);
    console.log(`TokenId for tests is ${entityId}`);
  });

  it('Client alive', async () => {
    const isClientAlive = await user.isClientAlive();
    const isWeb3WsAlive = await user.isWeb3WsAlive();
    // Check client and blockchain alive
    expect(isClientAlive).to.be.equal(true);
    expect(isWeb3WsAlive).to.be.equal(true);

    // Check api contracts ok
    const contractAddress = user.shieldContractAddress;
    expect(contractAddress).to.be.a('string').and.to.include('0x');
  });

  it('Deposits', async () => {
    const pendingDepositsInitial = await user.checkPendingDeposits();
    let balanceInitial = 0;
    try {
      balanceInitial = pendingDepositsInitial[UserConfig.CONTRACT_ADDRESS.toLowerCase()][1].balance;
    } catch (error) {
      // No initial pending balance
    }
    try {
      // Make deposit
      const txReceipts = await user.makeDeposit({
        tokenContractAddress: UserConfig.CONTRACT_ADDRESS,
        value: valueDeposit,
        tokenId: entityId,
        feeWei: '0',
      });
      // Check we have transaction hashes in Nightfall
      expect(txReceipts.txReceipt.transactionHash).to.a('string').and.to.include('0x');
      expect(txReceipts.txReceiptL2.transactionHash).to.a('string').and.to.include('0x');
      expect(user.nightfallDepositTxHashes[0]).to.a('string').and.to.include('0x');
    } catch (error) {
      console.log('Error in deposit', error);
    }
    const pendingDepositsFinal = await user.checkPendingDeposits();
    const balanceFinal = pendingDepositsFinal[UserConfig.CONTRACT_ADDRESS.toLowerCase()][1].balance;
    expect(balanceFinal - balanceInitial).to.be.equal(Number(valueDeposit));
  });

  it('Transfers', async () => {
    const balanceNightfallInitial = await user.checkNightfallBalances();
    let balanceInitial = 0;
    try {
      balanceInitial =
        balanceNightfallInitial[UserConfig.CONTRACT_ADDRESS.toLowerCase()][0].balance;
    } catch (error) {
      // No initial pending balance
    }
    try {
      // Make transfer
      const txReceipts = await user.makeTransfer({
        tokenContractAddress: UserConfig.CONTRACT_ADDRESS,
        value: valueDeposit,
        tokenId: entityId,
        recipientNightfallAddress: user2.getNightfallAddress(),
        isOffChain: true,
        feeWei: '0',
      });

      // Check we have transaction hashes in Nightfall
      expect(txReceipts.txReceiptL2.transactionHash).to.a('string').and.to.include('0x');
      expect(user.nightfallTransferTxHashes[0]).to.a('string').and.to.include('0x');
    } catch (error) {
      console.log('Error in transfer', error);
    }

    const balanceNightfallFinal = await user.checkNightfallBalances();
    const balanceFinal =
      balanceNightfallFinal[UserConfig.CONTRACT_ADDRESS.toLowerCase()][0].balance;
    expect(balanceInitial - balanceFinal).to.be.equal(Number(valueDeposit));
  });

  it('Withdraws', async () => {
    const balanceNightfallInitial = await user.checkNightfallBalances();
    let balanceInitial = 0;
    try {
      balanceInitial =
        balanceNightfallInitial[UserConfig.CONTRACT_ADDRESS.toLowerCase()][0].balance;
    } catch (error) {
      // No initial pending balance
    }
    try {
      // Make withdrawal
      const txReceipts = await user.makeWithdrawal({
        tokenContractAddress: UserConfig.CONTRACT_ADDRESS,
        value: valueDeposit,
        tokenId: entityId,
        recipientEthAddress: UserConfig.ETH_ADDRESS,
        feeWei: '0',
      });
      // Check we have transaction hashes in Nightfall
      expect(txReceipts.txReceiptL2.transactionHash).to.a('string').and.to.include('0x');
      expect(user.nightfallWithdrawalTxHashes[0]).to.a('string').and.to.include('0x');
    } catch (error) {
      console.log('Error in withdraw', error);
    }
    const balanceNightfallFinal = await user.checkNightfallBalances();
    const balanceFinal =
      balanceNightfallFinal[UserConfig.CONTRACT_ADDRESS.toLowerCase()][0].balance;
    expect(balanceInitial - balanceFinal).to.be.equal(Number(valueDeposit));
  });

  after(async () => {
    user.close();
  });
});
