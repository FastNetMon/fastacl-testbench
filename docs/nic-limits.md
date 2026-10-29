# NIC limits measured in the lab

Highest packet rates each adapter has reached in this lab, at 64 B frames (64 B before FCS,
68 B on the wire) unless the row says otherwise.

- **TX**: what the card sends as a TRex generator.
- **NIC receive**: what the card takes in from the wire without loss at the port
  (`rx_packets_phy` with no `rx_discards_phy`).
- **VPP drop**: what FastACL in VPP receives and drops (5 drop rules), so CPU and memory count too.

"At least" means the sender ran out first, so the card's own limit is higher and still unmeasured.

| NIC | TX, one port | TX, whole card | NIC receive, one port | NIC receive, whole card | VPP drop, one port | VPP drop, whole card | What sets the limit |
|---|---|---|---|---|---|---|---|
| ConnectX-5 Ex, dual port, 100G | 142 (line rate); 148.8 at 64 B with FCS | ~200 (server1, ~100 per port) | 140.4 (line rate) | **~123**: the card discards ~56 % of 281 offered | 142 (line rate) | 123 | one packet engine shared by both ports. Two separate cards gave 190 in VPP, then the Rome host's I/O die was the limit |
| ConnectX-7, dual port, 100G / 200G | 139–140 at 100G (line rate); **258–264** at 200G with 16 TRex cores, **280** with 23 (server1, 2026-10-29) | **~278–280** | 142 (line rate) | at least **277–280** | 127 (= offered by flame1) | ~120 | TX: the card's packet rate. VPP: loss at the port above ~32 active receive queues |
| BlueField-3 B3240, NIC mode (ConnectX-7 inside), 100G; 400G in server1 since 2026-10-28 | **246–248** at 400G (server1, 24 TRex cores); 200 Gbps at 1500 B (PCIe Gen4 x16) | — | 142 (line rate) | ~290 of 297.6 sent | 142 (line rate) | ~110 (14 workers) | the sender for NIC receive; VPP workers for VPP drop |
| BlueField-3, DPU mode (Arm VPP), 100G | — | — | — | — | ~60 | ~60 | the 16 Arm cores, not the NIC |
| ConnectX-8, dual port, 400G, Gen5 x16 slot | ~300 | **~300** | at least ~300 | at least **311**, zero NIC loss | **298** (epyc-sp5, 32 workers); 196–200 (alice) | at least 298 (all bob sends) | TX: the card's packet rate (NVIDIA's DPDK report also shows 299.6). Receive: unknown, because bob can't send more. On alice VPP is limited by CPU and memory |
| ConnectX-8, socket direct (two Gen5 x16), epyc-sp5, 2026-10-29 | — | — | **~226–230** of 560 offered (one function alone: ~212) | **~229** of 759 offered, both ports | **226.4** (16 + 16 workers) | 172 (48 workers; port 0's 16 were the limit) | the card's intake: ~230 Mpps whether one port or both are loaded; the second x16 adds bandwidth (400 Gbps lossless on one port at 1500 B), not packet rate. See the section below |

The ConnectX-7 also drops in hardware when the rules are offloaded to it: 272.8 of ~280 Mpps
received, with nothing reaching VPP.

All rates are in Mpps.

## Whole host (epyc-sp5, until 2026-10-28)

Two ConnectX-8 and the BlueField-3 in one EPYC 9534, fed by six server1 ports (`2n-platform`):

| What | Mpps | Gbps (wire) | Cores |
|---|---|---|---|
| server1 sends, six ports | 893 | 600 | 48 (TRex data-plane cores) |
| epyc-sp5 NICs receive | ~875 | ~588 | — (in the NICs) |
| VPP drops, all six ports, NPS4, 62 workers | **450** (median of 3, 439–464; report 2026-10-09_1331) | 303 | 62 workers |
| VPP drops, all six ports, NPS1, 32 workers | 355 | 239 | 32 workers |
| VPP drops, all six ports, NPS1, 62 workers | 148 | 99 | 62 workers |
| FastACL with ~1M rules drops, all six ports, NPS4 (2026-10-20, TupleMerge) | **413** UDP flood; 402–428 across 7 attack types | 278 (270–288) | 62 workers |

Gbps is the rate on the wire. This rig's 64 B frames include the FCS, so each takes 84 B there
with the preamble and inter-frame gap: 1 Mpps = 0.672 Gbps, and 148.8 Mpps fill 100 Gbps. The six
ports are 2 × 200G + 4 × 100G, 800 Gbps in all; 64 B line rate across them is ~1,190 Mpps. Each VPP worker is one physical core
(cores 1–63 isolated, core 0 runs VPP's main thread); the 64 SMT siblings are not used.

With the BIOS at one NUMA node per socket (NPS1), VPP's workers share one packet-buffer pool and
spend most of their time on it (`dpdk_ops_vpp_dequeue` 55 %, `error_drop` 20 %, the filter 5 %), so
62 workers drop less than 32. NPS4 gives four pools: 62 workers then drop 450 Mpps. The NICs are
not the limit. Details and the other settings tried: `docs/lab.md`, "Tuning epyc-sp5".

## One ConnectX-8, socket direct (epyc-sp5, `2n-genoa-cx8sd`, 2026-10-29)

Both Gen5 x16 links active, port 1 fed with 560 Mpps of 64 B (64 B with FCS here) by two
ConnectX-7 through a MikroTik switch:

| What | Mpps | Gbps (wire) | Cores |
|---|---|---|---|
| server1 sends, two ConnectX-7 | 560 | 376 | 46 TRex cores |
| ConnectX-8 port 1 takes in | ~230 (~330 discarded at the port) | ~154 | — |
| VPP drops, port 1, 16 + 16 queues | **226** | 152 | 32 workers |
| VPP drops, port 1, 31 + 31 queues | 168 | 113 | 62 workers |
| ConnectX-8, both ports, 759 Mpps offered | 229 taken in, 172 dropped by VPP | | 48 workers |
| Port 1 at 1500 B | 32.9 = **400 Gbps**, no loss | 400 | 32 workers |

Reports `2026-10-29_1215_epyc-sd-pps_platform` and `2026-10-29_1234_epyc-sd_platform`.

The card takes in ~230 Mpps of small frames whether one port or both are loaded; the
auxiliary x16 adds bandwidth (400 Gbps lossless on one port) but not packet rate. Details:
`docs/lab.md`, "Socket-direct ConnectX-8".

## ConnectX-8 at other frame sizes

Frame sizes include the FCS; the rate on the wire is Mpps × (S + 20) × 8 / 1000 Gbps.

| Frame | TX, whole card (bob), Mpps | Gbps (wire) | Comment |
|---|---|---|---|
| 64 B | ~300 | ~202 | card's packet rate |
| 128 B | ~200 | ~237 | |
| 256 B | ~120 | ~265 | |
| 512 B | ~80 | ~340 | |
| 1024 B, 1518 B | ~48–49 / ~32–33 | 400–411 | Gen5 x16 PCIe bandwidth; the second port adds almost nothing |
| 4096 B / 9000 B | ~11.5 / ~4.8 | ~380 / ~350 | jumbo frames are slower |
| IMIX (354 B average) | ~120–130 | ~390 | epyc-sp5 receives all of it |

## Notes

- epyc-sp5 with the ConnectX-8 sometimes starts in a state where the card drops a fixed ~10.4 %
  at the port (`rx_discards_phy`) whatever the load, which caps it at ~269 Mpps. The suspect is
  the IOMMU running in translated mode; a reboot with `iommu=pt` is still to be tried.
- The ConnectX-7 and ConnectX-8 both lose packets at the port once more than ~32 receive queues
  are active, so VPP runs 32 workers on them (see `docs/lab.md`).
- To tell a NIC limit from a generator limit, compare the DUT's `rx_packets_phy` with what TRex
  reports sent, and watch `rx_discards_phy` / `rx_prio0_buf_discard` (loss inside the card) and
  `rx_out_of_buffer` (VPP not keeping up).
