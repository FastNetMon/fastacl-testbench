# FastACL Hardware Lab

The lab runs the HW suites of `docs/test-strategy.md` (L5–L7). This page describes the machines,
the cabling, and how CI reaches the lab. Host names, BMC and PDU addresses, credentials and MAC
addresses are **not** in this repository: they come from the `LAB_ENV` secret, rendered into
`labs/hw/lab.env` at run time (see `labs/hw/lab.env.example` for the variables).

## Machines

| Name | Role | CPU | NIC | Profile |
|------|------|-----|-----|---------|
| server1 | DUT, `2n-rome-cx7` | AMD EPYC 7742 (Rome), 64 cores / 128 threads | ConnectX-7, dual port, links at 200 Gbps | `labs/hw/profiles/server1.env` |
| epyc-sp5 | DUT, `2n-genoa-bf3` | AMD EPYC 9534 (Genoa), 64 cores, PCIe Gen5 | BlueField-3 B3240 (integrated ConnectX-7), host NIC mode | `labs/hw/profiles/epyc-sp5.env` |
| bluefield3 | DUT, `2n-bf3-arm` | BlueField-3 Arm, 16× Cortex-A78 | the same BlueField-3 in DPU mode | `labs/hw/dpu/` |
| alice | DUT (profile `alice`) and TG for bob | AMD Ryzen 9 9950X, 16 cores / 32 threads | ConnectX-8, dual port, links at 400 Gbps; PCIe Gen5 x16 (half of the card's Gen6 x16) | `labs/hw/profiles/alice.env`, `GEN=alice` |
| bob | DUT (profile `bob`) and TG for alice | AMD Ryzen 9 9950X, 16 cores / 32 threads | ConnectX-8, dual port, links at 400 Gbps; PCIe Gen5 x16 | `labs/hw/profiles/bob.env`, `GEN=bob` |
| flame1 | TG for server1 | AMD Ryzen 7 5800X | ConnectX-7, dual port | `GEN=flame` |
| lava1 | TG for epyc-sp5 and bluefield3 | AMD Ryzen 9 9950X | 2× ConnectX-5 Ex (one sender card, one receiver card) | `GEN=lava` |
| dell | spare TG | 2× Intel Xeon Gold 6230R | 2× ConnectX-5 | `GEN=dell` |
| rackpi | out-of-band proxy | Raspberry Pi 5 | — | reaches the BMCs and PDUs |

The BMCs (IPMI, iDRAC) and two networked PDUs sit on the lab's management LAN and are reached
only through rackpi. `labs/hw/bringup-guarded.sh` uses them to recover a DUT whose NIC wedged
during DPDK initialisation: first an IPMI power cycle, then a PDU power drain.

## Cabling

```
flame1  sender   ──100G──►  server1 eth-left   (ingress)
flame1  receiver ◄─100G───  server1 eth-right  (egress)

lava1   card B   ──100G──►  epyc-sp5 BF-3 port 1  (ingress)
lava1   card A   ◄─100G───  epyc-sp5 BF-3 port 0  (egress)

bob   port 1  ──400G──►  alice port 1  (ingress)      alice port 1 ──400G──►  bob port 1  (ingress)
bob   port 0  ◄─400G───  alice port 0  (egress)       alice port 0 ◄─400G───  bob port 0  (egress)
```

alice and bob are cabled port to port, so either is the DUT and the other its generator: profile
`alice` puts the DUT on alice, profile `bob` on bob. TRex releases up to v3.06 do not know the
ConnectX-8, so their generator image is built once from TRex source (`docker/Dockerfile.trex-src`,
pinned commit, DPDK 25.07) and kept as a private package, `ghcr.io/garyachy/fastacl-testbench-trex`.
`labs/hw/gen-image.sh` pulls it on the machine running the bench (with `GHCR_TOKEN` or the `gh`
login, through a throw-away docker config) and streams it to the generator with `docker save | docker
load`, so no registry credential is stored on a lab host. VPP runs 15 workers on cores 1-15; the hosts have no BMC.

Two separate generator cards on lava1 avoid the receive ceiling of a single dual-port adapter.
The BlueField-3 is owned by the host (NIC mode) for `2n-genoa-bf3` and by its Arm cores (DPU
mode) for `2n-bf3-arm`. Switching mode needs a cold power cycle; `labs/hw/bf-mode.sh nic|dpu`
does it unattended (mlxconfig on the Arm, IPMI cycle of epyc-sp5, verify), and the suite
scripts call it so each run finds the card in the mode it needs.

## Access from CI

Workflows run on GitHub-hosted runners and reach the lab over a Tailscale tailnet:

| Secret | Contents |
|--------|----------|
| `TS_AUTHKEY` | Tailscale auth key (reusable, ephemeral, untagged) that joins the runner as a device of the user the lab hosts are shared with |
| `LAB_SSH_KEY` | private key authorised on the lab hosts |
| `LAB_ENV` | the full `labs/hw/lab.env`: host names, SSH user, BMC and PDU credentials, MACs |
| `FASTACL_RELEASE_TOKEN` | read-only token for downloading FastACL release bundles |
| `FASTACL_LAB_LICENSE_JSON`, `FASTACL_LAB_LICENSE_SIG` | a FastACL licence bound to the lab DUTs (optional; otherwise the bundle's evaluation licence) |

All HW workflows share the `hw-lab` concurrency group, so only one run uses the lab at a time.
Every run syncs this repository and the bundle to the hosts, builds the DUT image from the
bundle, runs the suite, publishes the report, and tears the hosts back down: containers, images
and the synced checkout are removed.

## Running by hand

From a machine on the tailnet with a filled-in `labs/hw/lab.env`:

```sh
export DUT=server1 GEN=flame HOST_REPO=fastacl-testbench
rsync -az ./ "$LAB_SSH_USER@<dut>:~/fastacl-testbench/"       # and to the generator
ssh "$LAB_SSH_USER@<dut>" 'bash ~/fastacl-testbench/labs/hw/dut-image.sh'
DUT_SEL=$DUT labs/hw/bringup-guarded.sh
PROFILE=server1 labs/hw/suite.sh gate
python3 labs/hw/report.py results/run.jsonl --out-dir out
labs/hw/teardown.sh
```
