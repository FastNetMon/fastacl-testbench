# FastACL hardware bench: epyc-platform, platform suite

**CALIBRATION RUN (no verdict)**: 0 checks passed, 0 failed, 23 recorded measurements. 2026-10-09 13:13 UTC.

| | |
|---|---|
| Topology | server1 (TRex, six ports) cabled port to port to epyc-platform, no switch; every DUT port is an ingress and drops everything |
| DUT CPU | AMD EPYC 9534 64-Core Processor (128 CPUs), memory 12 x 4800 MT/s |
| DUT kernel | 6.8.0-142-generic, IOMMU iommu=pt |
| DUT NUMA | 4 node(s) (BIOS NUMA nodes per socket) |
| DUT ports | cx8a-p1 (16 queues), cx8b-p1 (16 queues), cx8b-p0 (8 queues), cx8a-p0 (8 queues), bf3-p0 (7 queues), bf3-p1 (7 queues) |
| VPP | 62 worker threads, one receive queue each, 524288 buffers per NUMA node |
| Generator | AMD EPYC 7742 64-Core Processor (128 CPUs), TRex ghcr.io/garyachy/fastacl-testbench-trex:27e0153b |
| FastACL | release latest-main, 5 drop rules (`5rules-drop`) |
| Testbench | 17cab92 |
| Run | local |

## Method

- The generator sends 64 B UDP frames (64 B including the FCS, 84 B on the wire) at the line rate of every port in the stage; each stage adds generator cards. The destination port matches the drop rules, so FastACL drops every packet VPP receives.
- The source address increments over 65,536 values so RSS spreads the load over the queues.
- **sent** is the generator's `tx_packets_phy`; **NIC received** is the DUT's `rx_packets_phy`; **NIC dropped** is `rx_discards_phy + rx_out_of_buffer`; **VPP received** is the interface receive counter; **VPP dropped** is FastACL's aggregate drop counter. Packets the NIC received but VPP did not take (ring full, `rx_prio0_buf_discard`) are the gap between NIC received and VPP received.
- Each stage runs several trials; the summary shows the trial with the median VPP drop rate.
- Rates are in Mpps; **Gbps** columns are the rate on the wire, (frame + 20 B) x 8 bits per packet, so at 64 B 1 Mpps is 0.672 Gbps and 148.8 Mpps fill 100 Gbps. **VPP workers** counts the receive queues of the stage's ports: each queue is one worker on its own physical core.

## Summary (median trial)

| stage | generator | trials | VPP workers | sent | NIC received | NIC dropped | VPP received | VPP dropped | sent Gbps | VPP dropped Gbps |
|---|---|---|---|---|---|---|---|---|---|---|
| cx7-1 | ConnectX-7 #1 alone | 3 | 16 | 264.3 | 262.5 | 0 | 147.9 | 148.0 | 177.6 | 99.4 |
| cx7-2 | ConnectX-7 #2 alone | 3 | 16 | 267.8 | 258.9 | 0 | 144.2 | 144.2 | 180 | 96.9 |
| cx5-1 | ConnectX-5 #1 alone (both ports) | 3 | 16 | 199.7 | 195.7 | 0 | 159.3 | 159.3 | 134.2 | 107.1 |
| cx5-23 | ConnectX-5 #2 and #3 alone | 3 | 14 | 297.6 | 290.9 | 45.7 | 107.8 | 107.8 | 200 | 72.5 |
| cx7x2 | both ConnectX-7 | 3 | 32 | 446.6 | 430.0 | 0 | 296.9 | 296.9 | 300.1 | 199.5 |
| cx7x2+cx5-1 | both ConnectX-7 + ConnectX-5 #1 | 3 | 48 | 632.3 | 609.2 | 0.03 | 406.4 | 406.4 | 424.9 | 273.1 |
| all | all six ports | 3 | 62 | 892.7 | 870.5 | 46.5 | 450.3 | 450.4 | 599.9 | 302.7 |

## Per port (median trial)

| stage | DUT port | VPP workers | sent | NIC received | NIC dropped | VPP received | VPP received Gbps |
|---|---|---|---|---|---|---|---|
| cx7-1 | cx8a-p1 | 16 | 264.3 | 262.5 | 0 | 147.9 | 99.4 |
| cx7-2 | cx8b-p1 | 16 | 267.8 | 258.9 | 0 | 144.2 | 96.9 |
| cx5-1 | cx8b-p0 | 8 | 99.9 | 97.8 | 0 | 79.7 | 53.6 |
| cx5-1 | cx8a-p0 | 8 | 99.8 | 97.8 | 0 | 79.6 | 53.5 |
| cx5-23 | bf3-p0 | 7 | 148.8 | 145.5 | 22.9 | 53.9 | 36.2 |
| cx5-23 | bf3-p1 | 7 | 148.8 | 145.4 | 22.9 | 53.9 | 36.2 |
| cx7x2 | cx8a-p1 | 16 | 223.3 | 215.0 | 0 | 148.9 | 100.1 |
| cx7x2 | cx8b-p1 | 16 | 223.3 | 215.0 | 0 | 148.0 | 99.4 |
| cx7x2+cx5-1 | cx8a-p1 | 16 | 216.3 | 208.5 | 0.02 | 137.9 | 92.7 |
| cx7x2+cx5-1 | cx8b-p1 | 16 | 216.3 | 208.4 | 0.01 | 137.5 | 92.4 |
| cx7x2+cx5-1 | cx8b-p0 | 8 | 99.8 | 96.2 | 0 | 65.6 | 44.1 |
| cx7x2+cx5-1 | cx8a-p0 | 8 | 99.8 | 96.2 | 0 | 65.4 | 44 |
| all | cx8a-p1 | 16 | 198.2 | 193.4 | 0 | 142.5 | 95.8 |
| all | cx8b-p1 | 16 | 198.2 | 193.4 | 0.01 | 101.0 | 67.9 |
| all | cx8b-p0 | 8 | 99.8 | 97.4 | 0 | 53.2 | 35.7 |
| all | cx8a-p0 | 8 | 99.8 | 97.3 | 0 | 67.6 | 45.4 |
| all | bf3-p0 | 7 | 148.3 | 144.5 | 23.2 | 43.0 | 28.9 |
| all | bf3-p1 | 7 | 148.3 | 144.4 | 23.2 | 43.0 | 28.9 |

## All trials (Mpps)

| stage | trial | sent | NIC received | NIC dropped | VPP received | VPP dropped |
|---|---|---|---|---|---|---|
| cx7-1 | 1 | 250.8 | 234.6 | 0 | 127.8 | 127.8 |
| cx7-1 | 2 | 264.3 | 262.5 | 0 | 147.9 | 148.0 |
| cx7-1 | 3 | 264.2 | 259.5 | 0 | 149.3 | 149.4 |
| cx7-2 | 1 | 266.8 | 257.8 | 0 | 139.8 | 139.8 |
| cx7-2 | 2 | 267.8 | 258.9 | 0 | 144.2 | 144.2 |
| cx7-2 | 3 | 267.6 | 262.1 | 0 | 149.5 | 149.5 |
| cx5-1 | 1 | 199.7 | 199.7 | 0 | 162.0 | 162.0 |
| cx5-1 | 2 | 199.7 | 195.7 | 0 | 159.3 | 159.3 |
| cx5-1 | 3 | 199.7 | 193.2 | 0 | 159.1 | 159.1 |
| cx5-23 | 1 | 297.6 | 284.7 | 44.8 | 105.4 | 105.4 |
| cx5-23 | 2 | 297.6 | 290.9 | 45.7 | 107.8 | 107.8 |
| cx5-23 | 3 | 297.6 | 292 | 45.9 | 108.2 | 108.2 |
| cx7x2 | 1 | 445.2 | 432.5 | 0 | 298.3 | 298.3 |
| cx7x2 | 2 | 447.0 | 427.3 | 0 | 293.9 | 293.9 |
| cx7x2 | 3 | 446.6 | 430.0 | 0 | 296.9 | 296.9 |
| cx7x2+cx5-1 | 1 | 631.3 | 616.5 | 0.02 | 409.3 | 409.4 |
| cx7x2+cx5-1 | 2 | 631.6 | 600.1 | 0.02 | 399.1 | 399.1 |
| cx7x2+cx5-1 | 3 | 632.3 | 609.2 | 0.03 | 406.4 | 406.4 |
| all | 1 | 892.7 | 870.5 | 46.5 | 450.3 | 450.4 |
| all | 2 | 893.0 | 850.7 | 45.3 | 439.3 | 439.3 |
| all | 3 | 893.1 | 893 | 47.7 | 464.1 | 464.1 |
