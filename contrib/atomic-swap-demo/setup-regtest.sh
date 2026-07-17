#!/usr/bin/env bash
#
# Bring up the two regtest nodes the atomic-swap demo needs:
#   - a Qbit regtest node, from the qbitd/qbit-cli you built from this branch
#   - a Bitcoin Core regtest node (via Docker)
# and print the QBIT_CLI / BTC_CLI environment the demo reads.
#
# Usage (from the repo root, after `cmake --build build`):
#   ./contrib/atomic-swap-demo/setup-regtest.sh
# Override any of these via env: QBITD, QBIT_CLI_BIN, QBIT_DATADIR, BTC_CONTAINER, BTC_IMAGE.
#
set -euo pipefail

QBITD=${QBITD:-./build/bin/qbitd}
QBIT_CLI_BIN=${QBIT_CLI_BIN:-./build/bin/qbit-cli}
QBIT_DATADIR=${QBIT_DATADIR:-$HOME/.qbit-swap-regtest}
BTC_CONTAINER=${BTC_CONTAINER:-btcregtest}
BTC_IMAGE=${BTC_IMAGE:-bitcoin/bitcoin:latest}
RPC_USER=lab
RPC_PASS=lab

command -v docker >/dev/null 2>&1 || { echo "error: docker is required for the Bitcoin Core regtest node" >&2; exit 1; }
[ -x "$QBITD" ]        || { echo "error: qbitd not found at '$QBITD' -- build it (cmake --build build) or set QBITD" >&2; exit 1; }
[ -x "$QBIT_CLI_BIN" ] || { echo "error: qbit-cli not found at '$QBIT_CLI_BIN' -- set QBIT_CLI_BIN" >&2; exit 1; }

QBITD=$(readlink -f "$QBITD")
QBIT_CLI_BIN=$(readlink -f "$QBIT_CLI_BIN")
mkdir -p "$QBIT_DATADIR"
QBIT_CLI="$QBIT_CLI_BIN -regtest -datadir=$QBIT_DATADIR -rpcuser=$RPC_USER -rpcpassword=$RPC_PASS"
BTC_CLI="docker exec $BTC_CONTAINER bitcoin-cli -regtest -rpcuser=$RPC_USER -rpcpassword=$RPC_PASS"

echo "[1/3] starting Bitcoin Core regtest ($BTC_IMAGE) as container '$BTC_CONTAINER' ..."
docker rm -f "$BTC_CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$BTC_CONTAINER" "$BTC_IMAGE" \
  -regtest -server -txindex -fallbackfee=0.0002 \
  -rpcuser=$RPC_USER -rpcpassword=$RPC_PASS -rpcbind=127.0.0.1 -rpcallowip=127.0.0.1 >/dev/null

echo "[2/3] starting Qbit regtest ($QBITD) with datadir $QBIT_DATADIR ..."
"$QBITD" -regtest -datadir="$QBIT_DATADIR" -server -daemon \
  -rpcuser=$RPC_USER -rpcpassword=$RPC_PASS -rpcport=18452 -fallbackfee=0.0002 -txindex >/dev/null

echo "[3/3] waiting for both RPCs ..."
for _ in $(seq 1 30); do $QBIT_CLI getblockcount >/dev/null 2>&1 && break; sleep 1; done
for _ in $(seq 1 30); do $BTC_CLI getblockcount  >/dev/null 2>&1 && break; sleep 1; done

cat <<EOF

Both regtest nodes are up. Run the demo like this:

  export QBIT_CLI="$QBIT_CLI"
  export BTC_CLI="$BTC_CLI"

  python3 contrib/atomic-swap-demo/atomic_swap_demo.py swap          # successful swap
  python3 contrib/atomic-swap-demo/atomic_swap_demo.py bob-aborts    # Alice recovers her BTC
  python3 contrib/atomic-swap-demo/atomic_swap_demo.py alice-aborts  # both parties recover

Tear down when finished:
  docker rm -f $BTC_CONTAINER
  $QBIT_CLI stop
EOF
