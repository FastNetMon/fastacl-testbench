# FastACL hardware bench: bob, full suite

**CALIBRATION RUN (no verdict)**: 5 checks passed, 6 failed, 101 recorded measurements. 2026-10-02 22:26 UTC.

| | |
|---|---|
| Topology | 2-node: alice (TRex) cabled back to back to bob, no switch |
| DUT CPU | AMD Ryzen 9 9950X 16-Core Processor (32 CPUs) |
| DUT NIC | Mellanox Technologies CX8 Family [ConnectX-8], link 400 Gbps |
| DUT kernel | 6.8.0-142-generic |
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
| 5 | fixed-flood-31 | 200 | 188.2 | 74 | DUT |
| 1000 | fixed-flood-31 | 200 | 187.3 | 87 | DUT |
| 10000 | fixed-flood-31 | 200 | 187.9 | 86 | DUT |
| 100000 | fixed-flood-31 | 200 | 186.4 | 104 | DUT |
| 983045 | fixed-flood-31 | 200 | 186.3 | 107 | DUT |

### Attack types (64 B unless the profile says otherwise)

| traffic | 5 rules: offered | absorbed Mpps | cyc/pkt | limited by | 983K rules: offered | absorbed Mpps | cyc/pkt | limited by |
|---|---|---|---|---|---|---|---|---|
| udp-rand | 200 | 184.4 | 121 | DUT | 199.9 | 183.1 | 135 | DUT |
| syn-flood | 200 | 165.4 | 56 | DUT | 200 | 174.2 | 92 | DUT |
| ack-flood | 200 | 165.5 | 56 | DUT | 200 | 174.4 | 92 | DUT |
| icmp-flood | 200 | 165.4 | 56 | DUT | 200 | 174.4 | 92 | DUT |
| frag-flood | 200 | 188.3 | 73 | DUT | 200 | 187.1 | 105 | DUT |
| fixed-flood-31 | 200 | 188.3 | 75 | DUT | 199.9 | 187.3 | 107 | DUT |
| fwd-flood-32 | 200 | 165.4 | 98 | DUT | 200 | 165.2 | 112 | DUT |
| tcp-flows-31 | 200 | 165.4 | 56 | DUT | 200 | 174.2 | 92 | DUT |
| cold-scan | 200 | 164.8 | 98 | DUT | 200 | 186.5 | 91 | DUT |
| cold-scan-scatter | 200 | 165.4 | 98 | DUT | 200.1 | 186.6 | 92 | DUT |
| cold-scan-imix | 129.1 | 55.8 | 123 | DUT | 129.3 | 86.3 | 104 | DUT |
| bng | 200.1 | 165.2 | 96 | DUT | 199.9 | 165.2 | 111 | DUT |
| bng-imix | 128.3 | 55.8 | 121 | DUT | 128.9 | 55.8 | 139 | DUT |
| ipv6-flood | 200 | 183.2 | 128 | DUT | 200 | 184.3 | 128 | DUT |
| ip6-cold-scan | 200 | 165.2 | 100 | DUT | 200 | 164.9 | 102 | DUT |
| reflection-mix | 48.9 | 23.9 | 153 | DUT | 49 | 39.8 | 445 | DUT |
| multivector | 135.1 | 126.7 | 96 | DUT | 135.2 | 109.8 | 426 | DUT |
| mix-sizes | 70.7 | 32.9 | 137 | DUT | 70.2 | 53.8 | 578 | DUT |
| mix-protos | 200 | 163.7 | 100 | DUT | 200 | 130.1 | 348 | DUT |
| mix-udptcp | 200 | 165.1 | 92 | DUT | 200 | 110.9 | 437 | DUT |
| mix-burst | 17.9 | 17.9 | 147 | generator | 17.3 | 17.4 | 508 | generator |

### Active flows (983K rules, 64 B, drop)

| active flows | IPv4 Mpps | IPv4 cyc/pkt | IPv6 Mpps | IPv6 cyc/pkt | limited by |
|---|---|---|---|---|---|
| 1000 | 188.3 | 87 | 188.8 | 69 | DUT |
| 10000 | 187.3 | 91 | 188.5 | 69 | DUT |
| 26000 | 186.3 | 92 | 187.9 | 69 | DUT |
| 32000 | 186.2 | 92 | 187.3 | 69 | DUT |
| 50000 | 184.3 | 98 | 186.6 | 70 | DUT |
| 100000 | 165.2 | 180 | 181.6 | 91 | DUT |
| 500000 | 95.8 | 522 | 131.5 | 285 | DUT |
| 983040 | 93.7 | 542 | 134.7 | 273 | DUT |


### Packet size (1 × 400 Gbps ingress)

| frame | drop Mpps | drop Gbps (wire) | drop limited by | forward Mpps | forward Gbps (wire) | forward limited by |
|---|---|---|---|---|---|---|
| 64 B | 189.1 | 133.1 | DUT | 165.5 | 116.5 | DUT |
| 128 B | 128.2 | 155.9 | DUT | 114.2 | 138.9 | DUT |
| 256 B | 100.5 | 225.1 | DUT | 83.4 | 186.8 | DUT |
| 512 B | 69 | 295.9 | DUT | 42.1 | 180.5 | DUT |
| 1024 B | 40.4 | 338.7 | DUT | 24 | 201.2 | DUT |
| 1500 B | 28.2 | 343.8 | DUT | 16.8 | 204.8 | DUT |
| IMIX 7:4:1 | 55.7 | 168.4 | DUT | 55.7 | 168.4 | DUT |

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
| 5rules-drop | 5 hot port-range drop rules | fixed-flood-31 | 64 B | 200 | 187.1 | 135 | 6.29 | 1 | 75.1 | 130 | FAIL |
| 0rules | no rules (forwarding baseline) | fwd-flood-32 | 64 B | 142 | 141.8 | 97 | 0.444 | 1 | 46.4 | 70 | PASS |
| country-set-drop | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | fixed-flood-31 | 64 B | 200 | 186.6 | 135 | 6.4 | 1 | 73.5 | 160 | FAIL |

## Prefix-set tuple count

| scenario | rules | tuples | limit | verdict |
|---|---|---|---|---|
| country-set-drop | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | 1 | 1 | PASS |

## Working-set gates (simultaneously active flows)

| scenario | rules | traffic | frame | active flows | offered Mpps | absorbed Mpps | floor Mpps | NIC loss % | loss limit % | cycles/pkt | cycle limit | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1m-rules-drop | 983,045 rules | cold-scan | 64 B | 32000 | 200 | 185.4 | 135 | 7.5 | 0.6 | 92 | 330 | FAIL |
| 1m-rules-drop | 983,045 rules | cold-scan-scatter | 64 B | 32000 | 200 | 185.5 | 135 | 7.5 | 0.6 | 93 | 330 | FAIL |
| 1m-rules-drop | 983,045 rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 32000 | 129.1 | 86.4 | 31 | 33.3 | 0.6 | 103 | 900 | FAIL |
| 1m-rules-drop-ip6 | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 56000 | 200 | 185.4 | 135 | 7.54 | 0.6 | 72 | 330 | FAIL |

## psample sampling under load

| traffic | verdict |
|---|---|
| fixed-flood-31 | PASS |

## Ceiling proof (ingress vs egress budget)

| egress streams dropped | offered Mpps | RX Mpps | TX Mpps | NIC loss % |
|---|---|---|---|---|
| drop 0/3 | 200.0 | 164.8 | 164.8 | 17.6 |
| drop 1/3 | 199.5 | 173.1 | 115.4 | 13.3 |
| drop 2/3 | 200.0 | 180.5 | 0 | 9.74 |
| drop 3/3 | 199.1 | 187.1 | 2383.2 | 6.06 |

## All survey measurements

| sweep | scenario | rules loaded | rules | traffic | frame | active flows | offered Mpps | absorbed Mpps | NIC loss % | cycles/pkt |
|---|---|---|---|---|---|---|---|---|---|---|
| rules | nrules-drop | 5 |  | fixed-flood-31 | 64 B | 0 | 200 | 188.2 | 6.27 | 74 |
| rules | nrules-drop | 1000 |  | fixed-flood-31 | 64 B | 0 | 200 | 187.3 | 6.45 | 87 |
| rules | nrules-drop | 10000 |  | fixed-flood-31 | 64 B | 0 | 200 | 187.9 | 6.43 | 86 |
| rules | nrules-drop | 100000 |  | fixed-flood-31 | 64 B | 0 | 200 | 186.4 | 7.18 | 104 |
| rules | nrules-drop | 983045 |  | fixed-flood-31 | 64 B | 0 | 200 | 186.3 | 7.25 | 107 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | udp-rand | 64 B | 26000 | 200 | 184.4 | 8.21 | 121 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | syn-flood | 64 B | 26000 | 200 | 165.4 | 17.6 | 56 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ack-flood | 64 B | 26000 | 200 | 165.5 | 17.6 | 56 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | icmp-flood | 64 B | 26000 | 200 | 165.4 | 17.6 | 56 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | frag-flood | 64 B | 26000 | 200 | 188.3 | 6.29 | 73 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 64 B | 26000 | 200 | 188.3 | 6.25 | 75 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | fwd-flood-32 | 64 B | 26000 | 200 | 165.4 | 17.6 | 98 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | tcp-flows-31 | 64 B | 26000 | 200 | 165.4 | 17.6 | 56 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan | 64 B | 26000 | 200 | 164.8 | 17.6 | 98 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-scatter | 64 B | 26000 | 200 | 165.4 | 17.6 | 98 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 26000 | 129.1 | 55.8 | 57.0 | 123 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | bng | 64 B | 26000 | 200.1 | 165.2 | 17.7 | 96 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | bng-imix | 64 B | 26000 | 128.3 | 55.8 | 56.7 | 121 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ipv6-flood | 64 B | 26000 | 200 | 183.2 | 8.74 | 128 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ip6-cold-scan | 64 B | 26000 | 200 | 165.2 | 17.8 | 100 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | reflection-mix | mixed sizes | 26000 | 48.9 | 23.9 | 51.3 | 153 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | multivector | 64 B | 26000 | 135.1 | 126.7 | 6.6 | 96 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-sizes | mixed sizes | 26000 | 70.7 | 32.9 | 54.0 | 137 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-protos | 64 B | 26000 | 200 | 163.7 | 18.5 | 100 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-udptcp | 64 B | 26000 | 200 | 165.1 | 17.8 | 92 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-burst | 64 B | 26000 | 17.9 | 17.9 | 0.311 | 147 |
| attacks | 1m-rules-drop |  | 983,045 rules | udp-rand | 64 B | 26000 | 199.9 | 183.1 | 8.83 | 135 |
| attacks | 1m-rules-drop |  | 983,045 rules | syn-flood | 64 B | 26000 | 200 | 174.2 | 13.3 | 92 |
| attacks | 1m-rules-drop |  | 983,045 rules | ack-flood | 64 B | 26000 | 200 | 174.4 | 13.2 | 92 |
| attacks | 1m-rules-drop |  | 983,045 rules | icmp-flood | 64 B | 26000 | 200 | 174.4 | 13.2 | 92 |
| attacks | 1m-rules-drop |  | 983,045 rules | frag-flood | 64 B | 26000 | 200 | 187.1 | 6.85 | 105 |
| attacks | 1m-rules-drop |  | 983,045 rules | fixed-flood-31 | 64 B | 26000 | 199.9 | 187.3 | 6.81 | 107 |
| attacks | 1m-rules-drop |  | 983,045 rules | fwd-flood-32 | 64 B | 26000 | 200 | 165.2 | 17.7 | 112 |
| attacks | 1m-rules-drop |  | 983,045 rules | tcp-flows-31 | 64 B | 26000 | 200 | 174.2 | 13.2 | 92 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 26000 | 200 | 186.5 | 7.17 | 91 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan-scatter | 64 B | 26000 | 200.1 | 186.6 | 7.09 | 92 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 26000 | 129.3 | 86.3 | 33.4 | 104 |
| attacks | 1m-rules-drop |  | 983,045 rules | bng | 64 B | 26000 | 199.9 | 165.2 | 17.8 | 111 |
| attacks | 1m-rules-drop |  | 983,045 rules | bng-imix | 64 B | 26000 | 128.9 | 55.8 | 56.9 | 139 |
| attacks | 1m-rules-drop |  | 983,045 rules | ipv6-flood | 64 B | 26000 | 200 | 184.3 | 8.24 | 128 |
| attacks | 1m-rules-drop |  | 983,045 rules | ip6-cold-scan | 64 B | 26000 | 200 | 164.9 | 17.6 | 102 |
| attacks | 1m-rules-drop |  | 983,045 rules | reflection-mix | mixed sizes | 26000 | 49 | 39.8 | 19.0 | 445 |
| attacks | 1m-rules-drop |  | 983,045 rules | multivector | 64 B | 26000 | 135.2 | 109.8 | 19.1 | 426 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-sizes | mixed sizes | 26000 | 70.2 | 53.8 | 24.4 | 578 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-protos | 64 B | 26000 | 200 | 130.1 | 35.2 | 348 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-udptcp | 64 B | 26000 | 200 | 110.9 | 44.8 | 437 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-burst | 64 B | 26000 | 17.3 | 17.4 | 0.3 | 508 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | fixed-flood-31 | 64 B | 26000 | 200 | 174.2 | 13.3 | 80 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | cold-scan | 64 B | 26000 | 200 | 188.1 | 6.4 | 65 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | multivector | 64 B | 26000 | 135 | 105.3 | 22.4 | 405 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | fixed-flood-31 | 64 B | 26000 | 200 | 165.6 | 17.5 | 43 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | cold-scan | 64 B | 26000 | 200 | 165.5 | 17.6 | 43 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | multivector | 64 B | 26000 | 135 | 127.2 | 6.21 | 56 |
| scenarios | multivector |  | rules for several attack families at once | fixed-flood-31 | 64 B | 26000 | 200 | 168 | 16.3 | 160 |
| scenarios | multivector |  | rules for several attack families at once | cold-scan | 64 B | 26000 | 199.9 | 122.8 | 38.9 | 251 |
| scenarios | multivector |  | rules for several attack families at once | multivector | 64 B | 26000 | 135.1 | 40.8 | 69.9 | 1234 |
| scenarios | tsweep |  | rule-diversity sweep | fixed-flood-31 | 64 B | 26000 | 200 | 174.2 | 13.3 | 80 |
| scenarios | tsweep |  | rule-diversity sweep | cold-scan | 64 B | 26000 | 200 | 188.2 | 6.34 | 65 |
| scenarios | tsweep |  | rule-diversity sweep | multivector | 64 B | 26000 | 135 | 131.7 | 2.9 | 284 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | fixed-flood-31 | 64 B | 26000 | 200 | 189.1 | 5.86 | 75 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | cold-scan | 64 B | 26000 | 200 | 189 | 5.9 | 75 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | multivector | 64 B | 26000 | 135.1 | 135.1 | 0.321 | 90 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | fixed-flood-31 | 64 B | 26000 | 200 | 167.1 | 16.8 | 218 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | cold-scan | 64 B | 26000 | 200 | 167.1 | 16.8 | 218 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | multivector | 64 B | 26000 | 135.1 | 135.1 | 0.323 | 234 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 1000 | 199.9 | 188.3 | 6.26 | 87 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 10000 | 200 | 187.3 | 6.78 | 91 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 26000 | 200 | 186.3 | 7.24 | 92 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 32000 | 200 | 186.2 | 7.29 | 92 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 50000 | 200 | 184.3 | 8.24 | 98 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 100000 | 200 | 165.2 | 17.8 | 180 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 500000 | 200 | 95.8 | 52.3 | 522 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 983040 | 200 | 93.7 | 53.3 | 542 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 1000 | 200 | 188.8 | 5.99 | 69 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 10000 | 200 | 188.5 | 6.17 | 69 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 26000 | 200 | 187.9 | 6.46 | 69 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 32000 | 200 | 187.3 | 6.74 | 69 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 50000 | 199.9 | 186.6 | 7.21 | 70 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 100000 | 200.1 | 181.6 | 9.62 | 91 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 500000 | 200 | 131.5 | 34.5 | 285 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 983040 | 200.1 | 134.7 | 33.0 | 273 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 64 B |  | 200 | 189.1 | 5.86 | 74 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 64 B |  | 200 | 165.5 | 17.6 | 43 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 128 B |  | 200 | 128.2 | 36.1 | 129 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 128 B |  | 200 | 114.2 | 43.2 | 47 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 256 B |  | 120 | 100.5 | 16.7 | 83 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 256 B |  | 120 | 83.4 | 30.8 | 49 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 512 B |  | 73.8 | 69 | 6.98 | 91 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 512 B |  | 73.8 | 42.1 | 43.1 | 68 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 1024 B |  | 44.4 | 40.4 | 9.31 | 109 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 1024 B |  | 44.2 | 24 | 45.9 | 96 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 1500 B |  | 32.8 | 28.2 | 14.4 | 133 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 1500 B |  | 32.8 | 16.8 | 48.8 | 115 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-imix | IMIX 7:4:1 |  | 129.9 | 55.7 | 57.2 | 126 |
| frames | 0rules |  | no rules (forwarding baseline) | cold-scan-imix | IMIX 7:4:1 |  | 129.5 | 55.7 | 57.1 | 61 |

## Two-port drop: the generator sends on both ports, the DUT filters both

| rules | traffic | requested Mpps (both ports) | arrived at the DUT NIC Mpps | absorbed Mpps | NIC loss % | cycles/pkt | detail |
|---|---|---|---|---|---|---|---|
| 5rules-drop | fixed-flood-31 | 400 | 182.1 | 177.8 | 1.95 | 76.2 | PASS dropped-in-node |
| 1m-rules-drop | fixed-flood-31 | 400 | 181.8 | 176.6 | 2.34 | 110 | PASS dropped-in-node |

## NIC temperature during the run (mlx5 ASIC sensor; the run stops at the limit)

| host | max °C | limit °C |
|---|---|---|
| bob | 67 | 95 |
| alice | 63 | 95 |

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
