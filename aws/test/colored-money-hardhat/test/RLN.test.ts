import { expect } from 'chai';
import { UserFactory } from 'nightfall-sdk';
import { UserConfig } from '../helper-hardhat-config';

const getRLNBalance = async (
  user: any,
  contractAddress: string,
  entityId: string,
  onlyConfirmed: boolean = false,
) => {
  let balance = 0;
  let balanceTokenPendingDeposits = 0;
  let balanceTokenNightfall = 0;

  if (!onlyConfirmed) {
    try {
      const pendingDeposits = await user.checkPendingDeposits();
      balanceTokenPendingDeposits =
        pendingDeposits[contractAddress.toLowerCase()].find((t: { tokenId: string }) =>
          t?.tokenId?.includes(entityId),
        )?.balance || 0;
    } catch (error) {
      // No deposits pending balance
    }
  }

  try {
    const balancesNightfall = await user.checkNightfallBalances();
    balanceTokenNightfall =
      balancesNightfall[UserConfig.CONTRACT_ADDRESS.toLowerCase()].find((t: { tokenId: string }) =>
        t?.tokenId?.includes(entityId),
      )?.balance || 0;
  } catch (error) {
    // No balance
  }

  balance = balanceTokenPendingDeposits + balanceTokenNightfall;
  return balance;
};

describe('Test RLN functionality', async function () {
  let user: any;
  let user2: any;
  const valueDeposit = UserConfig.VALUE || '10';
  const entityId = UserConfig.TOKEN_ID || '1';

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

    console.log(`    RLN contract address is ${UserConfig.CONTRACT_ADDRESS}`);
    console.log(`    TokenId for tests is ${entityId}. Value is ${valueDeposit}`);
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
    const balanceInitial = await getRLNBalance(user, UserConfig.CONTRACT_ADDRESS, entityId);
    for (let i = 0; i < 2; i++) {
      try {
        // Make deposit
        const txReceipts = await user.makeDeposit({
          tokenContractAddress: UserConfig.CONTRACT_ADDRESS,
          value: valueDeposit,
          tokenId: entityId,
          feeWei: '0',
        });
        // Check we have transaction hashes in Nightfall
        expect(txReceipts.txReceipt.transactionHash).to.be.a('string').and.to.include('0x');
        expect(txReceipts.txReceiptL2.transactionHash).to.be.a('string').and.to.include('0x');
        expect(user.nightfallDepositTxHashes[0]).to.be.a('string').and.to.include('0x');
      } catch (error) {
        console.log('Error in deposit', error);
      }
    }
    const balanceFinal = await getRLNBalance(user, UserConfig.CONTRACT_ADDRESS, entityId);
    expect(balanceFinal - balanceInitial).to.be.equal(2 * Number(valueDeposit));
  });

  it('Transfers', async () => {
    let confirmedBalance = await getRLNBalance(user, UserConfig.CONTRACT_ADDRESS, entityId, true);
    while (confirmedBalance < 2 * Number(valueDeposit)) {
      console.log(
        `Waiting for confirmed balance to be > ${
          2 * Number(valueDeposit)
        } (${confirmedBalance})...`,
      );
      await new Promise(resolve => setTimeout(resolve, 10000));
      confirmedBalance = await getRLNBalance(user, UserConfig.CONTRACT_ADDRESS, entityId, true);
    }
    console.log(`      Confirmed balance: ${confirmedBalance}`);

    const balanceInitial = await getRLNBalance(user, UserConfig.CONTRACT_ADDRESS, entityId);
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
      expect(txReceipts.txReceiptL2.transactionHash).to.be.a('string').and.to.include('0x');
      expect(user.nightfallTransferTxHashes[0]).to.be.a('string').and.to.include('0x');
    } catch (error) {
      console.log('Error in transfer', error);
    }

    const balanceFinal = await getRLNBalance(user, UserConfig.CONTRACT_ADDRESS, entityId);
    expect(balanceInitial - balanceFinal).to.be.equal(Number(valueDeposit));
  });

  it('Withdraws', async () => {
    const balanceInitial = await getRLNBalance(user, UserConfig.CONTRACT_ADDRESS, entityId);
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
      expect(txReceipts.txReceiptL2.transactionHash).to.be.a('string').and.to.include('0x');
      expect(user.nightfallWithdrawalTxHashes[0]).to.be.a('string').and.to.include('0x');
    } catch (error) {
      console.log('Error in withdraw', error);
    }
    const balanceFinal = await getRLNBalance(user, UserConfig.CONTRACT_ADDRESS, entityId);
    expect(balanceInitial - balanceFinal).to.be.equal(Number(valueDeposit));
  });

  after(async () => {
    user.close();
  });
});
