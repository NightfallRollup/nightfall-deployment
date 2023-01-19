FROM ethereum/client-go:stable

EXPOSE 8545
EXPOSE 8546

ENTRYPOINT ["/setup/entrypoint.sh"]

WORKDIR /setup
COPY config/geth .

WORKDIR /data
COPY volumes/geth-miner-chain1 .

WORKDIR /dag
COPY volumes/dag1 .

WORKDIR /

CMD ["--http", "--http.addr", "0.0.0.0", "--http.port", "8545", "--http.vhosts", "*", "--http.corsdomain", "'*'", "--http.api", "eth,net,web3,admin,txpool,personal", "--ws.port", "8546", "--ws",  "--ws.origins", "'*'", "--ws.addr", "0.0.0.0","--mine", "--verbosity", "4", "--allow-insecure-unlock","--rpc.txfeecap", "0" ]