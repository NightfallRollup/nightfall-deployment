/*
  - sync test: Open N_SOCKETS to emulate wallets, and wait to receive EXPECTED_N_BLOCKS from
     publisher
  - proposedBlock test: Open N_SOCKETS and receive 1 block periodically
*/
import WebSocket from 'ws';

const {
  EVENT_WS_URL,
  LAST_BLOCK,
  N_SOCKETS = 1,
  EXPECTED_N_BLOCKS,
  TEST_TYPE = 'sync',
  DELETE_BLOCKS = [],
  SYNC_TYPE = TEST_TYPE,
} = process.env;

let dblocks
let rollbackBlock = -1;
let expectedLastBlock;

if(DELETE_BLOCKS.length > 0) { dblocks = DELETE_BLOCKS.split(' ').map(Number);}

async function setupWebSocket() {
  const sockets = [];
  const rxBlocks = [];
  // silly mechanism to modulate timeouts. Good enough for testing
  // but for real environments, it needs to be thought better
  const MIN_TIMEOUT = N_SOCKETS <= 100 ? 10000 : 20000;
  const MAX_TIMEOUT = N_SOCKETS <= 100 ? 20000 : 100000;

  /*
      Timeout to send sync request
    */
  const keepAlive = async id => {
    if (!sockets[id]) return;
    if (sockets[id].readyState !== WebSocket.OPEN) return;
    // request blocks until done
    sockets[id].send(
      JSON.stringify({
        type: SYNC_TYPE,
        lastBlock: sockets[id].lastBlock,
      }),
    );
    sockets[id].alive = 1;
    sockets[id].watchdog = setTimeout(
      keepAlive,
      MIN_TIMEOUT + Math.floor(Math.random() * MAX_TIMEOUT),
      id,
    );
  };

  const showStats = async id => {
    var str = '';
    var keepAlive = 0;
    for (var j = 0; j < N_SOCKETS; j++) {
      if (sockets[j].alive) {
        keepAlive = 1;
        str += `${j}: ${rxBlocks[j].length}/${EXPECTED_N_BLOCKS} (${sockets[j].lastBlock}) `;
      }
    }
    console.log(str);
    if (keepAlive) {
      setTimeout(showStats, 10000, id);
    }
  };

  /*
      At the end of the test, verify if there are duplicated blocks
    */
  const checkBlocks = async blocks => {
    var expectedL2BlockNumber = 0;
    var ret = {
      check: true,
      missingBlocks: [],
    };
    for (const rxL2BlockNumber of blocks) {
      if (rxL2BlockNumber !== expectedL2BlockNumber) {
        ret.check = false;
        ret.missingBlocks.push(expectedL2BlockNumber);
      }
      expectedL2BlockNumber++;
    }
    return ret;
  };

  const checkDeletedBlocks = async blocks => {
    var ret = {
      check: true,
      missingBlocks: [],
    };
    if(blocks.length >= dblocks.length) {
      let difference = blocks.filter(x => !dblocks.includes(x));
      if(difference.length > 0) {
        ret.check = false 
        ret.missingBlocks = difference
      } 
    }
    return ret;
  };

  const checkSyncAndRollbackBlocks = async (blocks, rollbackBlock) => {
    var ret = await checkBlocks(blocks);
    if(rollbackBlock > -1) {
        if(blocks[blocks.length - 1] !== expectedLastBlock) {
          ret.check = false;
        }
    }
    return ret;
  };

  console.log('N WebSockets', N_SOCKETS);
  console.log(`WebSocket URL ${EVENT_WS_URL}`);
  console.log(`Test ${TEST_TYPE}`);
  console.log(`lastBlock ${LAST_BLOCK}`);
  for (var i = 0; i < N_SOCKETS; i++) {
    const socket = new WebSocket(EVENT_WS_URL);
    // received blocks - just need L2block number, but we
    // store whole block
    rxBlocks[i] = [];
    // wallet index
    socket.id = i;
    // is wallet alive? Not very useful as implemented
    socket.alive = 1;
    socket.lastBlock = LAST_BLOCK;
    socket.maxBlock = 0;
    socket.timestamp = new Date().getTime();
    sockets.push(socket);

    // Connection opened and request sync
    socket.addEventListener('open', async function () {
      if (TEST_TYPE === 'sync' || TEST_TYPE === 'syncFast' || TEST_TYPE === 'syncrollback') {
        keepAlive(socket.id);
      }
      if (socket.id === 0) showStats(socket.id);
    });

    socket.addEventListener('error', async function (event) {
      const nErrors = 0;
    });

    // Listen for messages
    socket.addEventListener('message', async function (event) {
      const parsed = JSON.parse(event.data);
      if (
        (parsed.type === 'sync' && TEST_TYPE === 'sync') ||
        (parsed.type === 'syncFast' && TEST_TYPE === 'syncFast')
      ) {
        clearTimeout(socket.watchdog);
        socket.alive = 0;
        socket.maxBlock = parsed.maxBlock;
        for (var block of parsed.historicalData) {
          if (socket.maxBlock === 1) {
            break;
          } else if (
            parsed.type === 'sync' &&
            (rxBlocks[socket.id].length === 0 ||
              rxBlocks[socket.id][rxBlocks[socket.id].length - 1] < block.block.blockNumberL2)
          ) {
            rxBlocks[socket.id].push(block.block.blockNumberL2);
          } else if (
            parsed.type === 'syncFast' &&
            (rxBlocks[socket.id].length === 0 ||
              rxBlocks[socket.id][rxBlocks[socket.id].length - 1] < block.blockNumberL2)
          ) {
            rxBlocks[socket.id].push(block.blockNumberL2);
          } else {
            // if duplicate, do not request packet again and just return
            console.log(`[${socket.id}] ${block.block.blockNumberL2} Duplicated`);
            return;
          }
        }
        if (socket.maxBlock === 1) {
          socket.timestamp = (new Date().getTime() - socket.timestamp) / 1000;
          const allBlocksOk = await checkBlocks(rxBlocks[socket.id]);
          if (
            rxBlocks[socket.id][rxBlocks[socket.id].length - 1] === Number(EXPECTED_N_BLOCKS) - 1 &&
            allBlocksOk.check
          ) {
            console.log(
              `[${socket.id}]: ${rxBlocks[socket.id].length}/${EXPECTED_N_BLOCKS} - ${
                socket.timestamp
              } sec - PASSED`,
            );
          } else {
            console.log(
              `[${socket.id}]: ${rxBlocks[socket.id].length}/${EXPECTED_N_BLOCKS} - ${
                socket.timestamp
              } sec - FAILED`,
            );
            console.log(`missing Blocks ${allBlocksOk.missingBlocks}`);
            console.log(`Blocks ${rxBlocks[socket.id]}`);
          }
          socket.close();
          return;
        }
        if (parsed.type === 'sync') {
          socket.lastBlock =
            parsed.historicalData[parsed.historicalData.length - 1].block.blockNumberL2;
        } else {
          socket.lastBlock =
            parsed.historicalData[parsed.historicalData.length - 1].timber.blockNumberL2;
        }
        if (parsed.historicalData.length === 0) return;
        keepAlive(socket.id);
      } else if (parsed.type === 'blockProposed') {
        if (TEST_TYPE === 'blockProposed') {
          if (
            rxBlocks[socket.id].length === 0 ||
            rxBlocks[socket.id][rxBlocks[socket.id].length - 1] < parsed.data.block.blockNumberL2
          ) {
            rxBlocks[socket.id].push(parsed.data.block.blockNumberL2);
          }
          if (
            rxBlocks[socket.id][rxBlocks[socket.id].length - 1] >=
            Number(EXPECTED_N_BLOCKS) - 1
          ) {
            socket.timestamp = (new Date().getTime() - socket.timestamp) / 1000;
            const allBlocksOk = await checkBlocks(rxBlocks[socket.id]);
            if (allBlocksOk.check) {
              console.log(
                `[${socket.id}]: ${rxBlocks[socket.id].length}/${EXPECTED_N_BLOCKS} - ${
                  socket.timestamp
                } sec - PASSED`,
              );
            } else {
              console.log(
                `[${socket.id}]: ${rxBlocks[socket.id].length}/${EXPECTED_N_BLOCKS} - ${
                  socket.timestamp
                } sec - FAILED`,
              );
              console.log(`missing Blocks ${allBlocksOk.missingBlocks}`);
            }
            sockets[socket.id].alive = 0;
            socket.close();
          }
        } 
      } else if (TEST_TYPE === 'rollback') {
        if(!rxBlocks[socket.id].includes(parsed.data.blockNumberL2))
          rxBlocks[socket.id].push(parsed.data.blockNumberL2);

        if(rxBlocks[socket.id][rxBlocks[socket.id].length - 1] >= EXPECTED_N_BLOCKS - 1) {
          socket.timestamp = (new Date().getTime() - socket.timestamp) / 1000;
          const allBlocksOk = await checkDeletedBlocks(rxBlocks[socket.id]);
          if (allBlocksOk.check && rxBlocks[socket.id].length === dblocks.length) {
            console.log(
              `[${socket.id}]: ${rxBlocks[socket.id].length}/${EXPECTED_N_BLOCKS} - ${
                socket.timestamp
              } sec - PASSED`,
            );
            sockets[socket.id].alive = 0;
            socket.close();
          } else if(allBlocksOk.check == false) {
            console.log(
              `[${socket.id}]: ${rxBlocks[socket.id].length}/${EXPECTED_N_BLOCKS} - ${
                socket.timestamp
              } sec - FAILED`,
            );
            console.log(`missing Blocks ${allBlocksOk.missingBlocks}`);
            sockets[socket.id].alive = 0;
            socket.close();
          }
        }
      } else if (TEST_TYPE === 'syncrollback') {
        clearTimeout(socket.watchdog);
        socket.alive = 0;
        socket.maxBlock = parsed.maxBlock;
        if (parsed.type === 'sync' || parsed.type === 'syncFast') {
            for (var block of parsed.historicalData) {
                if (socket.maxBlock === 1) {
                    break;
                } else if (
                parsed.type === 'sync' &&
                (rxBlocks[socket.id].length === 0 ||
                    rxBlocks[socket.id][rxBlocks[socket.id].length - 1] < block.block.blockNumberL2)
                ) {
                    rxBlocks[socket.id].push(block.block.blockNumberL2);
                } else if (
                parsed.type === 'syncFast' &&
                (rxBlocks[socket.id].length === 0 ||
                    rxBlocks[socket.id][rxBlocks[socket.id].length - 1] < block.blockNumberL2)
                ) {
                    rxBlocks[socket.id].push(block.blockNumberL2);
                } else if (parsed.type === 'rollback') {
                    rollbackBlock = parsed.data.blockNumberL2;
                }
            }
        } else if (parsed.type === 'rollback') {
            rollbackBlock = parsed.data.blockNumberL2;
            expectedLastBlock = rxBlocks[socket.id][rxBlocks[socket.id].length - 1] < rollbackBlock-1 ? rollbackBlock : rxBlocks[socket.id][rxBlocks[socket.id].length - 1];
        }
        if (socket.maxBlock === 1 && rollbackBlock > -1) {
            socket.timestamp = (new Date().getTime() - socket.timestamp) / 1000;
            const allBlocksOk = await checkSyncAndRollbackBlocks(rxBlocks[socket.id], rollbackBlock);
            if (
              rollbackBlock > -1 &&
              allBlocksOk.check
            ) {
              console.log(
                `[${socket.id}]: ${rxBlocks[socket.id].length}/${EXPECTED_N_BLOCKS} - ${
                  socket.timestamp
                } sec - PASSED`,
              );
            } else {
              console.log(
                `[${socket.id}]: ${rxBlocks[socket.id].length}/${EXPECTED_N_BLOCKS} - ${
                  socket.timestamp
                } sec - FAILED`,
              );
              console.log("rollbackBlock", rollbackBlock);
              console.log(`missing Blocks ${allBlocksOk.missingBlocks}`);
              console.log(`Blocks ${rxBlocks[socket.id]}`);
            }
            socket.close();
            return;
        }
          if (parsed.type === 'sync' && parsed.maxBlock !== 1) {
            socket.lastBlock =
              parsed.historicalData[parsed.historicalData.length - 1].block.blockNumberL2;
          }
          keepAlive(socket.id);
      }
    });
  }
}

setupWebSocket();
