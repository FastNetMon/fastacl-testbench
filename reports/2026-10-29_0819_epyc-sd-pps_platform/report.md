# FastACL hardware bench: epyc-sd-pps, platform suite

**CALIBRATION RUN (no verdict)**: 0 checks passed, 0 failed, 17 recorded measurements. 2026-10-29 08:00 UTC.

| | |
|---|---|
| Topology | server1 (TRex, six ports) cabled port to port to epyc-sd-pps, no switch; every DUT port is an ingress and drops everything |
| DUT CPU | AMD EPYC 9534 64-Core Processor (128 CPUs), memory 12 x 4800 MT/s |
| DUT kernel | 6.8.0-147-generic, IOMMU iommu=pt |
| DUT NUMA | 4 node(s) (BIOS NUMA nodes per socket) |
| DUT ports | sd-p1a (31 queues), sd-p1b (31 queues) |
| VPP | 62 worker threads, one receive queue each, 524288 buffers per NUMA node |
| Generator | AMD EPYC 7742 64-Core Processor (128 CPUs), TRex ghcr.io/garyachy/fastacl-testbench-trex:27e0153b |
| FastACL | release latest-main, 5 drop rules (`5rules-drop`) |
| Testbench | 1de54d7 |
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
| cx7-1 | ConnectX-7 #1 alone | 64 B | line rate | 3 | 31 | 280 | 211.3 | 68.7 | 210.0 | 210 | 188.2 | 141.1 |
| cx7-2 | ConnectX-7 #2 alone | 64 B | line rate | 3 | 31 | 280 | 214.3 | 65.7 | 212.3 | 212.3 | 188.2 | 142.7 |
| p1-r100 | both ConnectX-7 into ConnectX-8 port 1 | 64 B | 100 Mpps | 3 | 62 | 200 | 200 | 0 | 163.9 | 163.9 | 134.4 | 110.1 |
| p1-r140 | both ConnectX-7 into ConnectX-8 port 1 | 64 B | 140 Mpps | 3 | 62 | 280 | 228.6 | 51.4 | 168.7 | 168.7 | 188.2 | 113.4 |
| p1-64 | both ConnectX-7 into ConnectX-8 port 1 | 64 B | line rate | 3 | 62 | 560 | 229.7 | 330.2 | 168.4 | 168.4 | 376.3 | 113.2 |

## Per port (median trial)

| stage | DUT port | VPP workers | sent | NIC received | NIC dropped | VPP received | VPP received Gbps |
|---|---|---|---|---|---|---|---|
| cx7-1 | sd-p1a | 31 | 280 | 211.3 | 68.7 | 210.0 | 141.1 |
| cx7-2 | sd-p1b | 31 | 280 | 214.3 | 65.7 | 212.3 | 142.7 |
| p1-r100 | sd-p1a | 31 | 100 | 100 | 0 | 91.9 | 61.7 |
| p1-r100 | sd-p1b | 31 | 100 | 100 | 0 | 72.0 | 48.4 |
| p1-r140 | sd-p1a | 31 | 140 | 116.2 | 51.4 | 97.9 | 65.8 |
| p1-r140 | sd-p1b | 31 | 140 | 112.5 | 0 | 70.8 | 47.6 |
| p1-64 | sd-p1a | 31 | 280 | 114.9 | 330.2 | 97.9 | 65.8 |
| p1-64 | sd-p1b | 31 | 280 | 114.9 | 0 | 70.5 | 47.4 |

## All trials (Mpps)

| stage | trial | sent | NIC received | NIC dropped | VPP received | VPP dropped |
|---|---|---|---|---|---|---|
| cx7-1 | 1 | 280 | 211.3 | 68.7 | 210.0 | 210 |
| cx7-1 | 2 | 280 | 211.4 | 68.6 | 210.0 | 210.0 |
| cx7-1 | 3 | 280 | 211.3 | 68.7 | 210.0 | 210.0 |
| cx7-2 | 1 | 280 | 214.3 | 65.7 | 212.3 | 212.3 |
| cx7-2 | 2 | 280 | 214.2 | 65.8 | 212.2 | 212.2 |
| cx7-2 | 3 | 280 | 214.3 | 65.7 | 212.3 | 212.3 |
| p1-r100 | 1 | 200 | 199.9 | 0.14 | 163.7 | 163.7 |
| p1-r100 | 2 | 200 | 200 | 0 | 163.9 | 163.9 |
| p1-r100 | 3 | 200 | 200 | 0 | 164.4 | 164.4 |
| p1-r140 | 1 | 280 | 228.7 | 51.3 | 167.9 | 167.9 |
| p1-r140 | 2 | 280 | 228.8 | 51.2 | 168.8 | 168.8 |
| p1-r140 | 3 | 280 | 228.6 | 51.4 | 168.7 | 168.7 |
| p1-64 | 1 | 560 | 229.8 | 330.2 | 168.4 | 168.4 |
| p1-64 | 2 | 560 | 229.7 | 330.2 | 168.4 | 168.4 |
| p1-64 | 3 | 560 | 229.9 | 330.1 | 169.1 | 169.1 |
