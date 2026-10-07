# FastACL hardware bench: epyc-cx8, full suite

**CALIBRATION RUN (no verdict)**: 9 checks passed, 2 failed, 101 recorded measurements. 2026-10-07 09:02 UTC.

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
| VPP | v25.10-release, 32 worker threads, RX/TX ring 4096/4096 |
| FastACL | 0.6.1 from release latest-main, licence evaluation (30-day maximum) (expires 2026-11-01) |
| Testbench | 13f103c |
| Run | local |

## Summary

### Rules (64 B, drop)

| rules | traffic | offered Mpps | absorbed Mpps | cycles/pkt | limited by |
|---|---|---|---|---|---|
| 5 | fixed-flood-31 | 300 | 300.1 | 88 | offered rate |
| 1000 | fixed-flood-31 | 299.9 | 296.5 | 99 | DUT |
| 10000 | fixed-flood-31 | 300 | 300.2 | 99 | offered rate |
| 100000 | fixed-flood-31 | 299.9 | 300 | 113 | offered rate |
| 983045 | fixed-flood-31 | 300.1 | 300.1 | 116 | offered rate |

### Attack types (64 B unless the profile says otherwise)

| traffic | 5 rules: offered | absorbed Mpps | cyc/pkt | limited by | 983K rules: offered | absorbed Mpps | cyc/pkt | limited by |
|---|---|---|---|---|---|---|---|---|
| udp-rand | 300 | 300 | 125 | offered rate | 300 | 300 | 137 | offered rate |
| syn-flood | 300.1 | 299.8 | 62 | offered rate | 300 | 299.9 | 103 | offered rate |
| ack-flood | 299.9 | 268.9 | 64 | DUT | 300 | 298.9 | 105 | offered rate |
| icmp-flood | 300 | 299.8 | 62 | offered rate | 300 | 299.9 | 102 | offered rate |
| frag-flood | 300.1 | 300.1 | 86 | offered rate | 300 | 300.1 | 113 | offered rate |
| fixed-flood-31 | 300.1 | 300.1 | 87 | offered rate | 300 | 300.1 | 114 | offered rate |
| fwd-flood-32 | 299.9 | 299.8 | 112 | offered rate | 300 | 299.8 | 129 | offered rate |
| tcp-flows-31 | 300.1 | 299.8 | 62 | offered rate | 300 | 299.9 | 103 | offered rate |
| cold-scan | 300 | 299.8 | 112 | offered rate | 300 | 300.1 | 103 | offered rate |
| cold-scan-scatter | 300.1 | 299.8 | 112 | offered rate | 300.1 | 274.5 | 107 | DUT |
| cold-scan-imix | 132.3 | 121.8 | 142 | DUT | 132.3 | 130 | 144 | DUT |
| bng | 300 | 268.9 | 112 | DUT | 300.1 | 299.8 | 127 | offered rate |
| bng-imix | 132.4 | 121.8 | 139 | DUT | 132.3 | 121.8 | 155 | DUT |
| ipv6-flood | 300.1 | 300 | 129 | offered rate | 300 | 300 | 127 | offered rate |
| ip6-cold-scan | 300 | 268.9 | 115 | DUT | 300 | 299.8 | 114 | offered rate |
| reflection-mix | 49 | 49 | 188 | offered rate | 49 | 49 | 257 | offered rate |
| multivector | 138.4 | 138.4 | 124 | generator | 138.2 | 138.2 | 270 | generator |
| mix-sizes | 71.9 | 71.9 | 165 | offered rate | 71.9 | 71.9 | 264 | offered rate |
| mix-protos | 300 | 268.9 | 108 | DUT | 300.1 | 249.3 | 210 | DUT |
| mix-udptcp | 299.9 | 299.5 | 97 | offered rate | 299.9 | 219 | 254 | DUT |
| mix-burst | 17.9 | 17.9 | 228 | generator | 17.8 | 17.8 | 485 | generator |

### Active flows (983K rules, 64 B, drop)

| active flows | IPv4 Mpps | IPv4 cyc/pkt | IPv6 Mpps | IPv6 cyc/pkt | limited by |
|---|---|---|---|---|---|
| 1000 | 268.9 | 100 | 300.1 | 76 | DUT |
| 10000 | 300.1 | 102 | 300.1 | 78 | offered rate |
| 26000 | 300.1 | 104 | 300.1 | 78 | offered rate |
| 32000 | 300.1 | 106 | 300.1 | 80 | offered rate |
| 50000 | 299.9 | 122 | 300.1 | 81 | offered rate |
| 100000 | 271.9 | 179 | 300.1 | 101 | DUT |
| 500000 | 172.5 | 350 | 296.2 | 154 | DUT |
| 983040 | 163.6 | 374 | 290.1 | 161 | DUT |

- IPv4: the offered rate is held up to 50,000 active flows.
- IPv6: the offered rate is held up to 100,000 active flows.

### Packet size (1 × 400 Gbps ingress)

| frame | drop Mpps | drop Gbps (wire) | drop limited by | forward Mpps | forward Gbps (wire) | forward limited by |
|---|---|---|---|---|---|---|
| 64 B | 268.9 | 189.3 | DUT | 299.8 | 211.1 | offered rate |
| 128 B | 200 | 243.2 | offered rate | 200 | 243.2 | offered rate |
| 256 B | 120 | 268.8 | offered rate | 120 | 268.8 | offered rate |
| 512 B | 80.5 | 345.2 | offered rate | 80.6 | 345.6 | offered rate |
| 1024 B | 47.7 | 399.9 | offered rate | 47.7 | 399.9 | offered rate |
| 1500 B | 32.8 | 399.9 | offered rate | 32.8 | 399.9 | offered rate |
| IMIX 7:4:1 | 121.8 | 368.2 | DUT | 121.8 | 368.2 | DUT |

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
| 5rules-drop | 5 hot port-range drop rules | fixed-flood-31 | 64 B | 300 | 298.1 | 135 | 0.448 | 1 | 86.2 | 130 | PASS |
| 0rules | no rules (forwarding baseline) | fwd-flood-32 | 64 B | 300 | 298.9 | 97 | 0.547 | 1 | 48 | 70 | PASS |
| country-set-drop | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | fixed-flood-31 | 64 B | 300 | 298.9 | 135 | 0.449 | 1 | 82.3 | 160 | PASS |

## Prefix-set tuple count

| scenario | rules | tuples | limit | verdict |
|---|---|---|---|---|
| country-set-drop | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | 1 | 1 | PASS |

## Working-set gates (simultaneously active flows)

| scenario | rules | traffic | frame | active flows | offered Mpps | absorbed Mpps | floor Mpps | NIC loss % | loss limit % | cycles/pkt | cycle limit | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1m-rules-drop | 983,045 rules | cold-scan | 64 B | 32000 | 300 | 300.1 | 135 | 0.177 | 0.6 | 106 | 330 | PASS |
| 1m-rules-drop | 983,045 rules | cold-scan-scatter | 64 B | 32000 | 300 | 300 | 135 | 0.182 | 0.6 | 110 | 330 | PASS |
| 1m-rules-drop | 983,045 rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 32000 | 132.3 | 130 | 31 | 1.94 | 0.6 | 146 | 900 | FAIL |
| 1m-rules-drop-ip6 | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 56000 | 300 | 268.9 | 135 | 10.5 | 0.6 | 86 | 330 | FAIL |

## psample sampling under load

| traffic | verdict |
|---|---|
| fixed-flood-31 | PASS |

## Ceiling proof (ingress vs egress budget)

| egress streams dropped | offered Mpps | RX Mpps | TX Mpps | NIC loss % |
|---|---|---|---|---|
| drop 0/3 | 300.0 | 268.0 | 268.0 | 10.7 |
| drop 1/3 | 300.0 | 267.9 | 178.6 | 10.7 |
| drop 2/3 | 300.0 | 267.9 | 89.3 | 10.7 |
| drop 3/3 | 299.9 | 267.8 | 0.01 | 10.7 |

## All survey measurements

| sweep | scenario | rules loaded | rules | traffic | frame | active flows | offered Mpps | absorbed Mpps | NIC loss % | cycles/pkt |
|---|---|---|---|---|---|---|---|---|---|---|
| rules | nrules-drop | 5 |  | fixed-flood-31 | 64 B | 0 | 300 | 300.1 | 0.337 | 88 |
| rules | nrules-drop | 1000 |  | fixed-flood-31 | 64 B | 0 | 299.9 | 296.5 | 2.24 | 99 |
| rules | nrules-drop | 10000 |  | fixed-flood-31 | 64 B | 0 | 300 | 300.2 | 0.339 | 99 |
| rules | nrules-drop | 100000 |  | fixed-flood-31 | 64 B | 0 | 299.9 | 300 | 0.34 | 113 |
| rules | nrules-drop | 983045 |  | fixed-flood-31 | 64 B | 0 | 300.1 | 300.1 | 0.337 | 116 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | udp-rand | 64 B | 26000 | 300 | 300 | 0.342 | 125 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | syn-flood | 64 B | 26000 | 300.1 | 299.8 | 0.434 | 62 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ack-flood | 64 B | 26000 | 299.9 | 268.9 | 10.7 | 64 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | icmp-flood | 64 B | 26000 | 300 | 299.8 | 0.455 | 62 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | frag-flood | 64 B | 26000 | 300.1 | 300.1 | 0.337 | 86 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 64 B | 26000 | 300.1 | 300.1 | 0.335 | 87 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | fwd-flood-32 | 64 B | 26000 | 299.9 | 299.8 | 0.428 | 112 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | tcp-flows-31 | 64 B | 26000 | 300.1 | 299.8 | 0.436 | 62 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan | 64 B | 26000 | 300 | 299.8 | 0.423 | 112 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-scatter | 64 B | 26000 | 300.1 | 299.8 | 0.42 | 112 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 26000 | 132.3 | 121.8 | 8.26 | 142 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | bng | 64 B | 26000 | 300 | 268.9 | 10.7 | 112 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | bng-imix | 64 B | 26000 | 132.4 | 121.8 | 8.24 | 139 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ipv6-flood | 64 B | 26000 | 300.1 | 300 | 0.365 | 129 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ip6-cold-scan | 64 B | 26000 | 300 | 268.9 | 10.7 | 115 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | reflection-mix | mixed sizes | 26000 | 49 | 49 | 0.316 | 188 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | multivector | 64 B | 26000 | 138.4 | 138.4 | 0.326 | 124 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-sizes | mixed sizes | 26000 | 71.9 | 71.9 | 0.33 | 165 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-protos | 64 B | 26000 | 300 | 268.9 | 10.7 | 108 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-udptcp | 64 B | 26000 | 299.9 | 299.5 | 0.541 | 97 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-burst | 64 B | 26000 | 17.9 | 17.9 | 0.289 | 228 |
| attacks | 1m-rules-drop |  | 983,045 rules | udp-rand | 64 B | 26000 | 300 | 300 | 0.34 | 137 |
| attacks | 1m-rules-drop |  | 983,045 rules | syn-flood | 64 B | 26000 | 300 | 299.9 | 0.383 | 103 |
| attacks | 1m-rules-drop |  | 983,045 rules | ack-flood | 64 B | 26000 | 300 | 298.9 | 1.53 | 105 |
| attacks | 1m-rules-drop |  | 983,045 rules | icmp-flood | 64 B | 26000 | 300 | 299.9 | 0.389 | 102 |
| attacks | 1m-rules-drop |  | 983,045 rules | frag-flood | 64 B | 26000 | 300 | 300.1 | 0.331 | 113 |
| attacks | 1m-rules-drop |  | 983,045 rules | fixed-flood-31 | 64 B | 26000 | 300 | 300.1 | 0.348 | 114 |
| attacks | 1m-rules-drop |  | 983,045 rules | fwd-flood-32 | 64 B | 26000 | 300 | 299.8 | 0.429 | 129 |
| attacks | 1m-rules-drop |  | 983,045 rules | tcp-flows-31 | 64 B | 26000 | 300 | 299.9 | 0.389 | 103 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 26000 | 300 | 300.1 | 0.336 | 103 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan-scatter | 64 B | 26000 | 300.1 | 274.5 | 8.99 | 107 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 26000 | 132.3 | 130 | 2.09 | 144 |
| attacks | 1m-rules-drop |  | 983,045 rules | bng | 64 B | 26000 | 300.1 | 299.8 | 0.425 | 127 |
| attacks | 1m-rules-drop |  | 983,045 rules | bng-imix | 64 B | 26000 | 132.3 | 121.8 | 8.26 | 155 |
| attacks | 1m-rules-drop |  | 983,045 rules | ipv6-flood | 64 B | 26000 | 300 | 300 | 0.353 | 127 |
| attacks | 1m-rules-drop |  | 983,045 rules | ip6-cold-scan | 64 B | 26000 | 300 | 299.8 | 0.431 | 114 |
| attacks | 1m-rules-drop |  | 983,045 rules | reflection-mix | mixed sizes | 26000 | 49 | 49 | 0.318 | 257 |
| attacks | 1m-rules-drop |  | 983,045 rules | multivector | 64 B | 26000 | 138.2 | 138.2 | 0.328 | 270 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-sizes | mixed sizes | 26000 | 71.9 | 71.9 | 0.319 | 264 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-protos | 64 B | 26000 | 300.1 | 249.3 | 17.2 | 210 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-udptcp | 64 B | 26000 | 299.9 | 219 | 27.2 | 254 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-burst | 64 B | 26000 | 17.8 | 17.8 | 0.289 | 485 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | fixed-flood-31 | 64 B | 26000 | 300 | 268.9 | 10.7 | 92 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | cold-scan | 64 B | 26000 | 299.9 | 300.1 | 0.334 | 77 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | multivector | 64 B | 26000 | 138 | 138.1 | 0.326 | 205 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | fixed-flood-31 | 64 B | 26000 | 300 | 299.8 | 0.432 | 48 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | cold-scan | 64 B | 26000 | 300.1 | 299.8 | 0.434 | 48 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | multivector | 64 B | 26000 | 137.9 | 138 | 0.326 | 81 |
| scenarios | multivector |  | rules for several attack families at once | fixed-flood-31 | 64 B | 26000 | 300 | 266.5 | 11.5 | 182 |
| scenarios | multivector |  | rules for several attack families at once | cold-scan | 64 B | 26000 | 300.1 | 255.4 | 15.2 | 177 |
| scenarios | multivector |  | rules for several attack families at once | multivector | 64 B | 26000 | 137.9 | 137.9 | 0.336 | 326 |
| scenarios | tsweep |  | rule-diversity sweep | fixed-flood-31 | 64 B | 26000 | 299.9 | 268.9 | 10.7 | 92 |
| scenarios | tsweep |  | rule-diversity sweep | cold-scan | 64 B | 26000 | 300 | 300.1 | 0.338 | 77 |
| scenarios | tsweep |  | rule-diversity sweep | multivector | 64 B | 26000 | 137.8 | 137.9 | 0.326 | 185 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | fixed-flood-31 | 64 B | 26000 | 300 | 300.1 | 0.337 | 86 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | cold-scan | 64 B | 26000 | 300 | 300.1 | 0.334 | 86 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | multivector | 64 B | 26000 | 137.9 | 137.9 | 0.32 | 130 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | fixed-flood-31 | 64 B | 26000 | 299.9 | 232.3 | 22.6 | 233 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | cold-scan | 64 B | 26000 | 300.1 | 232.8 | 22.4 | 232 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | multivector | 64 B | 26000 | 138 | 138.1 | 0.327 | 271 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 1000 | 300 | 268.9 | 10.7 | 100 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 10000 | 300 | 300.1 | 0.339 | 102 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 26000 | 300.1 | 300.1 | 0.34 | 104 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 32000 | 299.9 | 300.1 | 0.339 | 106 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 50000 | 300.1 | 299.9 | 0.413 | 122 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 100000 | 299.9 | 271.9 | 9.72 | 179 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 500000 | 300 | 172.5 | 42.7 | 350 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 983040 | 300 | 163.6 | 45.7 | 374 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 1000 | 299.9 | 300.1 | 0.343 | 76 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 10000 | 300.1 | 300.1 | 0.335 | 78 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 26000 | 300 | 300.1 | 0.338 | 78 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 32000 | 300.1 | 300.1 | 0.337 | 80 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 50000 | 299.9 | 300.1 | 0.324 | 81 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 100000 | 300 | 300.1 | 0.336 | 101 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 500000 | 300 | 296.2 | 1.61 | 154 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 983040 | 300 | 290.1 | 3.66 | 161 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 64 B |  | 299.9 | 268.9 | 10.7 | 91 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 64 B |  | 299.9 | 299.8 | 0.439 | 48 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 128 B |  | 200 | 200 | 0.334 | 101 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 128 B |  | 200 | 200 | 0.334 | 56 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 256 B |  | 120 | 120 | 0.328 | 131 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 256 B |  | 120 | 120 | 0.323 | 69 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 512 B |  | 80.4 | 80.5 | 0.316 | 170 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 512 B |  | 80.6 | 80.6 | 0.333 | 103 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 1024 B |  | 47.7 | 47.7 | 0.316 | 241 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 1024 B |  | 47.7 | 47.7 | 0.317 | 157 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 1500 B |  | 32.8 | 32.8 | 0.305 | 294 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 1500 B |  | 32.8 | 32.8 | 0.307 | 204 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-imix | IMIX 7:4:1 |  | 132.4 | 121.8 | 8.25 | 143 |
| frames | 0rules |  | no rules (forwarding baseline) | cold-scan-imix | IMIX 7:4:1 |  | 132.4 | 121.8 | 8.27 | 75 |

## Two-port drop: the generator sends on both ports, the DUT filters both

| rules | traffic | requested Mpps (both ports) | arrived at the DUT NIC Mpps | absorbed Mpps | NIC loss % | cycles/pkt | detail |
|---|---|---|---|---|---|---|---|
| 5rules-drop | fixed-flood-31 | 600 | 187.5 | 186.7 | -0.031 | 100 | PASS dropped-in-node |
| 1m-rules-drop | fixed-flood-31 | 600 | 187.8 | 186.5 | -0.01 | 128 | PASS dropped-in-node |

## NIC temperature during the run (mlx5 ASIC sensor; the run stops at the limit)

| host | max °C | limit °C |
|---|---|---|
| epyc-sp5 | 66 | 95 |
| bob | 71 | 95 |

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
