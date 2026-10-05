# FastACL hardware bench: bob, full suite

**CALIBRATION RUN (no verdict)**: 8 checks passed, 1 failed, 6 recorded measurements. 2026-10-05 15:16 UTC.

| | |
|---|---|
| Topology | 2-node: alice (TRex) cabled back to back to bob, no switch |
| DUT CPU | AMD Ryzen 9 9950X 16-Core Processor (32 CPUs) |
| DUT NIC | Mellanox Technologies CX8 Family [ConnectX-8], link 400 Gbps |
| DUT memory | 2 x 16 GB DDR5 @ 6000 MT/s (KF560C36BBE2-16TR) |
| DUT kernel | 6.8.0-142-generic |
| DUT software | Ubuntu 24.04.4 LTS, NIC firmware 40.50.1002 |
| NIC driver | dpdk |
| Generator | AMD Ryzen 9 9950X 16-Core Processor (32 CPUs), Mellanox Technologies CX8 Family [ConnectX-8], TRex 3.06 |
| VPP | v25.10-release, 15 worker threads, RX/TX ring 4096/4096 |
| FastACL | 0.6.1 from release latest-main, licence evaluation (30-day maximum) (expires 2026-11-01) |
| Testbench | b40579f |
| Run | local |

## Method

- Frames are sized before FCS: 64 B means 68 B on the wire, so 100 % of 100 GbE is 142.05 Mpps.
- 64 B traffic is offered at 200 Mpps and larger frames at 100 Gbps; mixed-size traffic is offered at 400 Gbps (a packet rate is only a fixed bit rate when every frame is the same size).
- **absorbed Mpps**: packets the DUT received and processed per second (dropped by a rule or forwarded), from counter deltas over the sample window.
- **NIC loss %**: packets that reached the DUT port but never reached VPP (`rx_phy - rx_good`), i.e. lost inside the adapter.
- **cycles/pkt**: CPU cycles the `fastacl-filter` node spends per packet (`show runtime`).
- A gate passes when every value is within its limit; survey and ceiling rows are recorded without a verdict.
- Trials: oneport 5 s warm-up, 10 s sample; flows 20 s warm-up, 30 s sample; ceiling 5 s warm-up, 15 s sample per row.
- Full methodology: [test strategy](https://github.com/FastNetMon/fastacl-testbench/blob/main/docs/test-strategy.md).

## One-port gates (drop and forward)

| scenario | rules | traffic | frame | offered Mpps | absorbed Mpps | floor Mpps | NIC loss % | loss limit % | cycles/pkt | cycle limit | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 5rules-drop | 5 hot port-range drop rules | fixed-flood-31 | 64 B | 200 | 198.9 | 135 | 0.447 | 1 | 77.7 | 130 | PASS |
| 0rules | no rules (forwarding baseline) | fwd-flood-32 | 64 B | 142 | 141.7 | 97 | 0.434 | 1 | 47.5 | 70 | PASS |
| country-set-drop | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | fixed-flood-31 | 64 B | 200 | 199.2 | 135 | 0.439 | 1 | 78.4 | 160 | PASS |

## Prefix-set tuple count

| scenario | rules | tuples | limit | verdict |
|---|---|---|---|---|
| country-set-drop | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | 1 | 1 | PASS |

## Working-set gates (simultaneously active flows)

| scenario | rules | traffic | frame | active flows | offered Mpps | absorbed Mpps | floor Mpps | NIC loss % | loss limit % | cycles/pkt | cycle limit | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1m-rules-drop | 983,045 rules | cold-scan | 64 B | 32000 | 200 | 200 | 135 | 0.17 | 0.6 | 96 | 330 | PASS |
| 1m-rules-drop | 983,045 rules | cold-scan-scatter | 64 B | 32000 | 200 | 200 | 135 | 0.171 | 0.6 | 102 | 330 | PASS |
| 1m-rules-drop | 983,045 rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 32000 | 132.3 | 97.5 | 31 | 26.4 | 0.6 | 104 | 900 | FAIL |
| 1m-rules-drop-ip6 | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 56000 | 200 | 200.1 | 135 | 0.167 | 0.6 | 78 | 330 | PASS |

## psample sampling under load

| traffic | verdict |
|---|---|
| fixed-flood-31 | PASS |

## Ceiling proof (ingress vs egress budget)

| egress streams dropped | offered Mpps | RX Mpps | TX Mpps | NIC loss % |
|---|---|---|---|---|
| drop 0/3 | 199.2 | 187.7 | 0 | 5.8 |
| drop 1/3 | 200.0 | 198.1 | 0 | 0.959 |
| drop 2/3 | 200.0 | 199.3 | -2.49e+03 | 0.359 |
| drop 3/3 | 200.8 | 200.1 | -2.61e+03 | 0.329 |

## NIC temperature during the run (mlx5 ASIC sensor; the run stops at the limit)

| host | max °C | limit °C |
|---|---|---|
| bob | 70 | 95 |
| alice | 63 | 95 |

## Scenarios and traffic in this run

| scenario | rules loaded |
|---|---|
| `0rules` | no rules (forwarding baseline) |
| `1m-rules-drop` | 983,045 rules: 983,040 cold /24 drops + 5 hot rules |
| `1m-rules-drop-ip6` | 983,040 IPv6 rules: cold destination /64 drops |
| `5rules-drop` | 5 hot port-range drop rules |
| `country-set-drop` | 20,000 source prefixes (/10 to /24) in one named set, one drop rule |

| traffic | profile |
|---|---|
| `cold-scan` | scan across N destination /24s: N simultaneously active flows (64 B) |
| `cold-scan-imix` | cold-scan with IMIX frames (IMIX 64/570/1518 B, 7:4:1) |
| `cold-scan-scatter` | cold-scan with targets spread through the rule table (64 B) |
| `fixed-flood-31` | 31 fixed UDP flows balanced across RSS queues (64 B) |
| `fwd-flood-32` | 32 fixed flows that no rule matches (forwarded) (64 B) |
| `ip6-cold-scan` | IPv6 scan across N destinations (64 B) |
