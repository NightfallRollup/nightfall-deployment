# Publisher

Publisher service is used as a broadcaster of Nightfall state for clients without the ability of being connected to 
a Web3 node permanently, for example a wallet. This service performs several functions:
- Updates a table with block information for every new block being proposed to nightfall
- Broadcasts new block information to all client addresses stored in a table
- When a rollback is notified, it removes all blocks affected by the rollback from the table
- Broadcasts the blockNumberL2 involved in the rollback operation to all connected clients

## Block Information
For every block received, the `publisher` service stores two objects in a table

### blockProposed

```js
    Item: {
      blockType: 'blockProposed',
      blockHash,
      blockNumberL2,
        block,
        transactions,
        blockNumber,
        blockTimestamp,
        transactionHashes,
      }
```
### timeberProposed

```js
    Item: {
      blockType: 'timberProposed',
      blockNumberL2,
      timber,
    }
```

## New block received
`publisher` is connected to a `mongoDb` database that some other entity is updating. `publisher` receives an alert from `mongoDb` everytime a new element is added to `timber` collection via `changeStreams`.
A new element is added to this collection everytime a new block is received and written to this database.


## Broadcast blocks
For every connection stored in a table, the `publisher` with send a copy of `blockProposed` object everytime a new element is added.

## New rollback notification received
`publisher` is connected to a `mongoDb` database that some other entity is updating. `publisher` receives an alert from `mongoDb` whenever a new rollback event is issued, via `changeStreams`. 
The rollback event is triggered through an update of a block from the `timber` collection, setting a new field `rollback = true` and immediately afterwards deleting the block.
The rollback event is triggered whenever the challenger detects an incorrectness in a certain block and challenges it.
Once received, the `publisher` takes care of deleting all blocks that are greater than or equal to the received `blockNumberL2` from the table, and communicate the `blockNumberL2` to the connected clients.

## Broadcast rollback
Whenever a rollback notification is received, the `publisher` sends the `blockNumberL2` affected by rollback, for each connection stored in a table.