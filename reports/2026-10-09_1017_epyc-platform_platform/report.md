# FastACL hardware bench: epyc-platform, platform suite

**CALIBRATION RUN (no verdict)**: 0 checks passed, 0 failed, 23 recorded measurements. 2026-10-09 10:00 UTC.

| | |
|---|---|
| Topology | server1 (TRex, six ports) cabled port to port to epyc-platform, no switch; every DUT port is an ingress and drops everything |
| DUT CPU | AMD EPYC 9534 64-Core Processor (128 CPUs), memory 12 x 4800 MT/s |
| DUT kernel | 6.8.0-142-generic |
| DUT ports | cx8a-p1 (16 queues), cx8b-p1 (16 queues), cx8b-p0 (8 queues), cx8a-p0 (8 queues), bf3-p0 (7 queues), bf3-p1 (7 queues) |
| VPP | 62 worker threads, one receive queue each |
| Generator | AMD EPYC 7742 64-Core Processor (128 CPUs), TRex ghcr.io/garyachy/fastacl-testbench-trex:27e0153b |
| FastACL | release latest-main, 5 drop rules (`5rules-drop`) |
| Testbench | 4260765 |
| Run | local |

## Method

- The generator sends 64 B UDP frames (64 B including the FCS, 84 B on the wire) at the line rate of every port in the stage; each stage adds generator cards. The destination port matches the drop rules, so FastACL drops every packet VPP receives.
- The source address increments over 65,536 values so RSS spreads the load over the queues.
- **sent** is the generator's `tx_packets_phy`; **NIC received** is the DUT's `rx_packets_phy`; **NIC dropped** is `rx_discards_phy + rx_out_of_buffer`; **VPP received** is the interface receive counter; **VPP dropped** is FastACL's aggregate drop counter. Packets the NIC received but VPP did not take (ring full, `rx_prio0_buf_discard`) are the gap between NIC received and VPP received.
- Each stage runs several trials; the summary shows the trial with the median VPP drop rate.

## Summary (Mpps, median trial)

| stage | generator | trials | sent | NIC received | NIC dropped | VPP received | VPP dropped |
|---|---|---|---|---|---|---|---|
| cx7-1 | ConnectX-7 #1 alone | 3 | 258.3 | 253.2 | 0 | 152.5 | 152.5 |
| cx7-2 | ConnectX-7 #2 alone | 3 | 264.3 | 253.3 | 0 | 149.1 | 149.1 |
| cx5-1 | ConnectX-5 #1 alone (both ports) | 3 | 199.7 | 193.6 | 0 | 161.2 | 161.2 |
| cx5-23 | ConnectX-5 #2 and #3 alone | 3 | 297.6 | 290.9 | 44.7 | 109.8 | 109.9 |
| cx7x2 | both ConnectX-7 | 3 | 447.1 | 435.0 | 0 | 293.8 | 293.8 |
| cx7x2+cx5-1 | both ConnectX-7 + ConnectX-5 #1 | 3 | 632.6 | 622.4 | 0.01 | 182.7 | 182.7 |
| all | all six ports | 3 | 893.1 | 875.1 | 47.9 | 148.0 | 148.1 |

## Per port (Mpps, median trial)

| stage | DUT port | sent | NIC received | NIC dropped | VPP received |
|---|---|---|---|---|---|
| cx7-1 | cx8a-p1 | 258.3 | 253.2 | 0 | 152.5 |
| cx7-2 | cx8b-p1 | 264.3 | 253.3 | 0 | 149.1 |
| cx5-1 | cx8b-p0 | 99.8 | 96.8 | 0 | 80.8 |
| cx5-1 | cx8a-p0 | 99.8 | 96.8 | 0 | 80.3 |
| cx5-23 | bf3-p0 | 148.8 | 145.5 | 22.3 | 54.9 |
| cx5-23 | bf3-p1 | 148.8 | 145.4 | 22.3 | 54.9 |
| cx7x2 | cx8a-p1 | 223.6 | 217.5 | 0 | 147.4 |
| cx7x2 | cx8b-p1 | 223.5 | 217.5 | 0 | 146.4 |
| cx7x2+cx5-1 | cx8a-p1 | 216.4 | 213.0 | 0 | 58.3 |
| cx7x2+cx5-1 | cx8b-p1 | 216.4 | 212.9 | 0.01 | 69.9 |
| cx7x2+cx5-1 | cx8b-p0 | 99.8 | 98.2 | 0 | 26.7 |
| cx7x2+cx5-1 | cx8a-p0 | 99.8 | 98.2 | 0 | 27.7 |
| all | cx8a-p1 | 198.4 | 194.5 | 0 | 39.9 |
| all | cx8b-p1 | 198.4 | 194.5 | 0 | 51.9 |
| all | cx8b-p0 | 99.8 | 97.8 | 0 | 16.1 |
| all | cx8a-p0 | 99.8 | 97.8 | 0 | 16.6 |
| all | bf3-p0 | 148.3 | 145.2 | 23.9 | 12.1 |
| all | bf3-p1 | 148.3 | 145.2 | 23.9 | 11.5 |

## All trials (Mpps)

| stage | trial | sent | NIC received | NIC dropped | VPP received | VPP dropped |
|---|---|---|---|---|---|---|
| cx7-1 | 1 | 259 | 253.3 | 0 | 150.2 | 150.2 |
| cx7-1 | 2 | 258.3 | 253.2 | 0 | 152.5 | 152.5 |
| cx7-1 | 3 | 258.2 | 252.4 | 0 | 155.6 | 155.6 |
| cx7-2 | 1 | 265.7 | 259.4 | 0 | 148.3 | 148.3 |
| cx7-2 | 2 | 264.3 | 253.3 | 0 | 149.1 | 149.1 |
| cx7-2 | 3 | 267.6 | 262.7 | 0 | 156.7 | 156.7 |
| cx5-1 | 1 | 199.7 | 196.7 | 0 | 164 | 164.0 |
| cx5-1 | 2 | 199.7 | 193.6 | 0 | 161.2 | 161.2 |
| cx5-1 | 3 | 199.7 | 192.0 | 0 | 160.1 | 160.1 |
| cx5-23 | 1 | 297.6 | 288.7 | 44.3 | 109.1 | 109.1 |
| cx5-23 | 2 | 297.6 | 292.6 | 44.9 | 110.4 | 110.4 |
| cx5-23 | 3 | 297.6 | 290.9 | 44.7 | 109.8 | 109.9 |
| cx7x2 | 1 | 444.2 | 427.6 | 0 | 291.2 | 291.2 |
| cx7x2 | 2 | 447.1 | 435.0 | 0 | 293.8 | 293.8 |
| cx7x2 | 3 | 443.1 | 435.7 | 0 | 296.5 | 296.5 |
| cx7x2+cx5-1 | 1 | 632.7 | 620.2 | 0.01 | 183.0 | 183.1 |
| cx7x2+cx5-1 | 2 | 631.9 | 610.6 | 0.01 | 180.0 | 180.1 |
| cx7x2+cx5-1 | 3 | 632.6 | 622.4 | 0.01 | 182.7 | 182.7 |
| all | 1 | 893.1 | 875.1 | 47.9 | 148.0 | 148.1 |
| all | 2 | 892.5 | 861.4 | 47.1 | 144.5 | 144.6 |
| all | 3 | 893.5 | 885.0 | 48.5 | 148.1 | 148.1 |
