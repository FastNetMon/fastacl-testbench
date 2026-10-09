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
| ConnectX-7, dual port, 100G / 200G | 139–140 at 100G (line rate); **258–264** at 200G | **~278** | 142 (line rate) | at least **277–280** | 127 (= offered by flame1) | ~120 | TX: the card's packet rate. VPP: loss at the port above ~32 active receive queues |
| BlueField-3 B3240, NIC mode (ConnectX-7 inside), 100G | — | — | 142 (line rate) | ~290 of 297.6 sent | 142 (line rate) | ~110 (14 workers) | the sender for NIC receive; VPP workers for VPP drop |
| BlueField-3, DPU mode (Arm VPP), 100G | — | — | — | — | ~60 | ~60 | the 16 Arm cores, not the NIC |
| ConnectX-8, dual port, 400G, Gen5 x16 slot | ~300 | **~300** | at least ~300 | at least **311**, zero NIC loss | **298** (epyc-sp5, 32 workers); 196–200 (alice) | at least 298 (all bob sends) | TX: the card's packet rate (NVIDIA's DPDK report also shows 299.6). Receive: unknown, because bob can't send more. On alice VPP is limited by CPU and memory |

The ConnectX-7 also drops in hardware when the rules are offloaded to it: 272.8 of ~280 Mpps
received, with nothing reaching VPP.

All rates are in Mpps.

## Whole host (epyc-sp5, 2026-10-09)

Two ConnectX-8 and the BlueField-3 in one EPYC 9534, fed by six server1 ports (`2n-platform`):

| What | Mpps |
|---|---|
| server1 sends, six ports | 893 |
| epyc-sp5 NICs receive | ~875 |
| VPP drops, all six ports, 32 workers | **346** |
| VPP drops, all six ports, 62 workers | 148 |

More VPP workers make it worse: with 62 workers each spends most of its time allocating and
freeing packet buffers from VPP's one shared pool (`dpdk_ops_vpp_dequeue` 55 %, `error_drop` 20 %,
the filter 5 %). Full load, one trial each: 16 workers 212, 24 → 296, 32 → 346, 48 → 191,
62 → 148 Mpps. The NICs are not the limit. The published report (`*_epyc-platform_platform`,
2026-10-09) ran 62 workers; the bench now defaults to 32.

## ConnectX-8 at other frame sizes

| Frame | TX, whole card (bob) | Comment |
|---|---|---|
| 64 B | ~300 Mpps | card's packet rate |
| 128 B | ~200 Mpps | |
| 256 B | ~120 Mpps | |
| 512 B | ~80 Mpps | |
| 1024 B, 1518 B | 400–411 Gbps | Gen5 x16 PCIe bandwidth; the second port adds almost nothing |
| 4096 B / 9000 B | ~380 / ~350 Gbps | jumbo frames are slower |
| IMIX (354 B average) | ~120–130 Mpps (~390 Gbps) | epyc-sp5 receives all of it |

## Notes

- epyc-sp5 with the ConnectX-8 sometimes starts in a state where the card drops a fixed ~10.4 %
  at the port (`rx_discards_phy`) whatever the load, which caps it at ~269 Mpps. The suspect is
  the IOMMU running in translated mode; a reboot with `iommu=pt` is still to be tried.
- The ConnectX-7 and ConnectX-8 both lose packets at the port once more than ~32 receive queues
  are active, so VPP runs 32 workers on them (see `docs/lab.md`).
- To tell a NIC limit from a generator limit, compare the DUT's `rx_packets_phy` with what TRex
  reports sent, and watch `rx_discards_phy` / `rx_prio0_buf_discard` (loss inside the card) and
  `rx_out_of_buffer` (VPP not keeping up).
