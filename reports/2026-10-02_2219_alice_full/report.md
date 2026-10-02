# FastACL hardware bench: alice, full suite

**CALIBRATION RUN (no verdict)**: 5 checks passed, 6 failed, 101 recorded measurements. 2026-10-02 20:25 UTC.

| | |
|---|---|
| Topology | 2-node: bob (TRex) cabled back to back to alice, no switch |
| DUT CPU | AMD Ryzen 9 9950X 16-Core Processor (32 CPUs) |
| DUT NIC | Mellanox Technologies CX8 Family [ConnectX-8], link 400 Gbps |
| DUT kernel | 6.8.0-146-generic |
| DUT software | Ubuntu 24.04.4 LTS, NIC firmware 40.50.1002 |
| NIC driver | dpdk |
| Generator | AMD Ryzen 9 9950X 16-Core Processor (32 CPUs), Mellanox Technologies CX8 Family [ConnectX-8], TRex 3.06 |
| VPP | v25.10-release, 15 worker threads, RX/TX ring 4096/4096 |
| FastACL | 0.6.1 from release latest-main, licence evaluation (30-day maximum) (expires 2026-11-01) |
| Testbench | a162df2 |
| Run | local |

## Summary

### Rules (64 B, drop)

| rules | traffic | offered Mpps | absorbed Mpps | cycles/pkt | limited by |
|---|---|---|---|---|---|
| 5 | fixed-flood-31 | 200 | 188 | 75 | DUT |
| 1000 | fixed-flood-31 | 200 | 187.6 | 87 | DUT |
| 10000 | fixed-flood-31 | 200 | 187.5 | 87 | DUT |
| 100000 | fixed-flood-31 | 200 | 186.1 | 105 | DUT |
| 983045 | fixed-flood-31 | 200 | 185.8 | 107 | DUT |

### Attack types (64 B unless the profile says otherwise)

| traffic | 5 rules: offered | absorbed Mpps | cyc/pkt | limited by | 983K rules: offered | absorbed Mpps | cyc/pkt | limited by |
|---|---|---|---|---|---|---|---|---|
| udp-rand | 200 | 184.1 | 121 | DUT | 200 | 182 | 137 | DUT |
| syn-flood | 200 | 165.3 | 56 | DUT | 200 | 173.9 | 93 | DUT |
| ack-flood | 200 | 165.2 | 57 | DUT | 200 | 173.8 | 93 | DUT |
| icmp-flood | 200 | 165.2 | 56 | DUT | 200 | 173.9 | 93 | DUT |
| frag-flood | 199.9 | 187.9 | 74 | DUT | 199.9 | 186.1 | 107 | DUT |
| fixed-flood-31 | 200.1 | 188.1 | 76 | DUT | 200 | 186 | 108 | DUT |
| fwd-flood-32 | 200 | 165.1 | 99 | DUT | 200 | 164.8 | 113 | DUT |
| tcp-flows-31 | 200 | 165.2 | 57 | DUT | 199.9 | 173.8 | 93 | DUT |
| cold-scan | 200 | 165.1 | 99 | DUT | 200 | 186.1 | 93 | DUT |
| cold-scan-scatter | 200 | 165.1 | 99 | DUT | 200 | 186 | 94 | DUT |
| cold-scan-imix | 127.8 | 55.6 | 125 | DUT | 129 | 85.9 | 103 | DUT |
| bng | 200 | 165 | 97 | DUT | 200 | 164.9 | 111 | DUT |
| bng-imix | 127.9 | 55.6 | 123 | DUT | 128.2 | 55.6 | 142 | DUT |
| ipv6-flood | 200 | 182.4 | 134 | DUT | 200 | 182.3 | 134 | DUT |
| ip6-cold-scan | 200 | 165.1 | 107 | DUT | 199.9 | 165.1 | 107 | DUT |
| reflection-mix | 47.9 | 23.9 | 156 | DUT | 48 | 39.4 | 440 | DUT |
| multivector | 134.8 | 126.6 | 97 | DUT | 134.9 | 110.3 | 426 | DUT |
| mix-sizes | 71.7 | 32.7 | 140 | DUT | 71.7 | 53.1 | 606 | DUT |
| mix-protos | 200 | 163.4 | 100 | DUT | 200 | 130.3 | 347 | DUT |
| mix-udptcp | 200 | 164.6 | 92 | DUT | 200 | 111.4 | 437 | DUT |
| mix-burst | 18 | 18 | 153 | generator | 18 | 18 | 502 | generator |

### Active flows (983K rules, 64 B, drop)

| active flows | IPv4 Mpps | IPv4 cyc/pkt | IPv6 Mpps | IPv6 cyc/pkt | limited by |
|---|---|---|---|---|---|
| 1000 | 187.3 | 88 | 188.2 | 72 | DUT |
| 10000 | 186.8 | 92 | 187.9 | 70 | DUT |
| 26000 | 186.2 | 94 | 187.4 | 70 | DUT |
| 32000 | 186.1 | 93 | 187 | 72 | DUT |
| 50000 | 184.6 | 98 | 186 | 73 | DUT |
| 100000 | 168 | 172 | 181.7 | 92 | DUT |
| 500000 | 99.6 | 504 | 131.7 | 272 | DUT |
| 983040 | 95.1 | 540 | 133.7 | 288 | DUT |


### Packet size (1 × 400 Gbps ingress)

| frame | drop Mpps | drop Gbps (wire) | drop limited by | forward Mpps | forward Gbps (wire) | forward limited by |
|---|---|---|---|---|---|---|
| 64 B | 188.1 | 132.4 | DUT | 165.2 | 116.3 | DUT |
| 128 B | 126.9 | 154.3 | DUT | 113.9 | 138.5 | DUT |
| 256 B | 99.9 | 223.8 | DUT | 83.1 | 186.1 | DUT |
| 512 B | 68.4 | 293.3 | DUT | 42 | 180.1 | DUT |
| 1024 B | 40.1 | 336.2 | DUT | 24 | 201.2 | DUT |
| 1500 B | 27.9 | 340.2 | DUT | 16.8 | 204.8 | DUT |
| IMIX 7:4:1 | 55.5 | 167.8 | DUT | 55.5 | 167.8 | DUT |

*limited by*: **DUT** = the DUT absorbed less than was offered; **offered rate** = the generator reached its target and the DUT absorbed all of it; **generator** = the generator could not reach its target, so the DUT's limit is higher than shown.

## Method

- Frames are sized before FCS: 64 B means 68 B on the wire, so 100 % of 100 GbE is 142.05 Mpps.
- 64 B traffic is offered at 200 Mpps and larger frames at 100 Gbps; mixed-size traffic is offered at 400 Gbps (a packet rate is only a fixed bit rate when every frame is the same size).
- **absorbed Mpps**: packets the DUT received and processed per second (dropped by a rule or forwarded), from counter deltas over the sample window.
- **NIC loss %**: packets that reached the DUT port but never reached VPP (`rx_phy - rx_good`), i.e. lost inside the adapter.
- **cycles/pkt**: CPU cycles the `fastacl-filter` node spends per packet (`show runtime`).
- A gate passes when every value is within its limit; survey and ceiling rows are recorded without a verdict.
- Trials: oneport 5 s warm-up, 10 s sample; flows 20 s warm-up, 30 s sample; survey 10 s warm-up, 15 s sample; ceiling 5 s warm-up, 15 s sample per row.
- Full methodology: [test strategy](https://github.com/FastNetMon/fastacl-testbench/blob/main/docs/test-strategy.md).

## One-port gates (drop and forward)

| scenario | rules | traffic | frame | offered Mpps | absorbed Mpps | floor Mpps | NIC loss % | loss limit % | cycles/pkt | cycle limit | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 5rules-drop | 5 hot port-range drop rules | fixed-flood-31 | 64 B | 200 | 187.3 | 135 | 6.5 | 1 | 75.1 | 130 | FAIL |
| 0rules | no rules (forwarding baseline) | fwd-flood-32 | 64 B | 142 | 141.4 | 97 | 0.445 | 1 | 45.5 | 70 | PASS |
| country-set-drop | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | fixed-flood-31 | 64 B | 200 | 186.4 | 135 | 6.66 | 1 | 73.8 | 160 | FAIL |

## Prefix-set tuple count

| scenario | rules | tuples | limit | verdict |
|---|---|---|---|---|
| country-set-drop | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | 1 | 1 | PASS |

## Working-set gates (simultaneously active flows)

| scenario | rules | traffic | frame | active flows | offered Mpps | absorbed Mpps | floor Mpps | NIC loss % | loss limit % | cycles/pkt | cycle limit | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1m-rules-drop | 983,045 rules | cold-scan | 64 B | 32000 | 200 | 185.7 | 135 | 7.37 | 0.6 | 92 | 330 | FAIL |
| 1m-rules-drop | 983,045 rules | cold-scan-scatter | 64 B | 32000 | 200 | 185.2 | 135 | 7.59 | 0.6 | 93 | 330 | FAIL |
| 1m-rules-drop | 983,045 rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 32000 | 128.7 | 85.8 | 31 | 33.5 | 0.6 | 102 | 900 | FAIL |
| 1m-rules-drop-ip6 | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 56000 | 200 | 185 | 135 | 7.72 | 0.6 | 72 | 330 | FAIL |

## psample sampling under load

| traffic | verdict |
|---|---|
| fixed-flood-31 | PASS |

## Ceiling proof (ingress vs egress budget)

| egress streams dropped | offered Mpps | RX Mpps | TX Mpps | NIC loss % |
|---|---|---|---|---|
| drop 0/3 | 199.6 | 164.3 | 164.3 | 17.7 |
| drop 1/3 | 199.2 | 172.7 | -2.14e+03 | 13.3 |
| drop 2/3 | 200.0 | 180.0 | 60.0 | 9.99 |
| drop 3/3 | 199.9 | 187.2 | 0.01 | 6.39 |

## All survey measurements

| sweep | scenario | rules loaded | rules | traffic | frame | active flows | offered Mpps | absorbed Mpps | NIC loss % | cycles/pkt |
|---|---|---|---|---|---|---|---|---|---|---|
| rules | nrules-drop | 5 |  | fixed-flood-31 | 64 B | 0 | 200 | 188 | 6.44 | 75 |
| rules | nrules-drop | 1000 |  | fixed-flood-31 | 64 B | 0 | 200 | 187.6 | 6.62 | 87 |
| rules | nrules-drop | 10000 |  | fixed-flood-31 | 64 B | 0 | 200 | 187.5 | 6.66 | 87 |
| rules | nrules-drop | 100000 |  | fixed-flood-31 | 64 B | 0 | 200 | 186.1 | 7.34 | 105 |
| rules | nrules-drop | 983045 |  | fixed-flood-31 | 64 B | 0 | 200 | 185.8 | 7.49 | 107 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | udp-rand | 64 B | 26000 | 200 | 184.1 | 8.29 | 121 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | syn-flood | 64 B | 26000 | 200 | 165.3 | 17.8 | 56 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ack-flood | 64 B | 26000 | 200 | 165.2 | 17.7 | 57 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | icmp-flood | 64 B | 26000 | 200 | 165.2 | 17.8 | 56 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | frag-flood | 64 B | 26000 | 199.9 | 187.9 | 6.45 | 74 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 64 B | 26000 | 200.1 | 188.1 | 6.35 | 76 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | fwd-flood-32 | 64 B | 26000 | 200 | 165.1 | 17.8 | 99 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | tcp-flows-31 | 64 B | 26000 | 200 | 165.2 | 17.7 | 57 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan | 64 B | 26000 | 200 | 165.1 | 17.8 | 99 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-scatter | 64 B | 26000 | 200 | 165.1 | 17.8 | 99 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 26000 | 127.8 | 55.6 | 56.7 | 125 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | bng | 64 B | 26000 | 200 | 165 | 17.8 | 97 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | bng-imix | 64 B | 26000 | 127.9 | 55.6 | 56.7 | 123 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ipv6-flood | 64 B | 26000 | 200 | 182.4 | 9.18 | 134 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ip6-cold-scan | 64 B | 26000 | 200 | 165.1 | 17.8 | 107 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | reflection-mix | mixed sizes | 26000 | 47.9 | 23.9 | 50.4 | 156 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | multivector | 64 B | 26000 | 134.8 | 126.6 | 6.51 | 97 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-sizes | mixed sizes | 26000 | 71.7 | 32.7 | 54.7 | 140 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-protos | 64 B | 26000 | 200 | 163.4 | 18.6 | 100 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-udptcp | 64 B | 26000 | 200 | 164.6 | 18.0 | 92 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-burst | 64 B | 26000 | 18 | 18 | 0.307 | 153 |
| attacks | 1m-rules-drop |  | 983,045 rules | udp-rand | 64 B | 26000 | 200 | 182 | 9.36 | 137 |
| attacks | 1m-rules-drop |  | 983,045 rules | syn-flood | 64 B | 26000 | 200 | 173.9 | 13.5 | 93 |
| attacks | 1m-rules-drop |  | 983,045 rules | ack-flood | 64 B | 26000 | 200 | 173.8 | 13.5 | 93 |
| attacks | 1m-rules-drop |  | 983,045 rules | icmp-flood | 64 B | 26000 | 200 | 173.9 | 13.5 | 93 |
| attacks | 1m-rules-drop |  | 983,045 rules | frag-flood | 64 B | 26000 | 199.9 | 186.1 | 7.32 | 107 |
| attacks | 1m-rules-drop |  | 983,045 rules | fixed-flood-31 | 64 B | 26000 | 200 | 186 | 7.38 | 108 |
| attacks | 1m-rules-drop |  | 983,045 rules | fwd-flood-32 | 64 B | 26000 | 200 | 164.8 | 17.9 | 113 |
| attacks | 1m-rules-drop |  | 983,045 rules | tcp-flows-31 | 64 B | 26000 | 199.9 | 173.8 | 13.5 | 93 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 26000 | 200 | 186.1 | 7.35 | 93 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan-scatter | 64 B | 26000 | 200 | 186 | 7.4 | 94 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 26000 | 129 | 85.9 | 33.7 | 103 |
| attacks | 1m-rules-drop |  | 983,045 rules | bng | 64 B | 26000 | 200 | 164.9 | 17.9 | 111 |
| attacks | 1m-rules-drop |  | 983,045 rules | bng-imix | 64 B | 26000 | 128.2 | 55.6 | 56.8 | 142 |
| attacks | 1m-rules-drop |  | 983,045 rules | ipv6-flood | 64 B | 26000 | 200 | 182.3 | 9.23 | 134 |
| attacks | 1m-rules-drop |  | 983,045 rules | ip6-cold-scan | 64 B | 26000 | 199.9 | 165.1 | 17.8 | 107 |
| attacks | 1m-rules-drop |  | 983,045 rules | reflection-mix | mixed sizes | 26000 | 48 | 39.4 | 18.3 | 440 |
| attacks | 1m-rules-drop |  | 983,045 rules | multivector | 64 B | 26000 | 134.9 | 110.3 | 18.6 | 426 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-sizes | mixed sizes | 26000 | 71.7 | 53.1 | 26.4 | 606 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-protos | 64 B | 26000 | 200 | 130.3 | 35.1 | 347 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-udptcp | 64 B | 26000 | 200 | 111.4 | 44.5 | 437 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-burst | 64 B | 26000 | 18 | 18 | 0.298 | 502 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | fixed-flood-31 | 64 B | 26000 | 200 | 173.6 | 13.6 | 81 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | cold-scan | 64 B | 26000 | 200 | 187.5 | 6.64 | 66 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | multivector | 64 B | 26000 | 134.9 | 104.9 | 22.6 | 407 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | fixed-flood-31 | 64 B | 26000 | 200 | 165.2 | 17.8 | 43 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | cold-scan | 64 B | 26000 | 200 | 164.5 | 17.8 | 43 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | multivector | 64 B | 26000 | 134.8 | 126.8 | 6.36 | 56 |
| scenarios | multivector |  | rules for several attack families at once | fixed-flood-31 | 64 B | 26000 | 200 | 167.3 | 16.7 | 163 |
| scenarios | multivector |  | rules for several attack families at once | cold-scan | 64 B | 26000 | 200 | 140.9 | 29.9 | 220 |
| scenarios | multivector |  | rules for several attack families at once | multivector | 64 B | 26000 | 134.8 | 50.4 | 62.8 | 1001 |
| scenarios | tsweep |  | rule-diversity sweep | fixed-flood-31 | 64 B | 26000 | 200 | 173.7 | 13.5 | 80 |
| scenarios | tsweep |  | rule-diversity sweep | cold-scan | 64 B | 26000 | 200 | 187.5 | 6.62 | 66 |
| scenarios | tsweep |  | rule-diversity sweep | multivector | 64 B | 26000 | 134.8 | 133 | 1.75 | 282 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | fixed-flood-31 | 64 B | 26000 | 200 | 187.9 | 6.42 | 76 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | cold-scan | 64 B | 26000 | 200 | 187.9 | 6.46 | 76 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | multivector | 64 B | 26000 | 134.8 | 134.9 | 0.316 | 90 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | fixed-flood-31 | 64 B | 26000 | 200 | 164.7 | 18.0 | 228 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | cold-scan | 64 B | 26000 | 200 | 164.7 | 18.0 | 228 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | multivector | 64 B | 26000 | 134.9 | 134.9 | 0.319 | 238 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 1000 | 200 | 187.3 | 6.75 | 88 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 10000 | 199.9 | 186.8 | 6.98 | 92 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 26000 | 200 | 186.2 | 7.29 | 94 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 32000 | 200 | 186.1 | 7.38 | 93 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 50000 | 200 | 184.6 | 8.09 | 98 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 100000 | 200.1 | 168 | 16.4 | 172 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 500000 | 200 | 99.6 | 50.4 | 504 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 983040 | 199.9 | 95.1 | 52.7 | 540 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 1000 | 200 | 188.2 | 6.3 | 72 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 10000 | 199.9 | 187.9 | 6.44 | 70 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 26000 | 200 | 187.4 | 6.76 | 70 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 32000 | 200 | 187 | 6.92 | 72 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 50000 | 200 | 186 | 7.38 | 73 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 100000 | 200 | 181.7 | 9.55 | 92 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 500000 | 200 | 131.7 | 34.2 | 272 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 983040 | 200 | 133.7 | 33.5 | 288 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 64 B |  | 200 | 188.1 | 6.33 | 75 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 64 B |  | 200 | 165.2 | 17.7 | 43 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 128 B |  | 200.1 | 126.9 | 36.6 | 131 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 128 B |  | 200 | 113.9 | 43.3 | 47 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 256 B |  | 120 | 99.9 | 17.1 | 82 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 256 B |  | 120 | 83.1 | 31.1 | 49 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 512 B |  | 73.7 | 68.4 | 7.53 | 90 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 512 B |  | 73.7 | 42 | 43.2 | 67 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 1024 B |  | 46.8 | 40.1 | 14.7 | 108 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 1024 B |  | 46.7 | 24 | 48.8 | 93 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 1500 B |  | 32.8 | 27.9 | 15.1 | 129 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 1500 B |  | 32.8 | 16.8 | 49.0 | 112 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-imix | IMIX 7:4:1 |  | 129.4 | 55.5 | 57.2 | 125 |
| frames | 0rules |  | no rules (forwarding baseline) | cold-scan-imix | IMIX 7:4:1 |  | 128.9 | 55.5 | 57.1 | 60 |

## Two-port drop: the generator sends on both ports, the DUT filters both

| rules | traffic | requested Mpps (both ports) | arrived at the DUT NIC Mpps | absorbed Mpps | NIC loss % | cycles/pkt | detail |
|---|---|---|---|---|---|---|---|
| 5rules-drop | fixed-flood-31 | 400 | 180.6 | 178.1 | 1.21 | 76.3 | PASS dropped-in-node |
| 1m-rules-drop | fixed-flood-31 | 400 | 180.5 | 176.9 | 1.61 | 109 | PASS dropped-in-node |

## NIC temperature during the run (mlx5 ASIC sensor; the run stops at the limit)

| host | max °C | limit °C |
|---|---|---|
| alice | 64 | 95 |
| bob | 66 | 95 |

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
