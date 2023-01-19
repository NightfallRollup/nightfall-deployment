# Performance Optimizations
There are several tests that measure system performance:
- `test-ws` : tests publisher and lambda functions performance. There are two subtests:
   - `sync` : stresses lambda `syncBlockProd` by creating N blocks and measuring if system can cope with N simultaneous wallets syncronizing
   - `blockProd` : stresses publisher by creating N random blocks every 13 seconds, and measuring if system can cope with N simultaneous  wallets receiving updates.

Different AWS configurations have proved to boost performance:
- DynamoDb Tables: 
   - Configure docDb table with autoscaling 10/300 @ 50% utilzation for reading (`sync`), 
   and 1/200 @50% utilization for writing (`blockProposed`) . Monitor throttling graphs and adapt autoscaling to fit expected profile. 
   - Ws table doesn't seem to have an impact. Left it at 1 for both reading and writing
   - For 32 Tx/Block, we do a single read (all that fits in socket). Therefore, we have adapted the lambda code to do a `getItem` instead  of a query, because its more efficient and takes less time
   - To reduce throttling further, we have removed `maxBlocks` (parameter that returns number of blocks). Instead, we return 0 if more blocks  exist and 1 if no more blocks exist. With this, we removed 50% of the reads to the table.
- Lambda : Socket can send 4x32KB of data. a 32 Tx block takes about 77KB, so we can just send 1 block
   - SyncBlockProd
      - 512 MB memory seems optimum for 32Tx/Block. It uses 150 MB, so there is space to reduce memory required. 
      - When dynamoDb starts throttling reads, lambda times out (default is 3 seconds). When there is no throttling, lambda takes 80ms. Reducing lambda timeout helps. Minimum is 1sec.
- Wallet:
   - When doing a sync, wallets include the last block the have, and lambda will send next block. This should be changed to wallets sending the block they need, not the previous one. It makes sense that a wallet requests the block it wants.
   - When requesting a block, wallets need to include a time out and re-request it again. If there is a lot of load in the network, it may happen  that the request is served but too late (after wallet request times pit), and the wallet will receive duplicates. So, its necessary to have a duplicate protection in the wallet. Its also good that timeouts are modulated with load (some sort of exponential backoff). Otherwise, there may be many requests for the same block and load will further increase....
   - It would be interesting to monitor load to actually modulate parameters in real time
- Publisher:
   - Stressed in `blockProposed` events, when it needs to send block multiple times. 
   - Variables `PUBLISHER_POLLING_INTERVAL_SECONDS` and `PUBLISHER_MAX_WATCH_SECONDS` play a role here. `MAX_WATCH` specifies the computing   time the task is active when invoked. `POLLING_INTERVAL` measures the time between the task finishing and the time its called the next time. Set `MAX_WATCH` high so that task can do many things if needed. Set `POLLING_INTERVAL` low so that there is low latency. Proposed values are 300 and 10 seconds respectively.
   - Testing 1000 wallets -> (node:27) UnhandledPromiseRejectionWarning: LimitExceededException: 429. API GW quota is 10K request per second. 1000 wallets x 40 Blocks/ 13 seconds is 3K requests per second (its likely that i went over limit). Asked for 30K. There is an option in `API GW->Stages->Settings` where the max burst size can be configured.
   - index `transactionHash` in `transactions` collection to reach desired speed.
  

## Performance Results
### Publisher tests
#### Sync
Configuration:
- WS dynamoDb Table : constant read/write capacity of 1 unit
- Document dynamoDb Table: constant write capacity 1 Unit, 10/300/50% autoscaling read
- Lambda : 512MB memory, 1s timeout, no max count read, `getItem` table read, 1 Block per transmission
- General: 32 Tx/Block

|N Wallets|Blocks| Time(s)| TPS|
|---------|------|--------|-------|
| 1       | 1400 | 220    | 203 |
| 10      | 1400 | 225    |200 |
| 50      | 1400 | 530    | 85 |
| 100     | 1400 | 1300   | 34 |
| 1000    | 1400 | slow, but doesn't break | ? |

Performance decreases because DynamoDb table starts throttling. Increasing read speed in this table should ensure that performance of 100 TPS is achieavable.

#### blockProposed
Configuration:
- WS dynamoDb Table : constant read/write capacity of 1 unit
- Document dynamoDb Table:  1/50%/50% autoscaling write capacity Units, 10/300/50% autoscaling read capacity units
- Publisher: 300 seconds `MAX_WATCH` and 10 seconds `POLLING_INTERVAL`
- General: 
   - 32 Tx/Block
   - Block generation rate random 1-80 blocks every 13 seconds (40 blocks per second average)
   - TPS : 32 Tx * 40 blocks average / 13 seconds = 100 tps


|N Wallets| N Blocks | Time (sec) | TPS    | % Post | % Dynamo | % Doc | Observations ]
|-------------| ------------|----------------|----------|------------|-----------|---------------|-------------------|
| 10     | 10000  | 3600  | 89 | 19 | 11 | 6  |                       |
| 100    | 10000  | 5220  | 61 | 87 | 8  | 1  | Some GW throttling errors |
| 100    | 1000   | 1100  | 30 | 23 | 4  | <1 | Block generation rate: 1 block per second |
|1000    | 1000   | 2800  | 11 | 80 | 2  | <1 | Lots of GW throttling errors. Publisher can't keep up, but doesn't die|
| 1000   |  300   | 1700  |  6 | 12 | <1 | <1 | Block generation rate: 1 block every 5 seconds |

`%Post` measures the percentage of the time that publisher  uses to post messages to wallets
`%Dynamo` measures the percentage of the time that publisher uses to write `block` structure to dynamoDb
`%Doc` measures the percentage of the time that publisher uses to read `transactions` from Db

In those cases where adding the three components is less than 100% there is a significant amount of time where publisher is idle and therefore, publisher is keeping up with block generation rate

For those cases where adding the three components is more than 100%, publisher cannot keep up with block generation rate. It can be seen that the task that takes more time is `Post` (makes sense as the number of messages posts is equal to the number of wallets). To improve performance in these cases, we need to spin multiple publishers depending on the number of wallets, or use a multi-threaded programming language and use more CPUs in the fargate task.