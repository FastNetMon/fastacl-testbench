# NIC limits measured in the lab

Highest packet rates each adapter has reached in this lab, at 64 B frames (64 B before FCS,
68 B on the wire) unless the row says otherwise. **TX** is the rate a card sends as a TRex
generator. **RX** is the rate a card takes in as the DUT. "At least" means the sender ran out
first, so the card's own limit is higher and still unmeasured.

| NIC | Link | TX, one port | TX, whole card | RX, one port | RX, whole card | What sets the limit |
|---|---|---|---|---|---|---|
| ConnectX-5 Ex, dual port | 100G | 142 (line rate) | ~167 (flame1) | 140.4, zero discards (line rate) | **123** into VPP, both ports on one card | one packet engine shared by both ports; two separate cards gave 190 in total, then the Rome host's I/O die was the limit |
| ConnectX-7, dual port | 100G | 139–140 (line rate) | **~278** | 142 into VPP (line rate) | at least **277–280** with hardware drop offload, zero discards; ~120 into VPP over both ports | TX: the card's packet rate. RX into VPP: loss at the port above ~32 active receive queues |
| BlueField-3 B3240, NIC mode (ConnectX-7 inside) | 100G | — | — | 142 into VPP (line rate) | — | the sender (lava1); never driven harder |
| BlueField-3, DPU mode (Arm VPP) | 100G | — | — | ~60 | ~60 | the 16 Arm cores, not the NIC |
| ConnectX-8, dual port, Gen5 x16 slot | 400G | ~300 | **~300** | at least **298** into VPP (epyc-sp5, 32 workers) | ~300 | TX: the card's packet rate (NVIDIA's DPDK report also shows 299.6). RX: unknown, because bob can't send more |

All rates are in Mpps.

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

- ConnectX-8 RX on Ryzen hosts (alice, bob) is lower, 196–200 Mpps, because their CPU and
  dual-channel memory run out first, not the card.
- epyc-sp5 with the ConnectX-8 sometimes starts in a state where the card drops a fixed ~10.4 %
  at the port (`rx_discards_phy`) whatever the load, which caps it at ~269 Mpps. The suspect is
  the IOMMU running in translated mode; a reboot with `iommu=pt` is still to be tried.
- The ConnectX-7 and ConnectX-8 both lose packets at the port once more than ~32 receive queues
  are active, so VPP runs 32 workers on them (see `docs/lab.md`).
- To tell a NIC limit from a generator limit, compare the DUT's `rx_packets_phy` with what TRex
  reports sent, and watch `rx_discards_phy` / `rx_prio0_buf_discard` (loss inside the card) and
  `rx_out_of_buffer` (VPP not keeping up).
