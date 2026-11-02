# FastACL hardware bench: epyc-sd-pps, platform suite

**CALIBRATION RUN (no verdict)**: 0 checks passed, 0 failed, 17 recorded measurements. 2026-10-29 11:56 UTC.

| | |
|---|---|
| Topology | server1 (TRex, two ports): ConnectX-7 #1 and #2 at 200G through a MikroTik switch into ConnectX-8 port 1 (400G optics); the ConnectX-8 runs socket direct, ConnectX-7 #1 feeds the port 1 function on the first PCIe Gen5 x16 link and #2 the one on the second; every DUT port is an ingress and drops everything |
| DUT CPU | AMD EPYC 9534 64-Core Processor (128 CPUs), memory 12 x 4800 MT/s |
| DUT kernel | 6.8.0-147-generic, IOMMU iommu=pt |
| DUT NUMA | 4 node(s) (BIOS NUMA nodes per socket) |
| DUT ports | sd-p1a (16 queues), sd-p1b (16 queues) |
| VPP | 32 worker threads, one receive queue each, 524288 buffers per NUMA node |
| Generator | AMD EPYC 7742 64-Core Processor (128 CPUs), TRex ghcr.io/garyachy/fastacl-testbench-trex:27e0153b |
| FastACL | release latest-main, 5 drop rules (`5rules-drop`) |
| Testbench | 96f6d00 |
| Run | local |

## Method

- The generator sends UDP frames of the stage's size (**frame**, FCS included: 64 B is 84 B on the wire) at the line rate of every port in the stage; each stage adds generator cards. The destination port matches the drop rules, so FastACL drops every packet VPP receives.
- The source address increments over 65,536 values so RSS spreads the load over the queues. Where one generator port feeds two DUT functions (a socket-direct port), it alternates between their MACs and its sent rate is shown split evenly between them.
- **sent** is the generator's `tx_packets_phy`; **NIC received** is the DUT's `rx_packets_phy` (`rx_vport_unicast_packets` on a socket-direct port, whose two functions share the port counters; its `rx_discards_phy` is counted once); **NIC dropped** is `rx_discards_phy + rx_out_of_buffer`; **VPP received** is the interface receive counter; **VPP dropped** is FastACL's aggregate drop counter. Packets the NIC received but VPP did not take (ring full, `rx_prio0_buf_discard`) are the gap between NIC received and VPP received.
- Each stage runs several trials; the summary shows the trial with the median VPP drop rate.
- Rates are in Mpps; **Gbps** columns are the rate on the wire, (frame + 20 B) x 8 bits per packet, so at 64 B 1 Mpps is 0.672 Gbps and 148.8 Mpps fill 100 Gbps. **VPP workers** counts the receive queues of the stage's ports: each queue is one worker on its own physical core.

## Summary (median trial)

| stage | generator | frame | offered per port | trials | VPP workers | sent | NIC received | NIC dropped | VPP received | VPP dropped | sent Gbps | VPP dropped Gbps |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cx7-1 | ConnectX-7 #1 alone | 64 B | line rate | 3 | 16 | 280 | 190.8 | 89.2 | 189.9 | 189.9 | 188.2 | 127.6 |
| cx7-2 | ConnectX-7 #2 alone | 64 B | line rate | 3 | 16 | 280 | 190.5 | 89.5 | 189.8 | 189.8 | 188.2 | 127.6 |
| p1-r100 | both ConnectX-7 into ConnectX-8 port 1 | 64 B | 100 Mpps | 3 | 32 | 200 | 200 | 0 | 200 | 200.0 | 134.4 | 134.4 |
| p1-r140 | both ConnectX-7 into ConnectX-8 port 1 | 64 B | 140 Mpps | 3 | 32 | 280 | 224.3 | 55.7 | 224.3 | 224.3 | 188.2 | 150.8 |
| p1-64 | both ConnectX-7 into ConnectX-8 port 1 | 64 B | line rate | 3 | 32 | 560 | 226.4 | 333.6 | 226.4 | 226.4 | 376.3 | 152.1 |

## Per port (median trial)

| stage | DUT port | VPP workers | sent | NIC received | NIC dropped | VPP received | VPP received Gbps |
|---|---|---|---|---|---|---|---|
| cx7-1 | sd-p1a | 16 | 280 | 190.8 | 89.2 | 189.9 | 127.6 |
| cx7-2 | sd-p1b | 16 | 280 | 190.5 | 89.5 | 189.8 | 127.6 |
| p1-r100 | sd-p1a | 16 | 100 | 100 | 0 | 100 | 67.2 |
| p1-r100 | sd-p1b | 16 | 100 | 100 | 0 | 100 | 67.2 |
| p1-r140 | sd-p1a | 16 | 140 | 114.3 | 55.7 | 114.3 | 76.8 |
| p1-r140 | sd-p1b | 16 | 140 | 110.0 | 0 | 110.1 | 74 |
| p1-64 | sd-p1a | 16 | 280 | 113.2 | 333.6 | 113.2 | 76.1 |
| p1-64 | sd-p1b | 16 | 280 | 113.2 | 0 | 113.2 | 76.1 |

## All trials (Mpps)

| stage | trial | sent | NIC received | NIC dropped | VPP received | VPP dropped |
|---|---|---|---|---|---|---|
| cx7-1 | 1 | 280 | 190.8 | 89.2 | 189.9 | 189.9 |
| cx7-1 | 2 | 280 | 190.8 | 89.2 | 189.9 | 189.9 |
| cx7-1 | 3 | 280 | 190.8 | 89.2 | 189.9 | 189.9 |
| cx7-2 | 1 | 280 | 190.4 | 89.5 | 189.9 | 189.9 |
| cx7-2 | 2 | 280 | 190.5 | 89.5 | 189.8 | 189.8 |
| cx7-2 | 3 | 280 | 190.4 | 89.5 | 189.8 | 189.8 |
| p1-r100 | 1 | 200 | 200.0 | 0 | 200.0 | 200.0 |
| p1-r100 | 2 | 200 | 200 | 0 | 200 | 200.0 |
| p1-r100 | 3 | 200 | 200.0 | 0 | 200.0 | 200.0 |
| p1-r140 | 1 | 280 | 224.4 | 55.5 | 224.4 | 224.4 |
| p1-r140 | 2 | 280 | 224.3 | 55.7 | 224.3 | 224.3 |
| p1-r140 | 3 | 280 | 224.3 | 55.7 | 224.3 | 224.3 |
| p1-64 | 1 | 560 | 226.4 | 333.6 | 226.4 | 226.4 |
| p1-64 | 2 | 560 | 226.4 | 333.6 | 226.4 | 226.4 |
| p1-64 | 3 | 560 | 226.4 | 333.6 | 226.4 | 226.4 |
