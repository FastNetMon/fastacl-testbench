# FastACL hardware bench: alice, full suite

**CALIBRATION RUN (no verdict)**: 4 checks passed, 5 failed, 99 recorded measurements. 2026-10-02 15:25 UTC.

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
| Testbench | f8992a8 |
| Run | local |

## Summary

### Rules (64 B, drop)

| rules | traffic | offered Mpps | absorbed Mpps | cycles/pkt | limited by |
|---|---|---|---|---|---|
| 5 | fixed-flood-31 | 200 | 183.9 | 76 | DUT |
| 1000 | fixed-flood-31 | 200 | 183.7 | 87 | DUT |
| 10000 | fixed-flood-31 | 200 | 183.7 | 87 | DUT |
| 100000 | fixed-flood-31 | 200 | 182.4 | 105 | DUT |
| 983045 | fixed-flood-31 | 200 | 182.1 | 107 | DUT |

### Attack types (64 B unless the profile says otherwise)

| traffic | 5 rules: offered | absorbed Mpps | cyc/pkt | limited by | 983K rules: offered | absorbed Mpps | cyc/pkt | limited by |
|---|---|---|---|---|---|---|---|---|
| udp-rand | 200 | 181 | 122 | DUT | 199.9 | 178.8 | 136 | DUT |
| syn-flood | 200 | 160.3 | 57 | DUT | 200 | 168.3 | 93 | DUT |
| ack-flood | 200 | 160.3 | 57 | DUT | 200.1 | 168.3 | 93 | DUT |
| icmp-flood | 200 | 160.3 | 57 | DUT | 200.1 | 168.4 | 93 | DUT |
| frag-flood | 200 | 184 | 74 | DUT | 200.1 | 182.2 | 109 | DUT |
| fixed-flood-31 | 200 | 184 | 75 | DUT | 200 | 182.3 | 110 | DUT |
| fwd-flood-32 | 200 | 160.2 | 99 | DUT | 200 | 160.1 | 113 | DUT |
| tcp-flows-31 | 200 | 160.3 | 57 | DUT | 200 | 168.4 | 93 | DUT |
| cold-scan | 200 | 160.3 | 99 | DUT | 200 | 182.5 | 92 | DUT |
| cold-scan-scatter | 200 | 160.3 | 99 | DUT | 199.9 | 182.7 | 93 | DUT |
| cold-scan-imix | 33.2 | 33.2 | 141 | offered rate | 33.2 | 33.2 | 137 | offered rate |
| bng | 200 | 160.2 | 97 | DUT | 199.9 | 160.1 | 111 | DUT |
| bng-imix | 124.8 | 54.3 | 122 | DUT | 125 | 54.3 | 137 | DUT |
| ipv6-flood | 200 | 180 | 128 | DUT | 200 | 180.1 | 129 | DUT |
| ip6-cold-scan | 200 | 160.3 | 101 | DUT | 200 | 160.3 | 101 | DUT |
| reflection-mix | 47.9 | 23.4 | 155 | DUT | 48 | 38.6 | 447 | DUT |
| multivector | 134.6 | 122.7 | 97 | DUT | 134.8 | 109 | 430 | DUT |
| mix-sizes | 17.6 | 17.6 | 141 | offered rate | 17.6 | 17.6 | 383 | offered rate |
| mix-protos | 200.1 | 158.8 | 101 | DUT | 200 | 128.7 | 351 | DUT |
| mix-udptcp | 200.1 | 159.8 | 92 | DUT | 200 | 109.9 | 441 | DUT |
| mix-burst | 18.2 | 18.2 | 146 | generator | 18.3 | 18.3 | 504 | generator |

### Active flows (983K rules, 64 B, drop)

| active flows | IPv4 Mpps | IPv4 cyc/pkt | IPv6 Mpps | IPv6 cyc/pkt | limited by |
|---|---|---|---|---|---|
| 1000 | 183.5 | 87 | 187.9 | 70 | DUT |
| 10000 | 184.1 | 92 | 187.5 | 70 | DUT |
| 26000 | 186 | 92 | 187 | 70 | DUT |
| 32000 | 185.8 | 92 | 186.9 | 70 | DUT |
| 50000 | 184.6 | 96 | 186.5 | 71 | DUT |
| 100000 | 168.5 | 168 | 183.1 | 87 | DUT |
| 500000 | 98.6 | 509 | 133 | 288 | DUT |
| 983040 | 94.5 | 539 | 134.4 | 285 | DUT |


### Packet size (1 × 100G ingress)

| frame | drop Mpps | drop Gbps (wire) | drop limited by | forward Mpps | forward Gbps (wire) | forward limited by |
|---|---|---|---|---|---|---|
| 64 B | 187.8 | 132.2 | DUT | 164.7 | 115.9 | DUT |
| 128 B | 41.1 | 50.0 | generator | 41.1 | 50.0 | generator |
| 256 B | 22.3 | 50.0 | generator | 22.3 | 50.0 | generator |
| 512 B | 11.7 | 50.2 | generator | 11.7 | 50.2 | generator |
| 1024 B | 6 | 50.3 | generator | 6 | 50.3 | generator |
| 1500 B | 4.1 | 50.0 | generator | 4.1 | 50.0 | generator |
| IMIX 7:4:1 | 33.2 | 100.4 | offered rate | 33.2 | 100.4 | offered rate |

*limited by*: **DUT** = the DUT absorbed less than was offered; **offered rate** = the generator reached its target and the DUT absorbed all of it; **generator** = the generator could not reach its target, so the DUT's limit is higher than shown.

## Method

- Frames are sized before FCS: 64 B means 68 B on the wire, so 100 % of 100 GbE is 142.05 Mpps.
- 64 B traffic is offered at 200 Mpps and larger frames at 100 Gbps; mixed-size traffic is offered at 95 Gbps (a packet rate is only a fixed bit rate when every frame is the same size).
- **absorbed Mpps**: packets the DUT received and processed per second (dropped by a rule or forwarded), from counter deltas over the sample window.
- **NIC loss %**: packets that reached the DUT port but never reached VPP (`rx_phy - rx_good`), i.e. lost inside the adapter.
- **cycles/pkt**: CPU cycles the `fastacl-filter` node spends per packet (`show runtime`).
- A gate passes when every value is within its limit; survey and ceiling rows are recorded without a verdict.
- Trials: oneport 5 s warm-up, 10 s sample; flows 20 s warm-up, 30 s sample; survey 10 s warm-up, 15 s sample; ceiling 5 s warm-up, 15 s sample per row.
- Full methodology: [test strategy](https://github.com/FastNetMon/fastacl-testbench/blob/main/docs/test-strategy.md).

## One-port gates (drop and forward)

| scenario | rules | traffic | frame | offered Mpps | absorbed Mpps | floor Mpps | NIC loss % | loss limit % | cycles/pkt | cycle limit | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 5rules-drop | 5 hot port-range drop rules | fixed-flood-31 | 64 B | 200 | 182.3 | 135 | 8.77 | 1 | 77.8 | 130 | FAIL |
| 0rules | no rules (forwarding baseline) | fwd-flood-32 | 64 B | 142 | 141.1 | 97 | 0.441 | 1 | 45.7 | 70 | PASS |
| country-set-drop | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | fixed-flood-31 | 64 B | 200 | 182.1 | 135 | 8.71 | 1 | 74.4 | 160 | FAIL |

## Prefix-set tuple count

| scenario | rules | tuples | limit | verdict |
|---|---|---|---|---|
| country-set-drop | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | 1 | 1 | PASS |

## Working-set gates (simultaneously active flows)

| scenario | rules | traffic | frame | active flows | offered Mpps | absorbed Mpps | floor Mpps | NIC loss % | loss limit % | cycles/pkt | cycle limit | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1m-rules-drop | 983,045 rules | cold-scan | 64 B | 32000 | 200 | 182.3 | 135 | 9.08 | 0.6 | 93 | 330 | FAIL |
| 1m-rules-drop | 983,045 rules | cold-scan-scatter | 64 B | 32000 | 200 | 182 | 135 | 9.19 | 0.6 | 94 | 330 | FAIL |
| 1m-rules-drop | 983,045 rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 32000 | 33.2 | 33.2 | 31 | 0.166 | 0.6 | 146 | 900 | PASS |
| 1m-rules-drop-ip6 | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 56000 | 200 | 182.2 | 135 | 9.12 | 0.6 | 72 | 330 | FAIL |

## psample sampling under load

| traffic | verdict |
|---|---|
| fixed-flood-31 | PASS |

## Ceiling proof (ingress vs egress budget)

| egress streams dropped | offered Mpps | RX Mpps | TX Mpps | NIC loss % |
|---|---|---|---|---|
| drop 0/3 | 200.0 | 159.7 | 1964.2 | 20.1 |
| drop 1/3 | 199.5 | 167.3 | 2137.9 | 16.1 |
| drop 2/3 | 200.8 | 176.4 | -2.2e+03 | 12.2 |
| drop 3/3 | 200.0 | 183.4 | 0.01 | 8.33 |

## All survey measurements

| sweep | scenario | rules loaded | rules | traffic | frame | active flows | offered Mpps | absorbed Mpps | NIC loss % | cycles/pkt |
|---|---|---|---|---|---|---|---|---|---|---|
| rules | nrules-drop | 5 |  | fixed-flood-31 | 64 B | 0 | 200 | 183.9 | 8.4 | 76 |
| rules | nrules-drop | 1000 |  | fixed-flood-31 | 64 B | 0 | 200 | 183.7 | 8.56 | 87 |
| rules | nrules-drop | 10000 |  | fixed-flood-31 | 64 B | 0 | 200 | 183.7 | 8.53 | 87 |
| rules | nrules-drop | 100000 |  | fixed-flood-31 | 64 B | 0 | 200 | 182.4 | 9.21 | 105 |
| rules | nrules-drop | 983045 |  | fixed-flood-31 | 64 B | 0 | 200 | 182.1 | 9.29 | 107 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | udp-rand | 64 B | 26000 | 200 | 181 | 9.88 | 122 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | syn-flood | 64 B | 26000 | 200 | 160.3 | 20.2 | 57 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ack-flood | 64 B | 26000 | 200 | 160.3 | 20.2 | 57 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | icmp-flood | 64 B | 26000 | 200 | 160.3 | 20.2 | 57 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | frag-flood | 64 B | 26000 | 200 | 184 | 8.37 | 74 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 64 B | 26000 | 200 | 184 | 8.42 | 75 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | fwd-flood-32 | 64 B | 26000 | 200 | 160.2 | 20.2 | 99 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | tcp-flows-31 | 64 B | 26000 | 200 | 160.3 | 20.2 | 57 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan | 64 B | 26000 | 200 | 160.3 | 20.2 | 99 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-scatter | 64 B | 26000 | 200 | 160.3 | 20.2 | 99 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 26000 | 33.2 | 33.2 | 0.315 | 141 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | bng | 64 B | 26000 | 200 | 160.2 | 20.2 | 97 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | bng-imix | 64 B | 26000 | 124.8 | 54.3 | 56.8 | 122 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ipv6-flood | 64 B | 26000 | 200 | 180 | 10.4 | 128 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ip6-cold-scan | 64 B | 26000 | 200 | 160.3 | 20.2 | 101 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | reflection-mix | mixed sizes | 26000 | 47.9 | 23.4 | 51.3 | 155 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | multivector | 64 B | 26000 | 134.6 | 122.7 | 9.21 | 97 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-sizes | mixed sizes | 26000 | 17.6 | 17.6 | 0.306 | 141 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-protos | 64 B | 26000 | 200.1 | 158.8 | 20.9 | 101 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-udptcp | 64 B | 26000 | 200.1 | 159.8 | 20.4 | 92 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-burst | 64 B | 26000 | 18.2 | 18.2 | 0.302 | 146 |
| attacks | 1m-rules-drop |  | 983,045 rules | udp-rand | 64 B | 26000 | 199.9 | 178.8 | 11.0 | 136 |
| attacks | 1m-rules-drop |  | 983,045 rules | syn-flood | 64 B | 26000 | 200 | 168.3 | 16.2 | 93 |
| attacks | 1m-rules-drop |  | 983,045 rules | ack-flood | 64 B | 26000 | 200.1 | 168.3 | 16.3 | 93 |
| attacks | 1m-rules-drop |  | 983,045 rules | icmp-flood | 64 B | 26000 | 200.1 | 168.4 | 16.2 | 93 |
| attacks | 1m-rules-drop |  | 983,045 rules | frag-flood | 64 B | 26000 | 200.1 | 182.2 | 9.26 | 109 |
| attacks | 1m-rules-drop |  | 983,045 rules | fixed-flood-31 | 64 B | 26000 | 200 | 182.3 | 9.25 | 110 |
| attacks | 1m-rules-drop |  | 983,045 rules | fwd-flood-32 | 64 B | 26000 | 200 | 160.1 | 20.3 | 113 |
| attacks | 1m-rules-drop |  | 983,045 rules | tcp-flows-31 | 64 B | 26000 | 200 | 168.4 | 16.2 | 93 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 26000 | 200 | 182.5 | 9.12 | 92 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan-scatter | 64 B | 26000 | 199.9 | 182.7 | 9.09 | 93 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 26000 | 33.2 | 33.2 | 0.33 | 137 |
| attacks | 1m-rules-drop |  | 983,045 rules | bng | 64 B | 26000 | 199.9 | 160.1 | 20.3 | 111 |
| attacks | 1m-rules-drop |  | 983,045 rules | bng-imix | 64 B | 26000 | 125 | 54.3 | 56.9 | 137 |
| attacks | 1m-rules-drop |  | 983,045 rules | ipv6-flood | 64 B | 26000 | 200 | 180.1 | 10.3 | 129 |
| attacks | 1m-rules-drop |  | 983,045 rules | ip6-cold-scan | 64 B | 26000 | 200 | 160.3 | 20.2 | 101 |
| attacks | 1m-rules-drop |  | 983,045 rules | reflection-mix | mixed sizes | 26000 | 48 | 38.6 | 20.0 | 447 |
| attacks | 1m-rules-drop |  | 983,045 rules | multivector | 64 B | 26000 | 134.8 | 109 | 19.6 | 430 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-sizes | mixed sizes | 26000 | 17.6 | 17.6 | 0.346 | 383 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-protos | 64 B | 26000 | 200 | 128.7 | 35.9 | 351 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-udptcp | 64 B | 26000 | 200 | 109.9 | 45.3 | 441 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-burst | 64 B | 26000 | 18.3 | 18.3 | 0.304 | 504 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | fixed-flood-31 | 64 B | 26000 | 200 | 168.3 | 16.2 | 80 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | cold-scan | 64 B | 26000 | 200 | 183.2 | 8.79 | 66 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | multivector | 64 B | 26000 | 134.5 | 103.1 | 23.7 | 414 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | fixed-flood-31 | 64 B | 26000 | 200 | 160.3 | 20.2 | 42 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | cold-scan | 64 B | 26000 | 200 | 160.3 | 20.2 | 42 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | multivector | 64 B | 26000 | 134.6 | 123.1 | 8.93 | 55 |
| scenarios | multivector |  | rules for several attack families at once | fixed-flood-31 | 64 B | 26000 | 200 | 164.5 | 18.1 | 162 |
| scenarios | multivector |  | rules for several attack families at once | cold-scan | 64 B | 26000 | 200 | 145.1 | 27.8 | 221 |
| scenarios | multivector |  | rules for several attack families at once | multivector | 64 B | 26000 | 134.5 | 50.1 | 63.0 | 1009 |
| scenarios | tsweep |  | rule-diversity sweep | fixed-flood-31 | 64 B | 26000 | 200 | 168.4 | 16.2 | 81 |
| scenarios | tsweep |  | rule-diversity sweep | cold-scan | 64 B | 26000 | 200 | 183.4 | 8.68 | 66 |
| scenarios | tsweep |  | rule-diversity sweep | multivector | 64 B | 26000 | 134.6 | 131 | 3.16 | 286 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | fixed-flood-31 | 64 B | 26000 | 200 | 184 | 8.43 | 75 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | cold-scan | 64 B | 26000 | 199.9 | 184 | 8.4 | 75 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | multivector | 64 B | 26000 | 134.6 | 134.6 | 0.355 | 89 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | fixed-flood-31 | 64 B | 26000 | 200 | 163.8 | 18.5 | 220 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | cold-scan | 64 B | 26000 | 200 | 163.8 | 18.4 | 220 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | multivector | 64 B | 26000 | 134.5 | 134.6 | 0.321 | 231 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 1000 | 200.1 | 183.5 | 8.66 | 87 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 10000 | 200 | 184.1 | 8.23 | 92 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 26000 | 200 | 186 | 7.41 | 92 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 32000 | 200 | 185.8 | 7.48 | 92 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 50000 | 200 | 184.6 | 8.09 | 96 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 100000 | 200 | 168.5 | 16.1 | 168 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 500000 | 200 | 98.6 | 50.9 | 509 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 983040 | 199.9 | 94.5 | 52.9 | 539 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 1000 | 200 | 187.9 | 6.49 | 70 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 10000 | 200 | 187.5 | 6.69 | 70 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 26000 | 200 | 187 | 6.92 | 70 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 32000 | 200 | 186.9 | 6.94 | 70 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 50000 | 200 | 186.5 | 7.27 | 71 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 100000 | 200 | 183.1 | 8.89 | 87 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 500000 | 200 | 133 | 33.8 | 288 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 983040 | 200 | 134.4 | 33.1 | 285 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 64 B |  | 200 | 187.8 | 6.51 | 75 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 64 B |  | 200 | 164.7 | 18.0 | 42 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 128 B |  | 41.1 | 41.1 | 0.314 | 120 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 128 B |  | 41.1 | 41.1 | 0.361 | 76 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 256 B |  | 22.3 | 22.3 | 0.311 | 133 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 256 B |  | 22.3 | 22.3 | 0.33 | 96 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 512 B |  | 11.7 | 11.7 | 0.309 | 131 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 512 B |  | 11.7 | 11.7 | 0.305 | 89 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 1024 B |  | 6 | 6 | 0.308 | 146 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 1024 B |  | 6 | 6 | 0.278 | 105 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 1500 B |  | 4.1 | 4.1 | 0.253 | 159 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 1500 B |  | 4.1 | 4.1 | 0.244 | 121 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-imix | IMIX 7:4:1 |  | 33.2 | 33.2 | 0.323 | 144 |
| frames | 0rules |  | no rules (forwarding baseline) | cold-scan-imix | IMIX 7:4:1 |  | 33.2 | 33.2 | 0.321 | 81 |

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
