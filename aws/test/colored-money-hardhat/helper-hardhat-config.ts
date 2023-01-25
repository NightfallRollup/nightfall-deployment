require('dotenv').config();

const PRIVATE_KEY =
  process.env.PRIVATE_KEY || '0x0000000000000000000000000000000000000000000000000000000000000000';
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS || '';
const ETH_ADDRESS = process.env.ETH_ADDRESS || '';
const BLOCKCHAIN_URL = process.env.BLOCKCHAIN_URL || '';
const BLOCKCHAIN_WSS = process.env.BLOCKCHAIN_WSS || '';
const CLIENT_API_URL = process.env.CLIENT_API_URL || '';
const MNEMONIC = process.env.MNEMONIC || '';
const OPTIMIST_API_URL = process.env.OPTIMIST_API_URL || '';
const OPTIMIST_WS = process.env.OPTIMIST_WS || '';
const TOKEN_ID = process.env.TOKEN_ID || '';
const VALUE = process.env.VALUE || '';

export const UserConfig = {
  PRIVATE_KEY,
  CONTRACT_ADDRESS,
  ETH_ADDRESS,
  BLOCKCHAIN_URL,
  BLOCKCHAIN_WSS,
  CLIENT_API_URL,
  MNEMONIC,
  OPTIMIST_API_URL,
  OPTIMIST_WS,
  TOKEN_ID,
  VALUE,
};
