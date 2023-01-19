# Geth Service

To generate a Geth docker container, one first needs to generate some data that will be included as part of the container

## Process
1. Delete old data from `geth` service folder, but ensure that folder names remain
```
cd volumes/dag1 && sudo rm -rf * && cd -
cd volumes/geth1-chain && sudo rm -rf * && cd -
cd volumes/geth-miner-chain1 && sudo rm -rf * && cd-
```

2. Launch geth locally
```
./geth-standalone -s
```

3. Wait till DAG is created
```
docker logs -f geth-blockchain-miner1-1
```
When DAG is generated, the following is displayed
```
INFO [06-22|13:12:57.385] Generating DAG in progress               epoch=1 percentage=97 elapsed=14.045s
INFO [06-22|13:12:57.518] Generating DAG in progress               epoch=1 percentage=98 elapsed=14.178s
INFO [06-22|13:12:57.719] Generating DAG in progress               epoch=1 percentage=99 elapsed=14.379s
INFO [06-22|13:12:57.720] Generated ethash verification cache      epoch=1 elapsed=14.379s
INFO [06-22|13:12:58.571] Successfully sealed new block            number=9 sealhash=7f27ec..1257fa hash=7a0fa2..e94090 elapsed=3.955s
INFO [06-22|13:12:58.572] 🔨 mined potential block                  number=9 hash=7a0fa2..e94090
INFO [06-22|13:12:58.572] Commit new sealing work                  number=10 sealhash=531c9d..6ae951 uncles=0 txs=0 gas=0 fees=0 elapsed="106.007µs"
INFO [06-22|13:12:58.572] Commit new sealing work                  number=10 sealhash=531c9d..6ae951 uncles=0 txs=0 gas=0 fees=0 elapsed="702.404µs"
INFO [06-22|13:12:59.304] Successfully sealed new block            number=10 sealhash=531c9d..6ae951 hash=0c353f..dbb364 elapsed=732.404ms
INFO [06-22|13:12:59.304] 🔨 mined potential block                  number=10 hash=0c353f..dbb364
```

4. Stop geth
```
./geth-standalone -d
```

5. Change ownership
```
sudo chown -R ${USER} volumes
```

