# BTC ↔ QBT atomic-swap demo

End-to-end, on regtest, demonstrating why the node needs to sign non-template p2mr script-path leaves.
The Qbit side of the swap is an HTLC (`p2mr`) leaf, and each party signs it by handing a PSBT to their
**own Qbit node** via `walletprocesspsbt`. Without generic p2mr partial signing the node returns an
empty witness and the swap can neither be completed nor refunded in-node.

`atomic_swap_demo.py` runs three scenarios (Tier-Nolan; Alice has BTC and wants QBT, Bob the reverse):

| scenario       | what happens                            | what it proves |
|----------------|-----------------------------------------|----------------|
| `swap`         | both parties execute                    | the swap completes atomically; Alice's **claim** is signed by her node via `walletprocesspsbt` |
| `bob-aborts`   | Alice funds BTC, Bob never funds QBT     | Alice reclaims her BTC after the timeout; a one-sided abort costs her nothing |
| `alice-aborts` | both fund, Alice never claims            | Bob reclaims his QBT via his node (`walletprocesspsbt` signing the **refund** branch) and Alice reclaims her BTC |

Together they exercise **both** HTLC branches — claim (receiver key) and refund (funder key) — and
show that a refund is rejected before its CLTV timeout and accepted after.

## Prerequisites
- `qbitd` and `qbit-cli` built from this branch (`cmake --build build`).
- Docker (for the Bitcoin Core regtest node).
- Python 3 (standard library only — the demo implements the BTC-side secp256k1/ECDSA/BIP143 itself).

## Run
```sh
# from the repo root, after building:
./contrib/atomic-swap-demo/setup-regtest.sh      # starts both regtest nodes, prints the env to export

export QBIT_CLI="…"   # <- copy the two lines the script prints
export BTC_CLI="…"

python3 contrib/atomic-swap-demo/atomic_swap_demo.py swap
python3 contrib/atomic-swap-demo/atomic_swap_demo.py bob-aborts
python3 contrib/atomic-swap-demo/atomic_swap_demo.py alice-aborts
```
Each prints a `PASS`/`FAIL` line and exits non-zero on failure. Tear down with the commands
`setup-regtest.sh` prints at the end (`docker rm -f btcregtest` and `qbit-cli … stop`).

## Notes
- The Bitcoin leg uses a **P2WSH** HTLC (the same script shape as the Qbit `p2mr` leaf, for symmetry
  and simple ECDSA/BIP143 signing). A Taproot script-path variant is a planned client-side addition;
  it doesn't affect this node change.
- Only the Qbit node needs this branch's patch — the Bitcoin side is stock Bitcoin Core.
