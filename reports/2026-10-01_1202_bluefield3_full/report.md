# FastACL hardware bench: bluefield3, full suite

**PASS**: 3 checks passed, 0 failed, 4 recorded measurements. 2026-10-01 11:47 UTC.

| | |
|---|---|
| Topology | 2-node: lava (TRex) cabled back to back to bluefield3, no switch |
| DUT CPU | BlueField-3 Arm Cortex-A78AE (16 CPUs) |
| DUT NIC | Mellanox Technologies MT43244 BlueField-3 integrated ConnectX-7 network controller (rev 01), link 100 Gbps |
| DUT kernel | 5.15.0-1057-bluefield |
| DUT software | bf-bundle-2.9.1-50_24.11_ubuntu-22.04_prod |
| Generator | AMD Ryzen 9 9950X 16-Core Processor (32 CPUs), Mellanox Technologies MT28800 Family [ConnectX-5 Ex], TRex 3.06 |
| VPP | v26.06-release, 12 worker threads, RX/TX ring 4096/4096 |
| FastACL | 0.6.1 from release v0.6.1, licence evaluation (30-day maximum) (expires 2026-10-30) |
| Testbench | 5f313a4 |
| Run | local |

## Summary

### Packet size (BlueField-3 Arm, 1 × 100G ingress, drop)

| frame | rules | drop Mpps | drop Gbps (wire) | floor Mpps | verdict |
|---|---|---|---|---|---|
| 64 B | 1 | 55.4 | 39.0 | 45 | PASS |
| 128 B | 1 | 48.5 | 59.0 |  | INFO |
| 256 B | 1 | 44.2 | 99.0 |  | INFO |
| 512 B | 1 | 23.3 | 99.9 |  | INFO |
| 1024 B | 1 | 11.9 | 99.8 |  | INFO |
| 1500 B | 1 | 8.2 | 100.0 | 7 | PASS |
| IMIX 7:4:1 | 1 | 32.9 | 99.4 | 28 | PASS |

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
| udp drop 64 | 55.4 | 55.3 | 55.6 | 3 | 15.6 | 45 | PASS |
| udp drop 128 | 48.5 | 48.5 | 48.5 | 3 | 16.2 |  | INFO |
| udp drop 256 | 44.2 | 44.1 | 44.2 | 3 | 15.3 |  | INFO |
| udp drop 512 | 23.3 | 23.2 | 23.4 | 3 | 15.6 |  | INFO |
| udp drop 1024 | 11.9 | 11.9 | 12 | 3 | 16.2 |  | INFO |
| udp drop 1500 | 8.2 | 8.2 | 8.2 | 3 | 16.7 | 7 | PASS |
| udp drop imix | 32.9 | 32.8 | 32.9 | 3 | 15.4 | 28 | PASS |

## Scenarios and traffic in this run

| traffic | profile |
|---|---|
| `cold-scan-imix` | cold-scan with IMIX frames (IMIX 64/570/1518 B, 7:4:1) |
| `udp-rand` | UDP flood, random source and ports (64 B) |
