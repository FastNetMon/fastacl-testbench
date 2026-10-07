# FastACL hardware bench: epyc-cx8, full suite

**CALIBRATION RUN (no verdict)**: 5 checks passed, 6 failed, 101 recorded measurements. 2026-10-07 13:32 UTC.

| | |
|---|---|
| Topology | 2-node: bob (TRex) cabled back to back to epyc-cx8, no switch |
| DUT CPU | AMD EPYC 9534 64-Core Processor (128 CPUs) |
| DUT NIC | Mellanox Technologies CX8 Family [ConnectX-8], link 400 Gbps |
| DUT memory | 12 x 16 GB DDR5 @ 4800 MT/s (HMCG78AGBRA190N) |
| DUT kernel | 6.8.0-142-generic |
| DUT software | Ubuntu 24.04.4 LTS, NIC firmware 40.50.1002 |
| NIC driver | dpdk |
| Generator | AMD Ryzen 9 9950X 16-Core Processor (32 CPUs), Mellanox Technologies CX8 Family [ConnectX-8], TRex 3.06 |
| VPP | v25.10-release, 48 worker threads, RX/TX ring 4096/2048 |
| FastACL | 0.6.1 from release latest-main, licence evaluation (30-day maximum) (expires 2026-11-01) |
| Testbench | 19f1b5d |
| Run | local |

## Summary

### Rules (64 B, drop)

| rules | traffic | offered Mpps | absorbed Mpps | cycles/pkt | limited by |
|---|---|---|---|---|---|
| 5 | fixed-flood-31 | 299.9 | 199.1 | 82 | DUT |
| 1000 | fixed-flood-31 | 300 | 207.3 | 95 | DUT |
| 10000 | fixed-flood-31 | 300 | 207.6 | 95 | DUT |
| 100000 | fixed-flood-31 | 300 | 216.5 | 110 | DUT |
| 983045 | fixed-flood-31 | 300 | 219.6 | 113 | DUT |

### Attack types (64 B unless the profile says otherwise)

| traffic | 5 rules: offered | absorbed Mpps | cyc/pkt | limited by | 983K rules: offered | absorbed Mpps | cyc/pkt | limited by |
|---|---|---|---|---|---|---|---|---|
| udp-rand | 300 | 224.6 | 122 | DUT | 300 | 244.7 | 137 | DUT |
| syn-flood | 299.9 | 268.9 | 81 | DUT | 300 | 299.9 | 127 | offered rate |
| ack-flood | 299.9 | 268.9 | 81 | DUT | 299.9 | 268.9 | 131 | DUT |
| icmp-flood | 300 | 299.7 | 77 | offered rate | 300 | 268.9 | 130 | DUT |
| frag-flood | 300 | 199.6 | 81 | DUT | 300 | 218.4 | 113 | DUT |
| fixed-flood-31 | 300.1 | 200.4 | 82 | DUT | 300 | 219.3 | 113 | DUT |
| fwd-flood-32 | 300 | 299 | 134 | offered rate | 299.9 | 299.7 | 154 | offered rate |
| tcp-flows-31 | 300.1 | 268.9 | 81 | DUT | 299.9 | 268.9 | 131 | DUT |
| cold-scan | 300.1 | 268.9 | 137 | DUT | 300 | 214 | 101 | DUT |
| cold-scan-scatter | 299.9 | 299.7 | 133 | offered rate | 300 | 213.5 | 103 | DUT |
| cold-scan-imix | 132.3 | 114.8 | 184 | DUT | 132.4 | 120 | 189 | DUT |
| bng | 299.9 | 268.9 | 135 | DUT | 300 | 268.9 | 153 | DUT |
| bng-imix | 132.3 | 114.8 | 181 | DUT | 132.3 | 114.8 | 200 | DUT |
| ipv6-flood | 300 | 228.4 | 125 | DUT | 300 | 229.1 | 126 | DUT |
| ip6-cold-scan | 300 | 299.7 | 135 | offered rate | 300 | 268.9 | 140 | DUT |
| reflection-mix | 49 | 46.7 | 240 | DUT | 49 | 48.7 | 310 | offered rate |
| multivector | 137.9 | 138 | 155 | generator | 137.7 | 137.8 | 310 | generator |
| mix-sizes | 71.9 | 66.9 | 215 | DUT | 71.9 | 69.8 | 308 | DUT |
| mix-protos | 300 | 268.9 | 131 | DUT | 300.1 | 268.9 | 223 | DUT |
| mix-udptcp | 300 | 297.9 | 118 | offered rate | 300 | 268.9 | 268 | DUT |
| mix-burst | 17.8 | 17.8 | 261 | generator | 17.7 | 17.7 | 516 | generator |

### Active flows (983K rules, 64 B, drop)

| active flows | IPv4 Mpps | IPv4 cyc/pkt | IPv6 Mpps | IPv6 cyc/pkt | limited by |
|---|---|---|---|---|---|
| 1000 | 206.2 | 92 | 195.6 | 71 | DUT |
| 10000 | 212.4 | 98 | 197.1 | 72 | DUT |
| 26000 | 213.6 | 102 | 199.1 | 74 | DUT |
| 32000 | 217.5 | 104 | 197.9 | 75 | DUT |
| 50000 | 230.7 | 121 | 200.6 | 78 | DUT |
| 100000 | 268.9 | 225 | 211.2 | 94 | DUT |
| 500000 | 255.9 | 350 | 265.4 | 144 | DUT |
| 983040 | 249.1 | 365 | 260.1 | 153 | DUT |


### Packet size (1 × 400 Gbps ingress)

| frame | drop Mpps | drop Gbps (wire) | drop limited by | forward Mpps | forward Gbps (wire) | forward limited by |
|---|---|---|---|---|---|---|
| 64 B | 198.7 | 139.9 | DUT | 292.8 | 206.1 | DUT |
| 128 B | 186.2 | 226.4 | DUT | 200 | 243.2 | offered rate |
| 256 B | 120 | 268.8 | offered rate | 120 | 268.8 | offered rate |
| 512 B | 81.1 | 347.8 | offered rate | 81.1 | 347.8 | offered rate |
| 1024 B | 47.6 | 399.1 | offered rate | 45.7 | 383.1 | DUT |
| 1500 B | 32.8 | 399.9 | offered rate | 31.8 | 387.7 | DUT |
| IMIX 7:4:1 | 114.9 | 347.3 | DUT | 114.9 | 347.3 | DUT |

*limited by*: **DUT** = the DUT absorbed less than was offered; **offered rate** = the generator reached its target and the DUT absorbed all of it; **generator** = the generator could not reach its target, so the DUT's limit is higher than shown.

## Method

- Frames are sized before FCS: 64 B means 68 B on the wire, so 100 % of 100 GbE is 142.05 Mpps.
- 64 B traffic is offered at 300 Mpps and larger frames at 100 Gbps; mixed-size traffic is offered at 400 Gbps (a packet rate is only a fixed bit rate when every frame is the same size).
- **absorbed Mpps**: packets the DUT received and processed per second (dropped by a rule or forwarded), from counter deltas over the sample window.
- **NIC loss %**: packets that reached the DUT port but never reached VPP (`rx_phy - rx_good`), i.e. lost inside the adapter.
- **cycles/pkt**: CPU cycles the `fastacl-filter` node spends per packet (`show runtime`).
- A gate passes when every value is within its limit; survey and ceiling rows are recorded without a verdict.
- Trials: oneport 5 s warm-up, 10 s sample; flows 20 s warm-up, 30 s sample; survey 10 s warm-up, 15 s sample; ceiling 5 s warm-up, 15 s sample per row.
- Full methodology: [test strategy](https://github.com/FastNetMon/fastacl-testbench/blob/main/docs/test-strategy.md).

## One-port gates (drop and forward)

| scenario | rules | traffic | frame | offered Mpps | absorbed Mpps | floor Mpps | NIC loss % | loss limit % | cycles/pkt | cycle limit | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 5rules-drop | 5 hot port-range drop rules | fixed-flood-31 | 64 B | 300 | 200.6 | 135 | 33.4 | 1 | 84.5 | 130 | FAIL |
| 0rules | no rules (forwarding baseline) | fwd-flood-32 | 64 B | 300 | 267.3 | 97 | 10.8 | 1 | 67.2 | 70 | PASS |
| country-set-drop | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | fixed-flood-31 | 64 B | 300 | 197.1 | 135 | 34.4 | 1 | 80 | 160 | FAIL |

## Prefix-set tuple count

| scenario | rules | tuples | limit | verdict |
|---|---|---|---|---|
| country-set-drop | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | 1 | 1 | PASS |

## Working-set gates (simultaneously active flows)

| scenario | rules | traffic | frame | active flows | offered Mpps | absorbed Mpps | floor Mpps | NIC loss % | loss limit % | cycles/pkt | cycle limit | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1m-rules-drop | 983,045 rules | cold-scan | 64 B | 32000 | 300 | 214.1 | 135 | 28.8 | 0.6 | 103 | 330 | FAIL |
| 1m-rules-drop | 983,045 rules | cold-scan-scatter | 64 B | 32000 | 300 | 215.5 | 135 | 28.3 | 0.6 | 106 | 330 | FAIL |
| 1m-rules-drop | 983,045 rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 32000 | 132.3 | 120 | 31 | 9.51 | 0.6 | 191 | 900 | FAIL |
| 1m-rules-drop-ip6 | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 56000 | 299.9 | 200.5 | 135 | 33.3 | 0.6 | 79 | 330 | FAIL |

## psample sampling under load

| traffic | verdict |
|---|---|
| fixed-flood-31 | PASS |

## Ceiling proof (ingress vs egress budget)

| egress streams dropped | offered Mpps | RX Mpps | TX Mpps | NIC loss % |
|---|---|---|---|---|
| drop 0/3 | 300 | 298.6 | 298.6 | 0.461 |
| drop 1/3 | 300.1 | 268.0 | 178.6 | 10.7 |
| drop 2/3 | 300 | 267.9 | 89.3 | 10.7 |
| drop 3/3 | 299.9 | 193.2 | 0.01 | 35.6 |

## All survey measurements

| sweep | scenario | rules loaded | rules | traffic | frame | active flows | offered Mpps | absorbed Mpps | NIC loss % | cycles/pkt |
|---|---|---|---|---|---|---|---|---|---|---|
| rules | nrules-drop | 5 |  | fixed-flood-31 | 64 B | 0 | 299.9 | 199.1 | 33.9 | 82 |
| rules | nrules-drop | 1000 |  | fixed-flood-31 | 64 B | 0 | 300 | 207.3 | 31.2 | 95 |
| rules | nrules-drop | 10000 |  | fixed-flood-31 | 64 B | 0 | 300 | 207.6 | 31.1 | 95 |
| rules | nrules-drop | 100000 |  | fixed-flood-31 | 64 B | 0 | 300 | 216.5 | 28.1 | 110 |
| rules | nrules-drop | 983045 |  | fixed-flood-31 | 64 B | 0 | 300 | 219.6 | 27.1 | 113 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | udp-rand | 64 B | 26000 | 300 | 224.6 | 25.4 | 122 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | syn-flood | 64 B | 26000 | 299.9 | 268.9 | 10.7 | 81 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ack-flood | 64 B | 26000 | 299.9 | 268.9 | 10.7 | 81 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | icmp-flood | 64 B | 26000 | 300 | 299.7 | 0.47 | 77 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | frag-flood | 64 B | 26000 | 300 | 199.6 | 33.7 | 81 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 64 B | 26000 | 300.1 | 200.4 | 33.5 | 82 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | fwd-flood-32 | 64 B | 26000 | 300 | 299 | 1.49 | 134 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | tcp-flows-31 | 64 B | 26000 | 300.1 | 268.9 | 10.7 | 81 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan | 64 B | 26000 | 300.1 | 268.9 | 10.7 | 137 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-scatter | 64 B | 26000 | 299.9 | 299.7 | 0.458 | 133 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 26000 | 132.3 | 114.8 | 13.6 | 184 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | bng | 64 B | 26000 | 299.9 | 268.9 | 10.7 | 135 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | bng-imix | 64 B | 26000 | 132.3 | 114.8 | 13.6 | 181 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ipv6-flood | 64 B | 26000 | 300 | 228.4 | 24.1 | 125 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ip6-cold-scan | 64 B | 26000 | 300 | 299.7 | 0.462 | 135 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | reflection-mix | mixed sizes | 26000 | 49 | 46.7 | 4.96 | 240 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | multivector | 64 B | 26000 | 137.9 | 138 | 0.333 | 155 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-sizes | mixed sizes | 26000 | 71.9 | 66.9 | 7.37 | 215 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-protos | 64 B | 26000 | 300 | 268.9 | 10.7 | 131 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-udptcp | 64 B | 26000 | 300 | 297.9 | 1.78 | 118 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-burst | 64 B | 26000 | 17.8 | 17.8 | 0.252 | 261 |
| attacks | 1m-rules-drop |  | 983,045 rules | udp-rand | 64 B | 26000 | 300 | 244.7 | 18.7 | 137 |
| attacks | 1m-rules-drop |  | 983,045 rules | syn-flood | 64 B | 26000 | 300 | 299.9 | 0.409 | 127 |
| attacks | 1m-rules-drop |  | 983,045 rules | ack-flood | 64 B | 26000 | 299.9 | 268.9 | 10.7 | 131 |
| attacks | 1m-rules-drop |  | 983,045 rules | icmp-flood | 64 B | 26000 | 300 | 268.9 | 10.7 | 130 |
| attacks | 1m-rules-drop |  | 983,045 rules | frag-flood | 64 B | 26000 | 300 | 218.4 | 27.5 | 113 |
| attacks | 1m-rules-drop |  | 983,045 rules | fixed-flood-31 | 64 B | 26000 | 300 | 219.3 | 27.2 | 113 |
| attacks | 1m-rules-drop |  | 983,045 rules | fwd-flood-32 | 64 B | 26000 | 299.9 | 299.7 | 0.454 | 154 |
| attacks | 1m-rules-drop |  | 983,045 rules | tcp-flows-31 | 64 B | 26000 | 299.9 | 268.9 | 10.7 | 131 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 26000 | 300 | 214 | 28.9 | 101 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan-scatter | 64 B | 26000 | 300 | 213.5 | 29.1 | 103 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 26000 | 132.4 | 120 | 9.65 | 189 |
| attacks | 1m-rules-drop |  | 983,045 rules | bng | 64 B | 26000 | 300 | 268.9 | 10.7 | 153 |
| attacks | 1m-rules-drop |  | 983,045 rules | bng-imix | 64 B | 26000 | 132.3 | 114.8 | 13.6 | 200 |
| attacks | 1m-rules-drop |  | 983,045 rules | ipv6-flood | 64 B | 26000 | 300 | 229.1 | 23.9 | 126 |
| attacks | 1m-rules-drop |  | 983,045 rules | ip6-cold-scan | 64 B | 26000 | 300 | 268.9 | 10.7 | 140 |
| attacks | 1m-rules-drop |  | 983,045 rules | reflection-mix | mixed sizes | 26000 | 49 | 48.7 | 0.883 | 310 |
| attacks | 1m-rules-drop |  | 983,045 rules | multivector | 64 B | 26000 | 137.7 | 137.8 | 0.33 | 310 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-sizes | mixed sizes | 26000 | 71.9 | 69.8 | 3.34 | 308 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-protos | 64 B | 26000 | 300.1 | 268.9 | 10.7 | 223 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-udptcp | 64 B | 26000 | 300 | 268.9 | 10.7 | 268 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-burst | 64 B | 26000 | 17.7 | 17.7 | 0.298 | 516 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | fixed-flood-31 | 64 B | 26000 | 300 | 299.9 | 0.397 | 113 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | cold-scan | 64 B | 26000 | 300 | 197.3 | 34.5 | 73 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | multivector | 64 B | 26000 | 137.7 | 137.7 | 0.367 | 252 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | fixed-flood-31 | 64 B | 26000 | 300 | 299.7 | 0.463 | 62 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | cold-scan | 64 B | 26000 | 300 | 268.9 | 10.7 | 66 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | multivector | 64 B | 26000 | 137.8 | 137.8 | 0.33 | 106 |
| scenarios | multivector |  | rules for several attack families at once | fixed-flood-31 | 64 B | 26000 | 300 | 299.9 | 0.404 | 210 |
| scenarios | multivector |  | rules for several attack families at once | cold-scan | 64 B | 26000 | 300 | 268.9 | 10.7 | 190 |
| scenarios | multivector |  | rules for several attack families at once | multivector | 64 B | 26000 | 137.7 | 137.7 | 0.305 | 382 |
| scenarios | tsweep |  | rule-diversity sweep | fixed-flood-31 | 64 B | 26000 | 299.9 | 299.9 | 0.397 | 113 |
| scenarios | tsweep |  | rule-diversity sweep | cold-scan | 64 B | 26000 | 300 | 199.4 | 33.8 | 73 |
| scenarios | tsweep |  | rule-diversity sweep | multivector | 64 B | 26000 | 137.7 | 137.8 | 0.325 | 212 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | fixed-flood-31 | 64 B | 26000 | 300 | 199.4 | 33.8 | 81 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | cold-scan | 64 B | 26000 | 299.9 | 200.7 | 33.4 | 81 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | multivector | 64 B | 26000 | 137.8 | 137.8 | 0.329 | 171 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | fixed-flood-31 | 64 B | 26000 | 300 | 268.9 | 10.7 | 264 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | cold-scan | 64 B | 26000 | 300 | 296 | 1.74 | 266 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | multivector | 64 B | 26000 | 137.7 | 137.8 | 0.323 | 330 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 1000 | 300 | 206.2 | 31.5 | 92 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 10000 | 300 | 212.4 | 29.5 | 98 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 26000 | 300 | 213.6 | 29.0 | 102 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 32000 | 300 | 217.5 | 27.7 | 104 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 50000 | 300 | 230.7 | 23.4 | 121 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 100000 | 300 | 268.9 | 10.7 | 225 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 500000 | 300 | 255.9 | 15.0 | 350 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 983040 | 300 | 249.1 | 17.3 | 365 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 1000 | 300 | 195.6 | 35.0 | 71 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 10000 | 299.9 | 197.1 | 34.5 | 72 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 26000 | 300 | 199.1 | 33.9 | 74 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 32000 | 300 | 197.9 | 34.3 | 75 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 50000 | 300 | 200.6 | 33.4 | 78 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 100000 | 300.1 | 211.2 | 29.8 | 94 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 500000 | 299.9 | 265.4 | 11.9 | 144 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 983040 | 300 | 260.1 | 13.6 | 153 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 64 B |  | 300 | 198.7 | 34.0 | 82 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 64 B |  | 300 | 292.8 | 3.29 | 63 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 128 B |  | 199.9 | 186.2 | 7.25 | 84 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 128 B |  | 200 | 200 | 0.337 | 75 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 256 B |  | 120 | 120 | 0.329 | 160 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 256 B |  | 120 | 120 | 0.328 | 100 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 512 B |  | 81.1 | 81.1 | 0.322 | 216 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 512 B |  | 81 | 81.1 | 0.333 | 149 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 1024 B |  | 47.7 | 47.6 | 0.582 | 313 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 1024 B |  | 47.7 | 45.7 | 4.58 | 230 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 1500 B |  | 32.8 | 32.8 | 0.284 | 356 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 1500 B |  | 32.8 | 31.8 | 3.55 | 286 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-imix | IMIX 7:4:1 |  | 132.4 | 114.9 | 13.5 | 185 |
| frames | 0rules |  | no rules (forwarding baseline) | cold-scan-imix | IMIX 7:4:1 |  | 132.3 | 114.9 | 13.5 | 111 |

## Two-port drop: the generator sends on both ports, the DUT filters both

| rules | traffic | requested Mpps (both ports) | arrived at the DUT NIC Mpps | absorbed Mpps | NIC loss % | cycles/pkt | detail |
|---|---|---|---|---|---|---|---|
| 5rules-drop | fixed-flood-31 | 600 | 186.2 | 135.8 | 26.8 | 134 | PASS dropped-in-node |
| 1m-rules-drop | fixed-flood-31 | 600 | 186 | 136 | 26.8 | 166 | PASS dropped-in-node |

## NIC temperature during the run (mlx5 ASIC sensor; the run stops at the limit)

| host | max °C | limit °C |
|---|---|---|
| epyc-sp5 | 66 | 95 |
| bob | 72 | 95 |

## Scenarios and traffic in this run

| scenario | rules loaded |
|---|---|
| `0rules` | no rules (forwarding baseline) |
| `1m-rules-drop` | 983,045 rules: 983,040 cold /24 drops + 5 hot rules |
| `1m-rules-drop-ip6` | 983,040 IPv6 rules: cold destination /64 drops |
| `1m-rules-drop-proto` | 983,040 rules: destination /24 + protocol (folded compact key) |
| `5rules-drop` | 5 hot port-range drop rules |
| `country-rules-drop` | the same 20,000 source prefixes as one rule each |
| `country-set-drop` | 20,000 source prefixes (/10 to /24) in one named set, one drop rule |
| `multivector` | rules for several attack families at once |
| `tsweep` | rule-diversity sweep: many distinct mask shapes |

| traffic | profile |
|---|---|
| `ack-flood` | TCP ACK flood (64 B) |
| `cold-scan` | scan across N destination /24s: N simultaneously active flows (64 B) |
| `cold-scan-imix` | cold-scan with IMIX frames (IMIX 64/570/1518 B, 7:4:1) |
| `cold-scan-scatter` | cold-scan with targets spread through the rule table (64 B) |
| `fixed-flood-31` | 31 fixed UDP flows balanced across RSS queues (64 B) |
| `frag-flood` | IP fragment flood (64 B) |
| `fwd-flood-32` | 32 fixed flows that no rule matches (forwarded) (64 B) |
| `icmp-flood` | ICMP echo flood (64 B) |
| `ip6-cold-scan` | IPv6 scan across N destinations (64 B) |
| `ipv6-flood` | IPv6 UDP flood (64 B) |
| `mix-burst` | bursty traffic (64 B) |
| `mix-protos` | mixed protocols (64 B) |
| `mix-sizes` | mixed frame sizes (mixed sizes) |
| `mix-udptcp` | UDP and TCP mix (64 B) |
| `multivector` | UDP + TCP + ICMP + fragments at once (64 B) |
| `reflection-mix` | amplification/reflection source-port mix (mixed sizes) |
| `syn-flood` | TCP SYN flood (64 B) |
| `tcp-flows-31` | 31 fixed TCP flows (64 B) |
| `udp-rand` | UDP flood, random source and ports (64 B) |
