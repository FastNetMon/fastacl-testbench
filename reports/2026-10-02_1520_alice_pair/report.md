# FastACL hardware bench: alice, pair suite

**CALIBRATION RUN (no verdict)**: 0 checks passed, 0 failed, 20 recorded measurements. 2026-10-02 15:11 UTC.

| | |
|---|---|
| Topology | 2-node: bob and alice cabled port to port, no switch; each runs TRex |
| Hosts | AMD Ryzen 9 9950X 16-Core Processor (32 CPUs), kernel 6.8.0-146-generic |
| NIC | Mellanox Technologies CX8 Family [ConnectX-8], firmware 40.50.1002 (MT_0000001222), links 400 Gbps, PCIe Speed 32GT/s (downgraded), Width x16 |
| TRex | v3.08 (source) (ghcr.io/garyachy/fastacl-testbench-trex:27e0153b), 30 cores |
| Testbench | 2ade708 |
| Run | local |

## Method

- Each host runs TRex. One sends UDP at the highest rate it can on one port or on both, the other receives; then the roles swap.
- Frame sizes include the FCS: 64 B is 84 B on the wire with preamble and gap, and 400 GbE carries 595 Mpps of it.
- The source address increments over 65,536 values so the receiver spreads the load over its queues.
- **sent** and **received** are the NICs' `tx_packets_phy` and `rx_packets_phy` deltas over the sample window; **dropped by receiver** is `rx_discards_phy + rx_out_of_buffer` on the receiving host; **delivered** is received minus dropped.

## Generator pair ceiling: 64 B-1518 B UDP at the maximum rate, one port and both ports

| direction | ports | frame | sent Mpps | sent Gbps (L1) | received Mpps | dropped by receiver Mpps | delivered Mpps |
|---|---|---|---|---|---|---|---|
| bob -> alice | 1 | 64 B | 300 | 201.6 | 300 | 31.2 | 268.8 |
| bob -> alice | 2 | 64 B | 300 | 201.6 | 300 | 9.52 | 290.5 |
| bob -> alice | 1 | 128 B | 200 | 236.8 | 200 | 0 | 200 |
| bob -> alice | 2 | 128 B | 200.0 | 236.8 | 200 | 0 | 200 |
| bob -> alice | 1 | 256 B | 120 | 265 | 120 | 0 | 120 |
| bob -> alice | 2 | 256 B | 120 | 265 | 120 | 0 | 120 |
| bob -> alice | 1 | 512 B | 65.1 | 276.9 | 65.1 | 0 | 65.1 |
| bob -> alice | 2 | 512 B | 84.4 | 359.3 | 84.4 | 0 | 84.4 |
| bob -> alice | 1 | 1518 B | 32.2 | 396.3 | 32.2 | 0 | 32.2 |
| bob -> alice | 2 | 1518 B | 32.2 | 396.4 | 32.2 | 0 | 32.2 |
| alice -> bob | 1 | 64 B | 300 | 201.6 | 300 | 31.2 | 268.8 |
| alice -> bob | 2 | 64 B | 300 | 201.6 | 300 | 9.51 | 290.5 |
| alice -> bob | 1 | 128 B | 200.0 | 236.8 | 200.0 | 0 | 200.0 |
| alice -> bob | 2 | 128 B | 200 | 236.8 | 200 | 0 | 200 |
| alice -> bob | 1 | 256 B | 119.9 | 264.8 | 119.9 | 0 | 119.9 |
| alice -> bob | 2 | 256 B | 120.0 | 264.9 | 120.0 | 0 | 120.0 |
| alice -> bob | 1 | 512 B | 64.7 | 275.3 | 64.7 | 0 | 64.7 |
| alice -> bob | 2 | 512 B | 85.9 | 365.4 | 85.9 | 0 | 85.9 |
| alice -> bob | 1 | 1518 B | 31.1 | 383.3 | 31.2 | 0 | 31.2 |
| alice -> bob | 2 | 1518 B | 33.4 | 410.6 | 33.4 | 0 | 33.4 |

## Scenarios and traffic in this run

| traffic | profile |
|---|---|
