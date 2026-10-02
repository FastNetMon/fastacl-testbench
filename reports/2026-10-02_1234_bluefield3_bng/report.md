# FastACL hardware bench: bluefield3, bng suite

**PASS**: 0 checks passed, 0 failed, 16 recorded measurements. 2026-10-02 11:01 UTC.

| | |
|---|---|
| Topology | 2-node: lava (TRex) cabled back to back to bluefield3, no switch |
| DUT CPU | BlueField-3 Arm Cortex-A78AE (16 CPUs) |
| DUT NIC | Mellanox Technologies MT43244 BlueField-3 integrated ConnectX-7 network controller (rev 01), link 100 Gbps |
| DUT kernel | 5.15.0-1093-bluefield |
| DUT software | DOCA 3.4.0112, bf-release 4.15.0, NIC firmware 32.49.1014 |
| NIC driver | rdma dv |
| Generator | AMD Ryzen 9 9950X 16-Core Processor (32 CPUs), Mellanox Technologies MT28800 Family [ConnectX-5 Ex], TRex 3.06 |
| VPP | v26.10-rc1~0-g28e8c47f7, 12 worker threads, RX/TX ring 4096/4096 |
| FastACL | 0.6.1 from release local:fastacl-v0.6.1-vpp2610rc1-arm64.tar.gz, licence evaluation (30-day maximum) (expires 2026-10-30) |
| Testbench | 8cdfab6 |
| Run | local |

## Method

- Frames are sized before FCS: 64 B means 68 B on the wire, so 100 % of 100 GbE is 142.05 Mpps.
- 64 B traffic is offered at 142 Mpps and larger frames at 100 Gbps.
- **absorbed Mpps**: packets the DUT received and processed per second (dropped by a rule or forwarded), from counter deltas over the sample window.
- **NIC loss %**: packets that reached the DUT port but never reached VPP (`rx_phy - rx_good`), i.e. lost inside the adapter.
- **cycles/pkt**: CPU cycles the `fastacl-filter` node spends per packet (`show runtime`).
- A gate passes when every value is within its limit; survey and ceiling rows are recorded without a verdict.
- Trials: .
- Full methodology: [test strategy](https://github.com/FastNetMon/fastacl-testbench/blob/main/docs/test-strategy.md).

## BNG pipeline on the BlueField-3 Arm (routed, per-subscriber policer, NAT44-ED)

| test | pipeline | subscribers | ports each | NAT sessions | frame | received Mpps | forwarded Mpps | expected Mpps | NIC loss % | filter ticks/pkt | NAT ticks/pkt | pipeline ticks/pkt | RSS hash | workers receiving |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| routed | routed | 10000 | 10 |  | 64 B | 85.9 | 85.9 |  | 39.5 |  |  | 44.6 | default | 12 |
| routed | routed | 10000 | 10 |  | IMIX 7:4:1 | 33.3 | 33.0 |  | 0 |  |  | 100.6 | default | 12 |
| policer | policer | 10000 | 10 |  | 64 B | 26.1 | 26.0 |  | 81.6 | 97.6 |  | 151.7 | default | 12 |
| policer | policer | 10000 | 10 |  | IMIX 7:4:1 | 19.5 | 19.4 |  | 40.9 | 129.8 |  | 203.2 | default | 12 |
| nat | nat | 10000 | 10 | 100000 | 64 B | 16.4 | 16.2 |  | 88.4 |  | 163.5 | 241.4 | default | 12 |
| nat | nat | 10000 | 10 | 100000 | IMIX 7:4:1 | 13.9 | 13.7 |  | 57.8 |  | 195.3 | 285.1 | default | 12 |
| bng | bng | 10000 | 10 | 100000 | 64 B | 10.9 | 11.2 |  | 92.3 | 105.4 | 162.9 | 351.2 | default | 12 |
| bng | bng | 10000 | 10 | 100000 | IMIX 7:4:1 | 9.92 | 9.91 |  | 70.0 | 119.7 | 185.3 | 395.9 | default | 12 |
| bng sessions | bng | 10000 | 1 | 10000 | 64 B | 13.6 | 12.6 |  | 90.6 | 96.5 | 135.1 | 309.8 | default | 12 |
| bng sessions | bng | 10000 | 100 | 1000000 | 64 B | 10.6 | 10.6 |  | 92.5 | 107.5 | 176 | 369.1 | default | 12 |
| bng sessions | bng | 100000 | 10 | 1000000 | 64 B | 9.72 | 9.73 |  | 93.2 | 125.7 | 190 | 403 | default | 12 |
| policer accuracy | bng | 100 | 1 | 100 | 64 B | 74.2 | 2.5 | 2.5 | 47.7 | 19.7 | 5.7 | 51.3 | default | 12 |
| policer accuracy | bng | 100 | 1 | 100 | 64 B | 69.4 | 5 | 5 | 51.1 | 19.9 | 8.5 | 55.1 | default | 12 |
| rss default | routed | 1 | 1000 |  | 64 B | 85.9 | 85.9 |  | 39.5 |  |  | 44.6 | default | 12 |
| rss ipv4-udp | routed | 1 | 1000 |  | 64 B | 86.1 | 85.9 |  | 39.3 |  |  | 44.7 | ipv4-udp | 12 |
| rss ipv4-udp | routed | 10000 | 10 |  | 64 B | 85.8 | 85.8 |  | 39.6 |  |  | 44.6 | ipv4-udp | 12 |

## Scenarios and traffic in this run

| traffic | profile |
|---|---|
