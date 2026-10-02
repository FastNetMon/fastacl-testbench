# FastACL hardware bench: bluefield3, bng suite

**PASS**: 0 checks passed, 0 failed, 15 recorded measurements. 2026-10-02 08:35 UTC.

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
| Testbench | 570693c |
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
| routed | routed | 10000 | 10 |  | 64 B | 83.3 | 85.8 |  | 41.1 |  |  | 44.7 | default | 12 |
| routed | routed | 10000 | 10 |  | IMIX 7:4:1 | 32.9 | 32.9 |  | 0 |  |  | 100.9 | default | 12 |
| policer | policer | 10000 | 10 |  | 64 B | 30.1 | 30.1 |  | 78.8 | 83 |  | 131.2 | default | 12 |
| policer | policer | 10000 | 10 |  | IMIX 7:4:1 | 21.1 | 21.1 |  | 35.8 | 114.6 |  | 186.6 | default | 12 |
| nat | nat | 10000 | 10 | 100000 | 64 B | 19.6 | 19.7 |  | 86.2 |  | 124.5 | 199.2 | default | 12 |
| nat | nat | 10000 | 10 | 100000 | IMIX 7:4:1 | 16.3 | 16.3 |  | 50.5 |  | 150.1 | 241.4 | default | 12 |
| bng | bng | 10000 | 10 | 100000 | 64 B | 12.9 | 12.9 |  | 90.9 | 96.5 | 129.6 | 303.7 | default | 12 |
| bng | bng | 10000 | 10 | 100000 | IMIX 7:4:1 | 11.4 | 11.4 |  | 65.4 | 109.4 | 147.5 | 344.5 | default | 12 |
| bng sessions | bng | 10000 | 1 | 10000 | 64 B | 12.9 | 12.9 |  | 90.9 | 96.4 | 129.5 | 303.3 | default | 12 |
| bng sessions | bng | 100000 | 10 | 1000000 | 64 B | 12.9 | 12.9 |  | 90.9 | 96.6 | 129.7 | 304.1 | default | 12 |
| policer accuracy | bng | 100 | 1 | 100 | 64 B | 16.7 | 16.7 | 2.5 | 88.2 | 33.8 | 128.1 | 235.1 | default | 12 |
| policer accuracy | bng | 100 | 1 | 100 | 64 B | 16.6 | 16.6 | 5 | 88.3 | 33.9 | 128.1 | 236.2 | default | 12 |
| rss default | routed | 1 | 1000 |  | 64 B | 85.9 | 85.8 |  | 39.5 |  |  | 44.6 | default | 12 |
| rss ipv4-udp | routed | 1 | 1000 |  | 64 B | 85.8 | 85.9 |  | 39.6 |  |  | 44.6 | ipv4-udp | 12 |
| rss ipv4-udp | routed | 10000 | 10 |  | 64 B | 86.0 | 85.9 |  | 39.5 |  |  | 44.6 | ipv4-udp | 12 |

## Scenarios and traffic in this run

| traffic | profile |
|---|---|
