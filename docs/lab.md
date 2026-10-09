# FastACL Hardware Lab

The lab runs the HW suites of `docs/test-strategy.md` (L5–L7). This page describes the machines,
the cabling, and how CI reaches the lab. Host names, BMC and PDU addresses, credentials and MAC
addresses are **not** in this repository: they come from the `LAB_ENV` secret, rendered into
`labs/hw/lab.env` at run time (see `labs/hw/lab.env.example` for the variables).

## Machines

| Name | Role | CPU | NIC | Profile |
|------|------|-----|-----|---------|
| server1 | DUT, `2n-rome-cx7`; since 2026-10-09 the six-port TG for `2n-platform` | AMD EPYC 7742 (Rome), 64 cores / 128 threads | was: ConnectX-7, dual port, links at 200 Gbps. Now: 2× ConnectX-7 (`81:00`, `c2:00`, 200G) and 3× ConnectX-5 Ex (`01:00`, `82:00`, `c1:00`, 100G) | `labs/hw/profiles/server1.env`, `GEN=server1` |
| epyc-sp5 | DUT, `2n-genoa-bf3` | AMD EPYC 9534 (Genoa), 64 cores, PCIe Gen5 | BlueField-3 B3240 (integrated ConnectX-7), host NIC mode | `labs/hw/profiles/epyc-sp5.env` |
| epyc-sp5 | DUT, `2n-genoa-cx8` (since 2026-10-07; BlueField-3 removed) | AMD EPYC 9534 (Genoa), 64 cores, 12× DDR5-4800 | alice's ConnectX-8 in CPU SLOT5, links at 400 Gbps; PCIe Gen5 x16 | `labs/hw/profiles/epyc-cx8.env`, TG bob |
| epyc-sp5 | DUT, `2n-platform` (since 2026-10-09) | AMD EPYC 9534 (Genoa), 64 cores, 12× DDR5-4800 | alice's ConnectX-8 (`41:00`, CPU SLOT5), bob's ConnectX-8 (`0a:00`) and the BlueField-3 back in NIC mode (`03:00`); six ports, all ingress | `labs/hw/profiles/epyc-platform.env`, TG server1 |
| bluefield3 | DUT, `2n-bf3-arm` | BlueField-3 Arm, 16× Cortex-A78 | the same BlueField-3 in DPU mode | `labs/hw/dpu/` |
| alice | DUT (profile `alice`) and TG for bob; no NIC since 2026-10-07 (card moved to epyc-sp5) | AMD Ryzen 9 9950X, 16 cores / 32 threads | ConnectX-8, dual port, links at 400 Gbps; PCIe Gen5 x16 (half of the card's Gen6 x16) | `labs/hw/profiles/alice.env`, `GEN=alice` |
| bob | DUT (profile `bob`) and TG for alice | AMD Ryzen 9 9950X, 16 cores / 32 threads | ConnectX-8, dual port, links at 400 Gbps; PCIe Gen5 x16 | `labs/hw/profiles/bob.env`, `GEN=bob` |
| flame1 | TG for server1 | AMD Ryzen 7 5800X | ConnectX-7, dual port | `GEN=flame` |
| lava1 | TG for epyc-sp5 and bluefield3 | AMD Ryzen 9 9950X | 2× ConnectX-5 Ex (one sender card, one receiver card) | `GEN=lava` |
| dell | spare TG | 2× Intel Xeon Gold 6230R | 2× ConnectX-5 | `GEN=dell` |
| rackpi | out-of-band proxy | Raspberry Pi 5 | — | reaches the BMCs and PDUs |

The BMCs (IPMI, iDRAC) and two networked PDUs sit on the lab's management LAN and are reached
only through rackpi. `labs/hw/bringup-guarded.sh` uses them to recover a DUT whose NIC wedged
during DPDK initialisation: first an IPMI power cycle, then a PDU power drain.

alice and bob have no BMC; each has a JetKVM on the same management LAN instead, driven by
`labs/hw/setup/kvm.sh <host> {status|reboot|sysrq-reboot|on|off|cycle|reset}` (and by
`setup/ipmi.sh --target dut` for those profiles). `reboot` (Ctrl+Alt+Del) and `sysrq-reboot`
type on the host's keyboard, so they need a live kernel. Power on/off/cycle/reset press the
motherboard buttons and need the JetKVM ATX extension, which is not fitted yet. Every call takes
over the KVM session, signing out anyone using its web UI.

## alice and bob host changes

Reports from alice and bob before and after these dates were taken on differently configured
hosts. Every report since `f15f13f` names the DUT's memory speed in its header (`DUT memory`).

| Change | Since | Where | Effect |
|---|---|---|---|
| `iommu=pt` on the kernel command line | 2026-10-03 | `setup/install.sh` | TRex rate unchanged (300 Mpps per CX-8 is the card's packet rate); VPP starts in ~72 s instead of ~170 s |
| ASPM L1 off on the Intel I226 management port | 2026-10-05 | `setup/install.sh` (udev rule) | stops the port dropping off PCIe ("PCIe link lost") under heavy transfers |
| DDR5-6000 via EXPO, both hosts | 2026-10-05 | BIOS by hand: Ai Tweaker → Ai Overclock Tuner = EXPO II | memory was running at 4800; see below. Not scripted: a BIOS update or CMOS clear reverts it |
| Firmware reset repeated when the CX-8 PCIe link trains below the slot speed | 2026-10-05 | `setup/mellanox-init.sh` | bob's card came back at 2.5 GT/s on 2 of 8 resets and then ran at ~22 Mpps |

The EXPO profiles differ slightly: alice's modules (KF560C36-16) load DDR5-6000 36-44-44-90,
bob's (KF560C36BBE2-16TR) DDR5-6000 38-48-48-96, both at 1.35 V. Each host passed a 5-minute
`stress-ng --vm --verify` run at 6000 before any measurement.

### Enabling EXPO remotely

Run it with the host idle (no DUT or TRex containers). Watch every step with
`labs/hw/setup/kvm.sh <host> screenshot <file.png>`; keys go through the JetKVM keyboard.

1. On the host: `sudo systemctl reboot --firmware-setup`. The board boots straight into UEFI setup,
   so no key has to be timed during POST.
2. Wait until a screenshot shows the setup screen (EZ Mode), about 80 s. Keys sent earlier are
   lost or land on the wrong screen.
3. Press **F7** for Advanced Mode, then **Right** to the **Ai Tweaker** tab.
4. On **Ai Overclock Tuner** press **Enter**, choose **EXPO II** (three entries below Auto) and
   press **Enter**. The **EXPO** line under it must show the module's profile (DDR5-6000 …, 1.35 V)
   and Target DRAM Frequency 6000 MHz.
5. Press **F10**. The *Save Changes & Reset* dialog must list only Ai Overclock Tuner, Memory
   Frequency and the memory timings; if anything else is there, choose **Cancel** and reset
   without saving (Ctrl+Alt+Del). Otherwise confirm **Ok**.
6. The first boot at the new speed trains the memory (60–110 s here). Then check
   `sudo dmidecode -t memory` shows *Configured Memory Speed: 6000 MT/s* and run
   `stress-ng --vm 32 --vm-bytes 70% --vm-method all --verify --timeout 300s` with no failures
   and no machine-check errors in `dmesg`.

To revert, repeat with Ai Overclock Tuner = Auto.

Same day, same software, CALIBRATE runs of the gate and ceiling stages, DUT absorbed Mpps:

| Test (64 B unless noted) | alice 4800 | alice 6000 | bob 4800 | bob 6000 |
|---|---|---|---|---|
| 5rules-drop | 185.4 | 198.6 | 187.4 | 198.9 |
| country-set-drop | 186.3 | 199.8 | 186.3 | 199.2 |
| 1m-rules-drop, cold-scan | 184.4 | 199.7 | 185.2 | 200.0 |
| 1m-rules-drop, cold-scan-imix | 85.1 | 102.7 | 85.9 | 97.5 |
| 1m-rules-drop-ip6 | 184.5 | 200.0 | 185.0 | 200.1 |
| ceiling, 3/3 rules | 183.8 | 199.8 | 187.9 | 200.1 |
| report | [1307](../reports/2026-10-05_1307_alice_full/) | [1335](../reports/2026-10-05_1335_alice_full/) | [1416](../reports/2026-10-05_1416_bob_full/) | [1526](../reports/2026-10-05_1526_bob_full/) |

At 6000 the 64 B scenarios absorb the full 200 Mpps the suite offers. Offered more by a single
stream (5 drop rules, every processed packet confirmed dropped), alice drops ~196 Mpps at 250 and
300 Mpps offered (157 at 4800) and 187 Mpps with 150 + 150 on two ports (149 at 4800). The cost
of the filter node is unchanged (~76–79 cycles/packet); the receive node `dpdk-input` falls from
~206 to ~150 cycles/packet, so at 4800 the hosts were memory-bound, not CPU-bound.

DRAM traffic stays at ~340–350 bytes per 64 B packet at both speeds (`perf stat` on the
`amd_umc_0/1` PMUs, event `0xa`, `rdwrmask=1` reads / `2` writes, 64 B per count; needs
`modprobe amd_uncore`). AMD SDCI (cache injection) would cut that but is not usable on these
boards: the CPU reports SDCIAE in CPUID, but the BIOS has no TPH/SDCI option and the ACPI tables
no steering-tag `_DSM`, and enabling the CX-8's TPH requester changed nothing measurable.

## Cabling

```
flame1  sender   ──100G──►  server1 eth-left   (ingress)
flame1  receiver ◄─100G───  server1 eth-right  (egress)

lava1   card B   ──100G──►  epyc-sp5 BF-3 port 1  (ingress)
lava1   card A   ◄─100G───  epyc-sp5 BF-3 port 0  (egress)

bob   port 1  ──400G──►  alice port 1  (ingress)      alice port 1 ──400G──►  bob port 1  (ingress)
bob   port 0  ◄─400G───  alice port 0  (egress)       alice port 0 ◄─400G───  bob port 0  (egress)

bob   port 1  ──400G──►  epyc-sp5 CX-8 port 1  (ingress)
bob   port 0  ◄─400G───  epyc-sp5 CX-8 port 0  (egress)
```

Since 2026-10-09 (`2n-platform`, every epyc-sp5 port is an ingress; TRex port number first):

```
server1 0  CX-7 #1   81:00.1  ──200G──►  epyc-sp5 CX-8 A port 1  41:00.1
server1 1  CX-7 #2   c2:00.0  ──200G──►  epyc-sp5 CX-8 B port 1  0a:00.1
server1 2  CX-5 #1   01:00.1  ──100G──►  epyc-sp5 CX-8 B port 0  0a:00.0
server1 3  CX-5 #1   01:00.0  ──100G──►  epyc-sp5 CX-8 A port 0  41:00.0   (autonegotiation off on both ends)
server1 4  CX-5 #2   82:00.0  ──100G──►  epyc-sp5 BF-3 port 0    03:00.0
server1 5  CX-5 #3   c1:00.0  ──100G──►  epyc-sp5 BF-3 port 1    03:00.1
```

The ConnectX-7 to ConnectX-8 links run at 200G on 400G DACs. The `01:00.0`–`41:00.0` DAC links
only at a forced 100G with autonegotiation off on both ends; `GEN_FORCE_100G` and
`SINK_FORCE_100G` in `vars.sh` make `perf-tune.sh` do that. Run it with
`labs/hw/run.sh epyc-platform platform` (`labs/hw/platform-ceiling.sh`): stages add generator cards
one group at a time, small frames only. TRex takes at most 48 data-plane cores, 16 per port pair.
VPP runs 62 workers there, one receive queue each, with 524,288 buffers per NUMA node, and needs
the BIOS at NPS4 (below).

### Tuning epyc-sp5 for the platform ceiling (2026-10-09)

All six ports loaded, 64 B, VPP dropping everything; one trial unless noted:

| Host setting | 16 w | 24 w | 32 w | 48 w | 62 w |
|---|---|---|---|---|---|
| NPS1 (one NUMA node), IOMMU translated | 212 | 296 | 346–355 | 191 | 148 |
| NPS1, `iommu=pt` | | | 328 | | 150 |
| NPS1, 1024-entry receive rings | | | | | 135 |
| **NPS4, `iommu=pt`** | | | 329–336 | 363 | **420–464** (6 trials; full report 2026-10-09_1331: 450) |
| NPS4 + L3 cache as NUMA domain (8 nodes) | | | 332 | 389 | 356–403 (3 trials) |
| NPS4, mlx5 Multi-Packet RQ (`mprq_en=1`) | | | | | 401 |

Why: VPP keeps one packet-buffer pool per NUMA node. Every receive-ring refill
(`dpdk_ops_vpp_dequeue`, `src/plugins/dpdk/buffer.c`) and every freed packet go through a 512-buffer
per-thread cache and, when it runs empty or full, through the shared pool under one spinlock
(`vlib_buffer_pool_get`/`put`, `src/vlib/buffer_funcs.h`). At NPS1 all 62 workers, on eight CPU
dies, share that lock: `dpdk_ops_vpp_dequeue` takes 55 % of a worker, `error_drop` 20 %, the filter
5 %, and `show runtime` shows 937 cycles per packet (dpdk-input 636, drop 193, filter 82). At NPS4
a receive queue takes its buffers from the pool of the NIC's node (`src/plugins/dpdk/device/common.c`):
ConnectX-8 A is on node 2 (24 workers), ConnectX-8 B and the BlueField-3 on node 3 (38 workers), and
each pool's memory sits in that quadrant. The same 62 workers then spend 291 cycles per packet
(dpdk-input 105, drop 17, filter 102) and allocation is 9 % of a worker. `iommu=pt` and
Multi-Packet RQ change nothing measurable; L3-as-NUMA is worse than NPS4 alone.

The BIOS options are Advanced > ACPI Settings > *NUMA Nodes Per Socket* and *ACPI SRAT L3 Cache
As NUMA Domain*. Redfish refuses BIOS settings on this BMC (no DCMS licence), so
`labs/hw/setup/bios-numa.py --nps 4` sets them through the BMC's HTML5 KVM (Playwright through a
SOCKS tunnel to the lab proxy), reboots and checks `numactl -H`. `run.sh epyc-platform platform`
runs it by itself when the host's node count differs from `SINK_NUMA_NODES` (the machine running
`run.sh` needs Python Playwright with Chromium for that), the sink warns about a mismatch, and every
platform report shows the node count.

On 2026-10-09 alice, bob, flame1 and lava1 were offline: bob's ConnectX-8 is in epyc-sp5, so only
`epyc-platform` runs.

alice and bob are cabled port to port, so either is the DUT and the other its generator: profile
`alice` puts the DUT on alice, profile `bob` on bob. TRex releases up to v3.06 do not know the
ConnectX-8, so their generator image is built once from TRex source (`docker/Dockerfile.trex-src`,
pinned commit, DPDK 25.07) and kept as a private package, `ghcr.io/garyachy/fastacl-testbench-trex`.
`labs/hw/gen-image.sh` pulls it on the machine running the bench (with `GHCR_TOKEN` or the `gh`
login, through a throw-away docker config) and streams it to the generator with `docker save | docker
load`, so no registry credential is stored on a lab host. VPP runs 15 workers on cores 1-15; the hosts have no BMC.

Since 2026-10-07 alice's ConnectX-8 sits in epyc-sp5 (CPU SLOT5) and the BlueField-3 is out of the box,
so only `epyc-cx8` (DUT epyc-sp5, generator bob) runs; `epyc-sp5`, `bluefield3`, `alice` and `bob`
need their cards back first.

Two separate generator cards on lava1 avoid the receive ceiling of a single dual-port adapter.
The BlueField-3 is owned by the host (NIC mode) for `2n-genoa-bf3` and by its Arm cores (DPU
mode) for `2n-bf3-arm`. Switching mode needs a cold power cycle; `labs/hw/bf-mode.sh nic|dpu`
does it unattended (mlxconfig on the Arm, IPMI cycle of epyc-sp5, verify), and the suite
scripts call it so each run finds the card in the mode it needs.

## epyc-sp5 host changes

| Change | Since | Where | Effect |
|---|---|---|---|
| BlueField-3 removed, alice's ConnectX-8 fitted in CPU SLOT5 (`41:00.0/.1`), cabled port to port with bob | 2026-10-07 | by hand | new rig `epyc-cx8`; card links at PCIe Gen5 x16 (the card is Gen6) |
| bob's ConnectX-8 added (`0a:00.0/.1`), BlueField-3 refitted (`03:00`), all cabled to server1 | 2026-10-09 | by hand | new rig `epyc-platform` |
| `iommu=pt` added to the kernel command line (backup `grub.bak-20261009`) | 2026-10-09 | `/etc/default/grub` | no throughput change; matches the other hosts |
| BIOS NUMA Nodes Per Socket: Auto (NPS1) → **NPS4** | 2026-10-09 | `setup/bios-numa.py` | VPP drops 450 Mpps instead of 148 with 62 workers (see tuning above) |
| `isolcpus`, `nohz_full`, `rcu_nocbs` widened from `1-32` to `1-63` | 2026-10-07 | `/etc/default/grub` by hand (backup `grub.bak-20261007`) | lets VPP run up to 62 workers; VPP refuses 63 (`VPP_MAX_WORKERS` 64 counts the main thread) |

**Run VPP with 32 workers on this rig** (the `epyc-cx8` default). Every worker owns one receive
queue, and the ConnectX-8 loses packets at the port once more than 32 queues are active, as the
ConnectX-7 does. A sweep on 2026-10-07 (32 / 48 / 62 workers, 300 Mpps offered) showed:

| Scenario | 32 | 48 | 62 |
|---|---|---|---|
| 5 rules, 64 B, one flow set | 298 | 200 | — |
| country-rules-drop | 235 | 294 | 207 |
| 1M rules, mix-udptcp | 219 | 269 | 240 |
| 1M rules, 983K active flows | 163 | 250 | 267 |

48 or 62 workers only help the scenarios whose per-packet cost is high (hundreds of cycles); every
light one loses 25-35 % in the NIC instead. Raise `DUT_POLL_WORKERS` only to study those.

Until 2026-10-09 epyc-sp5 booted without `iommu=pt` (IOMMU in translated mode, lazy flush). It
has no MFT on the host, so `mellanox-init` runs inside the DUT image, which therefore carries
`pciutils` for `mlxfwreset`. Its MACs are `LAB_MAC_LEFT_epyc_cx8` / `LAB_MAC_RIGHT_epyc_cx8` in `lab.env`.

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
