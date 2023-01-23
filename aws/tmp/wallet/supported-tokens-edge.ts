const tokensList = {
	tokens:	[
    {
        chainId: 100,
        name: "Ether - ERC20 Mock",
        symbol: "ETH",
        decimals: 9,
        address: "0xe721F2D97c58b1D1ccd0C80B88256a152d27f0Fe",
        logoURI: "https://wallet-asset.matic.network/img/tokens/eth.svg",
        tags: [
            "pos",
            "erc20",
            "swapable",
            "metaTx"
        ],
        id: "ethereum",
        tokenId: '0',
        restrictions: {
            withdraw: "1000000000000",
            deposit: "250000000000"
        },
        extensions: {
            parentAddress: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
            project: {
                name: "-",
                summary: "-",
                contact: "-",
                website: "https://weth.io/"
            }
        }
    },
    {
        chainId: 100,
        name: "RLN -  Bank 1",
        symbol: "RLN1",
        decimals: 0,
        tokenId: '1',
        tokenType: "ERC1155",
        address: "0x337DB55480374cEEd24f83664A06530B90d40c3F",
        logoURI: "https://wallet-asset.matic.network/img/tokens/usdc.svg",
        tags: [
            "pos",
            "erc20",
            "swapable",
            "metaTx"
        ],
        id: "ethereum",
        restrictions: {
            withdraw: "1000000000",
            deposit: "250000000"
        },
        extensions: {
            parentAddress: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
            project: {
                name: "-",
                summary: "-",
                contact: "-",
                website: "https://weth.io/"
            }
        }
    },
    {
        chainId: 100,
        name: "RLN -  Bank 2",
        symbol: "RLN2",
        decimals: 0,
        tokenId: '2',
        tokenType: "ERC1155",
        address: "0x337DB55480374cEEd24f83664A06530B90d40c3F",
        logoURI: "https://wallet-asset.matic.network/img/tokens/usdc.svg",
        tags: [
            "pos",
            "erc20",
            "swapable",
            "metaTx"
        ],
        id: "ethereum",
        restrictions: {
            withdraw: "1000000000",
            deposit: "250000000"
        },
        extensions: {
            parentAddress: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
            project: {
                name: "-",
                summary: "-",
                contact: "-",
                website: "https://weth.io/"
            }
        }
    }
]
};

export default tokensList;