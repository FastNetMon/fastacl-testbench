# FastACL hardware bench: epyc-sd, platform suite

**CALIBRATION RUN (no verdict)**: 0 checks passed, 0 failed, 14 recorded measurements. 2026-10-29 08:19 UTC.

| | |
|---|---|
| Topology | server1 (TRex): ConnectX-7 #1 and #2 at 200G through a MikroTik switch into ConnectX-8 port 1 (400G optics), BlueField-3 port 0 (NIC mode, PCIe Gen4) by DAC into ConnectX-8 port 0 (400G); the ConnectX-8 runs socket direct, two PCIe Gen5 x16 functions per port, and each generator port alternates between the two functions of its DUT port; every DUT port is an ingress and drops everything |
| DUT CPU | AMD EPYC 9534 64-Core Processor (128 CPUs), memory 12 x 4800 MT/s |
| DUT kernel | 6.8.0-147-generic, IOMMU iommu=pt |
| DUT NUMA | 4 node(s) (BIOS NUMA nodes per socket) |
| DUT ports | sd-p1a (26 queues), sd-p1b (26 queues), sd-p0a (5 queues), sd-p0b (5 queues) |
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
| p1-1500 | both ConnectX-7 into ConnectX-8 port 1 | 1500 B | line rate | 3 | 52 | 32.9 | 32.9 | 0 | 32.9 | 32.9 | 399.6 | 399.7 |
| p0-1500 | BlueField-3 into ConnectX-8 port 0 | 1500 B | line rate | 3 | 10 | 16.4 | 16.4 | 0 | 16.4 | 16.4 | 199.9 | 199.9 |
| both-1500 | both ConnectX-7 and the BlueField-3 into both ConnectX-8 ports | 1500 B | line rate | 3 | 62 | 33.7 | 33.7 | 0 | 33.7 | 33.7 | 409.8 | 409.4 |
| both-64 | both ConnectX-7 and the BlueField-3 into both ConnectX-8 ports | 64 B | line rate | 3 | 62 | 729.5 | 229.3 | 500.2 | 146.5 | 146.5 | 490.2 | 98.5 |

## Per port (median trial)

| stage | DUT port | VPP workers | sent | NIC received | NIC dropped | VPP received | VPP received Gbps |
|---|---|---|---|---|---|---|---|
| p1-1500 | sd-p1a | 26 | 16.4 | 16.4 | 0 | 16.4 | 199.8 |
| p1-1500 | sd-p1b | 26 | 16.4 | 16.4 | 0 | 16.4 | 199.8 |
| p0-1500 | sd-p0a | 5 | 8.22 | 8.22 | 0 | 8.22 | 100 |
| p0-1500 | sd-p0b | 5 | 8.22 | 8.22 | 0 | 8.22 | 100 |
| both-1500 | sd-p1a | 26 | 11.2 | 11.2 | 0 | 11.2 | 135.8 |
| both-1500 | sd-p1b | 26 | 11.2 | 11.2 | 0 | 11.2 | 135.8 |
| both-1500 | sd-p0a | 5 | 5.67 | 5.66 | 0 | 5.66 | 68.8 |
| both-1500 | sd-p0b | 5 | 5.67 | 5.66 | 0 | 5.66 | 68.8 |
| both-64 | sd-p1a | 26 | 240.6 | 57.4 | 366.6 | 57.4 | 38.6 |
| both-64 | sd-p1b | 26 | 240.6 | 57.2 | 0 | 57.3 | 38.5 |
| both-64 | sd-p0a | 5 | 124.1 | 57.0 | 133.6 | 16.4 | 11 |
| both-64 | sd-p0b | 5 | 124.1 | 57.6 | 0 | 15.5 | 10.4 |

## All trials (Mpps)

| stage | trial | sent | NIC received | NIC dropped | VPP received | VPP dropped |
|---|---|---|---|---|---|---|
| p1-1500 | 1 | 32.9 | 32.9 | 0 | 32.9 | 32.9 |
| p1-1500 | 2 | 32.9 | 32.9 | 0 | 32.9 | 32.9 |
| p1-1500 | 3 | 32.8 | 32.8 | 0 | 32.9 | 32.9 |
| p0-1500 | 1 | 16.4 | 16.4 | 0 | 16.4 | 16.4 |
| p0-1500 | 2 | 16.4 | 16.4 | 0 | 16.4 | 16.4 |
| p0-1500 | 3 | 16.4 | 16.4 | 0 | 16.4 | 16.4 |
| both-1500 | 1 | 33.6 | 33.6 | 0 | 33.6 | 33.6 |
| both-1500 | 2 | 33.8 | 33.8 | 0 | 33.8 | 33.8 |
| both-1500 | 3 | 33.7 | 33.7 | 0 | 33.7 | 33.7 |
| both-64 | 1 | 729.5 | 229.3 | 500.2 | 146.5 | 146.5 |
| both-64 | 2 | 729.1 | 229.3 | 499.9 | 146.7 | 146.8 |
| both-64 | 3 | 729.8 | 229.3 | 500.5 | 146.4 | 146.4 |
