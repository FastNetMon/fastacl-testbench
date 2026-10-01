# FastACL hardware bench: bluefield3, full suite

**PASS**: 3 checks passed, 0 failed, 4 recorded measurements. 2026-10-01 12:43 UTC.

| | |
|---|---|
| Topology | 2-node: lava (TRex) cabled back to back to bluefield3, no switch |
| DUT CPU | BlueField-3 Arm Cortex-A78AE (16 CPUs) |
| DUT NIC | Mellanox Technologies MT43244 BlueField-3 integrated ConnectX-7 network controller (rev 01), link 100 Gbps |
| DUT kernel | 5.15.0-1093-bluefield |
| DUT software | DOCA 3.4.0112, bf-release 4.15.0, NIC firmware 32.49.1014 |
| Generator | AMD Ryzen 9 9950X 16-Core Processor (32 CPUs), Mellanox Technologies MT28800 Family [ConnectX-5 Ex], TRex 3.06 |
| VPP | v25.10-release, 12 worker threads, RX/TX ring 4096/4096 |
| FastACL | 0.6.1 from release v0.6.1, licence evaluation (30-day maximum) (expires 2026-10-30) |
| Testbench | 5f313a4-dirty |
| Run | local |

## Summary

### Packet size (BlueField-3 Arm, 1 × 100G ingress, drop)

| frame | rules | drop Mpps | drop Gbps (wire) | floor Mpps | verdict |
|---|---|---|---|---|---|
| 64 B | 1 | 59.2 | 41.7 | 45 | PASS |
| 128 B | 1 | 52.1 | 63.4 |  | INFO |
| 256 B | 1 | 44.2 | 99.0 |  | INFO |
| 512 B | 1 | 23.3 | 99.9 |  | INFO |
| 1024 B | 1 | 12 | 100.6 |  | INFO |
| 1500 B | 1 | 8.2 | 100.0 | 7 | PASS |
| IMIX 7:4:1 | 1 | 32.8 | 99.1 | 28 | PASS |

## Method

- Frames are sized before FCS: 64 B means 68 B on the wire, so 100 % of 100 GbE is 142.05 Mpps.
- 64 B traffic is offered at 142 Mpps and larger frames at 100 Gbps.
- **absorbed Mpps**: packets the DUT received and processed per second (dropped by a rule or forwarded), from counter deltas over the sample window.
- **NIC loss %**: packets that reached the DUT port but never reached VPP (`rx_phy - rx_good`), i.e. lost inside the adapter.
- **cycles/pkt**: CPU cycles the `fastacl-filter` node spends per packet (`show runtime`).
- A gate passes when every value is within its limit; survey and ceiling rows are recorded without a verdict.
- Trials: dpu 4 s warm-up, 15 s sample.
- Full methodology: [test strategy](https://github.com/FastNetMon/fastacl-testbench/blob/main/docs/test-strategy.md).

## BlueField-3 Arm drop line rate

| test | absorbed Mpps | min | max | trials | ticks/pkt | floor Mpps | verdict |
|---|---|---|---|---|---|---|---|
| udp drop 64 | 59.2 | 59 | 59.4 | 3 | 15.4 | 45 | PASS |
| udp drop 128 | 52.1 | 52.1 | 52.1 | 3 | 15.8 |  | INFO |
| udp drop 256 | 44.2 | 44.1 | 44.2 | 3 | 15.2 |  | INFO |
| udp drop 512 | 23.3 | 23.2 | 23.4 | 3 | 15.5 |  | INFO |
| udp drop 1024 | 12 | 12 | 12 | 3 | 16.1 |  | INFO |
| udp drop 1500 | 8.2 | 8.2 | 8.2 | 3 | 16.6 | 7 | PASS |
| udp drop imix | 32.8 | 32.8 | 33 | 3 | 15.3 | 28 | PASS |

## Scenarios and traffic in this run

| traffic | profile |
|---|---|
| `cold-scan-imix` | cold-scan with IMIX frames (IMIX 64/570/1518 B, 7:4:1) |
| `udp-rand` | UDP flood, random source and ports (64 B) |
