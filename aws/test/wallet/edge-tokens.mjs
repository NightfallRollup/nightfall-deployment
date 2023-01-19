import fs from 'fs';

const { ETH_TOKEN_ADDRESS, RLN_CONTRACT_ADDRESS, BANK_NAMES } = process.env;

function newEthToken() {
  const token = {
    chainId: 100,
    name: 'Ether - ERC20 Mock',
    symbol: 'ETH',
    decimals: 9,
    address: ETH_TOKEN_ADDRESS || '0xe721F2D97c58b1D1ccd0C80B88256a152d27f0Fe',
    logoURI: 'https://wallet-asset.matic.network/img/tokens/eth.svg',
    tags: ['pos', 'erc20', 'swapable', 'metaTx'],
    id: 'ethereum',
    tokenId: '0',
    restrictions: {
      withdraw: '1000000000000',
      deposit: '250000000000',
    },
    extensions: {
      parentAddress: '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
      project: {
        name: '-',
        summary: '-',
        contact: '-',
        website: 'https://weth.io/',
      },
    },
  };
  return token;
}

function newRlnToken(rlnToken, rlnTokenId) {
  const token = {
    chainId: 100,
    name: `RLN - ${rlnToken}`,
    symbol: `RLN${rlnTokenId}`,
    decimals: 0,
    tokenId: `${rlnTokenId}`,
    tokenType: 'ERC1155',
    address: RLN_CONTRACT_ADDRESS,
    logoURI: 'https://wallet-asset.matic.network/img/tokens/usdc.svg',
    tags: ['pos', 'erc20', 'swapable', 'metaTx'],
    id: 'ethereum',
    restrictions: {
      withdraw: '1000000000',
      deposit: '250000000',
    },
    extensions: {
      parentAddress: '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
      project: {
        name: '-',
        summary: '-',
        contact: '-',
        website: 'https://weth.io/',
      },
    },
  };
  return token;
}

async function addTokens() {
  const tokens = [];
  tokens.push(newEthToken());
  const rlnTokens = BANK_NAMES.split('\n');
  let tokenId = 0;
  for (const rlnToken of rlnTokens) {
    if (rlnToken === ' Reserved') continue;
    tokens.push(newRlnToken(rlnToken, ++tokenId));
  }

  let edgeTokens = 'const tokensList = {\n\ttokens:\t';
  edgeTokens += JSON.stringify(tokens, null, 4).replace(/"([^"]+)":/g, '$1:');
  edgeTokens += '\n};\n\nexport default tokensList;\n';
  fs.writeFileSync(
    '../../nightfall_3/wallet/src/static/supported-token-lists/supported-tokens-edge.ts',
    edgeTokens,
  );
  return;
}

addTokens();
