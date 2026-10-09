# FastACL hardware bench: epyc-platform, platform suite

**CALIBRATION RUN (no verdict)**: 0 checks passed, 0 failed, 23 recorded measurements. 2026-10-09 10:52 UTC.

| | |
|---|---|
| Topology | server1 (TRex, six ports) cabled port to port to epyc-platform, no switch; every DUT port is an ingress and drops everything |
| DUT CPU | AMD EPYC 9534 64-Core Processor (128 CPUs), memory 12 x 4800 MT/s |
| DUT kernel | 6.8.0-142-generic |
| DUT ports | cx8a-p1 (8 queues), cx8b-p1 (8 queues), cx8b-p0 (4 queues), cx8a-p0 (4 queues), bf3-p0 (4 queues), bf3-p1 (4 queues) |
| VPP | 32 worker threads, one receive queue each |
| Generator | AMD EPYC 7742 64-Core Processor (128 CPUs), TRex ghcr.io/garyachy/fastacl-testbench-trex:27e0153b |
| FastACL | release latest-main, 5 drop rules (`5rules-drop`) |
| Testbench | 15e9afc |
| Run | local |

## Method

- The generator sends 64 B UDP frames (64 B including the FCS, 84 B on the wire) at the line rate of every port in the stage; each stage adds generator cards. The destination port matches the drop rules, so FastACL drops every packet VPP receives.
- The source address increments over 65,536 values so RSS spreads the load over the queues.
- **sent** is the generator's `tx_packets_phy`; **NIC received** is the DUT's `rx_packets_phy`; **NIC dropped** is `rx_discards_phy + rx_out_of_buffer`; **VPP received** is the interface receive counter; **VPP dropped** is FastACL's aggregate drop counter. Packets the NIC received but VPP did not take (ring full, `rx_prio0_buf_discard`) are the gap between NIC received and VPP received.
- Each stage runs several trials; the summary shows the trial with the median VPP drop rate.

## Summary (Mpps, median trial)

| stage | generator | trials | sent | NIC received | NIC dropped | VPP received | VPP dropped |
|---|---|---|---|---|---|---|---|
| cx7-1 | ConnectX-7 #1 alone | 3 | 257.2 | 250.8 | 0 | 102.4 | 102.5 |
| cx7-2 | ConnectX-7 #2 alone | 3 | 262.2 | 253.0 | 0 | 101.3 | 101.3 |
| cx5-1 | ConnectX-5 #1 alone (both ports) | 3 | 199.7 | 197.7 | 0 | 104.2 | 104.2 |
| cx5-23 | ConnectX-5 #2 and #3 alone | 3 | 297.6 | 294.0 | 45.0 | 98.4 | 98.4 |
| cx7x2 | both ConnectX-7 | 3 | 443.6 | 434.4 | 0 | 200.6 | 200.6 |
| cx7x2+cx5-1 | both ConnectX-7 + ConnectX-5 #1 | 3 | 630.4 | 620.8 | 0.01 | 290.7 | 290.7 |
| all | all six ports | 3 | 889.8 | 875.2 | 44.8 | 355.2 | 355.2 |

## Per port (Mpps, median trial)

| stage | DUT port | sent | NIC received | NIC dropped | VPP received |
|---|---|---|---|---|---|
| cx7-1 | cx8a-p1 | 257.2 | 250.8 | 0 | 102.4 |
| cx7-2 | cx8b-p1 | 262.2 | 253.0 | 0 | 101.3 |
| cx5-1 | cx8b-p0 | 99.9 | 98.9 | 0 | 53.3 |
| cx5-1 | cx8a-p0 | 99.8 | 98.9 | 0 | 50.9 |
| cx5-23 | bf3-p0 | 148.8 | 147.0 | 22.5 | 49.2 |
| cx5-23 | bf3-p1 | 148.8 | 147.0 | 22.5 | 49.2 |
| cx7x2 | cx8a-p1 | 221.8 | 217.2 | 0 | 100.5 |
| cx7x2 | cx8b-p1 | 221.8 | 217.2 | 0 | 100.1 |
| cx7x2+cx5-1 | cx8a-p1 | 215.3 | 212.1 | 0 | 97.3 |
| cx7x2+cx5-1 | cx8b-p1 | 215.3 | 212.1 | 0.01 | 96.6 |
| cx7x2+cx5-1 | cx8b-p0 | 99.8 | 98.3 | 0 | 48.8 |
| cx7x2+cx5-1 | cx8a-p0 | 99.8 | 98.3 | 0 | 48.0 |
| all | cx8a-p1 | 196.8 | 193.7 | 0 | 89.8 |
| all | cx8b-p1 | 196.8 | 193.7 | 0.01 | 89.4 |
| all | cx8b-p0 | 99.9 | 98.2 | 0 | 45.1 |
| all | cx8a-p0 | 99.9 | 98.2 | 0 | 44.5 |
| all | bf3-p0 | 148.2 | 145.7 | 22.2 | 43.6 |
| all | bf3-p1 | 148.2 | 145.7 | 22.6 | 42.9 |

## All trials (Mpps)

| stage | trial | sent | NIC received | NIC dropped | VPP received | VPP dropped |
|---|---|---|---|---|---|---|
| cx7-1 | 1 | 256.8 | 248.0 | 0 | 100.8 | 100.8 |
| cx7-1 | 2 | 257.2 | 250.8 | 0 | 102.4 | 102.5 |
| cx7-1 | 3 | 257.8 | 253.3 | 0 | 104.5 | 104.5 |
| cx7-2 | 1 | 265.3 | 258.3 | 0 | 100.4 | 100.5 |
| cx7-2 | 2 | 263.5 | 262.4 | 0 | 103.5 | 103.5 |
| cx7-2 | 3 | 262.2 | 253.0 | 0 | 101.3 | 101.3 |
| cx5-1 | 1 | 199.7 | 197.7 | 0 | 104.2 | 104.2 |
| cx5-1 | 2 | 199.7 | 194.1 | 0 | 97.9 | 97.9 |
| cx5-1 | 3 | 199.7 | 196.8 | 0 | 104.8 | 104.8 |
| cx5-23 | 1 | 297.6 | 294.7 | 45.1 | 98.7 | 98.7 |
| cx5-23 | 2 | 297.6 | 294.0 | 45.0 | 98.4 | 98.4 |
| cx5-23 | 3 | 297.6 | 292.7 | 44.8 | 98.0 | 98.0 |
| cx7x2 | 1 | 444.2 | 430.8 | 0 | 197.8 | 197.8 |
| cx7x2 | 2 | 443.6 | 434.4 | 0 | 200.6 | 200.6 |
| cx7x2 | 3 | 445.2 | 445.2 | 0 | 207.6 | 207.6 |
| cx7x2+cx5-1 | 1 | 629.6 | 619.5 | 0 | 286.7 | 286.7 |
| cx7x2+cx5-1 | 2 | 630.4 | 620.8 | 0.01 | 290.7 | 290.7 |
| cx7x2+cx5-1 | 3 | 629.1 | 623.1 | 0.01 | 293.2 | 293.3 |
| all | 1 | 890.5 | 873.6 | 44.7 | 353.9 | 354.0 |
| all | 2 | 889.8 | 875.2 | 44.8 | 355.2 | 355.2 |
| all | 3 | 890.9 | 880.3 | 45.0 | 356.8 | 356.9 |
