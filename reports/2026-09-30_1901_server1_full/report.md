# FastACL hardware bench: server1, full suite

**PASS**: 9 checks passed, 0 failed, 95 recorded measurements. 2026-09-30 19:01 UTC.

| | |
|---|---|
| Topology | 2-node: flame (TRex) cabled back to back to server1, no switch |
| DUT CPU | AMD EPYC 7742 64-Core Processor (128 CPUs) |
| DUT NIC | Mellanox Technologies MT2910 Family [ConnectX-7], link 200 Gbps |
| DUT kernel | 6.8.0-139-generic |
| Generator | AMD Ryzen 7 5800X 8-Core Processor (16 CPUs), Mellanox Technologies MT2910 Family [ConnectX-7], TRex 3.06 |
| VPP | v25.10-release, 32 worker threads, RX/TX ring 4096/4096 |
| FastACL | 0.6.0 from release v0.6.0, licence evaluation (30-day maximum) (expires 2026-10-29) |
| Testbench | 3440df0-dirty |
| Run | local |

## Summary

### Rules (64 B, drop)

| rules | traffic | offered Mpps | absorbed Mpps | cycles/pkt | limited by |
|---|---|---|---|---|---|
| 5 | fixed-flood-31 | 127 | 127 | 120 | offered rate |
| 1000 | fixed-flood-31 | 127 | 127 | 138 | offered rate |
| 10000 | fixed-flood-31 | 127 | 127 | 138 | offered rate |
| 100000 | fixed-flood-31 | 127 | 127 | 154 | offered rate |
| 983045 | fixed-flood-31 | 127 | 127 | 159 | offered rate |

### Attack types (64 B unless the profile says otherwise)

| traffic | 5 rules: offered | absorbed Mpps | cyc/pkt | limited by | 983K rules: offered | absorbed Mpps | cyc/pkt | limited by |
|---|---|---|---|---|---|---|---|---|
| udp-rand | 127 | 127 | 166 | offered rate | 127 | 127 | 191 | offered rate |
| syn-flood | 127 | 111.7 | 88 | DUT | 127 | 118.9 | 140 | DUT |
| ack-flood | 127 | 111.7 | 88 | DUT | 127 | 118.9 | 140 | DUT |
| icmp-flood | 127 | 112.2 | 87 | DUT | 127 | 119.4 | 139 | DUT |
| frag-flood | 127 | 127 | 118 | offered rate | 127 | 127 | 159 | offered rate |
| fixed-flood-31 | 127 | 127 | 120 | offered rate | 127 | 127 | 159 | offered rate |
| fwd-flood-32 | 127 | 112.1 | 152 | DUT | 127 | 112.1 | 181 | DUT |
| tcp-flows-31 | 127 | 111.7 | 88 | DUT | 127 | 118.9 | 140 | DUT |
| cold-scan | 127 | 112.2 | 152 | DUT | 127 | 127 | 230 | offered rate |
| cold-scan-scatter | 127 | 112.2 | 152 | DUT | 127 | 127 | 213 | offered rate |
| cold-scan-imix | 33.2 | 33.2 | 163 | offered rate | 33.2 | 33.2 | 177 | offered rate |
| ipv6-flood | 127 | 127 | 164 | offered rate | 127 | 127 | 163 | offered rate |
| ip6-cold-scan | 127 | 112.1 | 147 | DUT | 127 | 112.1 | 146 | DUT |
| reflection-mix | 24.5 | 19.3 | 168 | DUT | 24.5 | 24.5 | 208 | offered rate |
| multivector | 127 | 25.5 | 236 | DUT | 127 | 27.9 | 455 | DUT |
| mix-sizes | 17.6 | 17.6 | 171 | offered rate | 17.6 | 17.6 | 252 | offered rate |
| mix-protos | 127 | 31.5 | 221 | DUT | 127 | 34.3 | 373 | DUT |
| mix-udptcp | 127 | 24.9 | 257 | DUT | 127 | 26.1 | 518 | DUT |
| mix-burst | 12.5 | 12.5 | 228 | generator | 13 | 13 | 503 | generator |

### Active flows (983K rules, 64 B, drop)

| active flows | IPv4 Mpps | IPv4 cyc/pkt | IPv6 Mpps | IPv6 cyc/pkt | limited by |
|---|---|---|---|---|---|
| 1000 | 127 | 142 | 127 | 107 | offered rate |
| 10000 | 127 | 145 | 127 | 108 | offered rate |
| 26000 | 127 | 231 | 127 | 112 | offered rate |
| 32000 | 127 | 260 | 127 | 115 | offered rate |
| 50000 | 127 | 319 | 127 | 165 | offered rate |
| 100000 | 127 | 394 | 127 | 187 | offered rate |
| 500000 | 125.6 | 428 | 127 | 208 | DUT |
| 983040 | 126 | 424 | 127 | 208 | offered rate |

- IPv4: the offered rate is held up to 983,040 active flows.
- IPv6: the offered rate is held up to 983,040 active flows.

### Packet size (1 × 100G ingress)

| frame | drop Mpps | drop Gbps (wire) | drop limited by | forward Mpps | forward Gbps (wire) | forward limited by |
|---|---|---|---|---|---|---|
| 64 B | 127 | 89.4 | offered rate | 112.1 | 78.9 | DUT |
| 128 B | 82.3 | 100.1 | offered rate | 82.1 | 99.8 | offered rate |
| 256 B | 44.7 | 100.1 | offered rate | 44.7 | 100.1 | offered rate |
| 512 B | 23.3 | 99.9 | offered rate | 23.3 | 99.9 | offered rate |
| 1024 B | 11.9 | 99.8 | offered rate | 11.9 | 99.8 | offered rate |
| 1500 B | 8.2 | 100.0 | offered rate | 8.2 | 100.0 | offered rate |
| IMIX 7:4:1 | 33.2 | 100.4 | offered rate | 33.2 | 100.4 | offered rate |

*limited by*: **DUT** = the DUT absorbed less than was offered; **offered rate** = the generator reached its target and the DUT absorbed all of it; **generator** = the generator could not reach its target, so the DUT's limit is higher than shown.

## Method

- Frames are sized before FCS: 64 B means 68 B on the wire, so 100 % of 100 GbE is 142.05 Mpps.
- 64 B traffic is offered at 127 Mpps and larger frames at 100 Gbps; mixed-size traffic is offered at 95 Gbps (a packet rate is only a fixed bit rate when every frame is the same size).
- **absorbed Mpps**: packets the DUT received and processed per second (dropped by a rule or forwarded), from counter deltas over the sample window.
- **NIC loss %**: packets that reached the DUT port but never reached VPP (`rx_phy - rx_good`), i.e. lost inside the adapter.
- **cycles/pkt**: CPU cycles the `fastacl-filter` node spends per packet (`show runtime`).
- A gate passes when every value is within its limit; survey and ceiling rows are recorded without a verdict.
- Trials: oneport 5 s warm-up, 10 s sample; flows 20 s warm-up, 30 s sample; survey 10 s warm-up, 15 s sample; ceiling 5 s warm-up, 15 s sample per row.
- Full methodology: [test strategy](https://github.com/FastNetMon/fastacl-testbench/blob/main/docs/test-strategy.md).

## One-port gates (drop and forward)

| scenario | rules | traffic | frame | offered Mpps | absorbed Mpps | floor Mpps | NIC loss % | loss limit % | cycles/pkt | cycle limit | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 5rules-drop | 5 hot port-range drop rules | fixed-flood-31 | 64 B | 127 | 126.2 | 120 | 0.45 | 1 | 119 | 130 | PASS |
| 0rules | no rules (forwarding baseline) | fixed-flood-31 | 64 B | 105 | 104.3 | 103 | 0.444 | 1 | 65.4 | 70 | PASS |
| country-set-drop | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | fixed-flood-31 | 64 B | 127 | 126.2 | 120 | 0.435 | 1 | 123 | 160 | PASS |

## Prefix-set tuple count

| scenario | rules | tuples | limit | verdict |
|---|---|---|---|---|
| country-set-drop | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | 1 | 1 | PASS |

## Working-set gates (simultaneously active flows)

| scenario | rules | traffic | frame | active flows | offered Mpps | absorbed Mpps | floor Mpps | NIC loss % | loss limit % | cycles/pkt | cycle limit | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1m-rules-drop | 983,045 rules | cold-scan | 64 B | 32000 | 127 | 127 | 124 | 0.173 | 0.6 | 260 | 330 | PASS |
| 1m-rules-drop | 983,045 rules | cold-scan-scatter | 64 B | 32000 | 127 | 127 | 124 | 0.175 | 0.6 | 242 | 330 | PASS |
| 1m-rules-drop | 983,045 rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 32000 | 33.2 | 33.2 | 30 | 0.165 | 0.6 | 194 | 900 | PASS |
| 1m-rules-drop-ip6 | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 56000 | 127 | 127 | 124 | 0.172 | 0.6 | 170 | 330 | PASS |

## psample sampling under load

| traffic | verdict |
|---|---|
| fixed-flood-31 | PASS |

## Ceiling proof (ingress vs egress budget)

| egress streams dropped | offered Mpps | RX Mpps | TX Mpps | NIC loss % |
|---|---|---|---|---|
| drop 0/3 | 127.0 | 111.7 | 111.7 | 12.0 |
| drop 1/3 | 127.2 | 119.1 | 79.4 | 6.36 |
| drop 2/3 | 126.5 | 126.1 | 42.0 | 0.339 |
| drop 3/3 | 126.5 | 126.1 | 0.01 | 0.341 |

## All survey measurements

| sweep | scenario | rules loaded | rules | traffic | frame | active flows | offered Mpps | absorbed Mpps | NIC loss % | cycles/pkt |
|---|---|---|---|---|---|---|---|---|---|---|
| rules | nrules-drop | 5 |  | fixed-flood-31 | 64 B | 0 | 127 | 127 | 0.321 | 120 |
| rules | nrules-drop | 1000 |  | fixed-flood-31 | 64 B | 0 | 127 | 127 | 0.322 | 138 |
| rules | nrules-drop | 10000 |  | fixed-flood-31 | 64 B | 0 | 127 | 127 | 0.329 | 138 |
| rules | nrules-drop | 100000 |  | fixed-flood-31 | 64 B | 0 | 127 | 127 | 0.325 | 154 |
| rules | nrules-drop | 983045 |  | fixed-flood-31 | 64 B | 0 | 127 | 127 | 0.322 | 159 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | udp-rand | 64 B | 26000 | 127 | 127 | 0.324 | 166 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | syn-flood | 64 B | 26000 | 127 | 111.7 | 12.4 | 88 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ack-flood | 64 B | 26000 | 127 | 111.7 | 12.4 | 88 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | icmp-flood | 64 B | 26000 | 127 | 112.2 | 12.0 | 87 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | frag-flood | 64 B | 26000 | 127 | 127 | 0.322 | 118 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 64 B | 26000 | 127 | 127 | 0.32 | 120 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | fwd-flood-32 | 64 B | 26000 | 127 | 112.1 | 12.0 | 152 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | tcp-flows-31 | 64 B | 26000 | 127 | 111.7 | 12.4 | 88 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan | 64 B | 26000 | 127 | 112.2 | 11.8 | 152 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-scatter | 64 B | 26000 | 127 | 112.2 | 11.9 | 152 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 26000 | 33.2 | 33.2 | 0.303 | 163 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ipv6-flood | 64 B | 26000 | 127 | 127 | 0.329 | 164 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ip6-cold-scan | 64 B | 26000 | 127 | 112.1 | 12.1 | 147 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | reflection-mix | mixed sizes | 26000 | 24.5 | 19.3 | 21.3 | 168 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | multivector | 64 B | 26000 | 127 | 25.5 | 80.0 | 236 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-sizes | mixed sizes | 26000 | 17.6 | 17.6 | 0.285 | 171 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-protos | 64 B | 26000 | 127 | 31.5 | 75.3 | 221 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-udptcp | 64 B | 26000 | 127 | 24.9 | 80.5 | 257 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-burst | 64 B | 26000 | 12.5 | 12.5 | 0.275 | 228 |
| attacks | 1m-rules-drop |  | 983,045 rules | udp-rand | 64 B | 26000 | 127 | 127 | 0.322 | 191 |
| attacks | 1m-rules-drop |  | 983,045 rules | syn-flood | 64 B | 26000 | 127 | 118.9 | 6.7 | 140 |
| attacks | 1m-rules-drop |  | 983,045 rules | ack-flood | 64 B | 26000 | 127 | 118.9 | 6.71 | 140 |
| attacks | 1m-rules-drop |  | 983,045 rules | icmp-flood | 64 B | 26000 | 127 | 119.4 | 6.32 | 139 |
| attacks | 1m-rules-drop |  | 983,045 rules | frag-flood | 64 B | 26000 | 127 | 127 | 0.322 | 159 |
| attacks | 1m-rules-drop |  | 983,045 rules | fixed-flood-31 | 64 B | 26000 | 127 | 127 | 0.327 | 159 |
| attacks | 1m-rules-drop |  | 983,045 rules | fwd-flood-32 | 64 B | 26000 | 127 | 112.1 | 12.0 | 181 |
| attacks | 1m-rules-drop |  | 983,045 rules | tcp-flows-31 | 64 B | 26000 | 127 | 118.9 | 6.71 | 140 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 26000 | 127 | 127 | 0.324 | 230 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan-scatter | 64 B | 26000 | 127 | 127 | 0.323 | 213 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 26000 | 33.2 | 33.2 | 0.305 | 177 |
| attacks | 1m-rules-drop |  | 983,045 rules | ipv6-flood | 64 B | 26000 | 127 | 127 | 0.323 | 163 |
| attacks | 1m-rules-drop |  | 983,045 rules | ip6-cold-scan | 64 B | 26000 | 127 | 112.1 | 12.1 | 146 |
| attacks | 1m-rules-drop |  | 983,045 rules | reflection-mix | mixed sizes | 26000 | 24.5 | 24.5 | 0.299 | 208 |
| attacks | 1m-rules-drop |  | 983,045 rules | multivector | 64 B | 26000 | 127 | 27.9 | 78.1 | 455 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-sizes | mixed sizes | 26000 | 17.6 | 17.6 | 0.291 | 252 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-protos | 64 B | 26000 | 127 | 34.3 | 73.1 | 373 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-udptcp | 64 B | 26000 | 127 | 26.1 | 79.5 | 518 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-burst | 64 B | 26000 | 13 | 13 | 0.276 | 503 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | fixed-flood-31 | 64 B | 26000 | 127 | 119.4 | 6.33 | 119 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | cold-scan | 64 B | 26000 | 127 | 127 | 0.329 | 116 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | multivector | 64 B | 26000 | 127 | 26.8 | 79.0 | 397 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | fixed-flood-31 | 64 B | 26000 | 127 | 112.2 | 12.0 | 67 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | cold-scan | 64 B | 26000 | 127 | 112.3 | 11.9 | 66 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | multivector | 64 B | 26000 | 127 | 25.5 | 80.0 | 160 |
| scenarios | multivector |  | rules for several attack families at once | fixed-flood-31 | 64 B | 26000 | 127 | 119.4 | 6.3 | 253 |
| scenarios | multivector |  | rules for several attack families at once | cold-scan | 64 B | 26000 | 127 | 127.1 | 0.328 | 303 |
| scenarios | multivector |  | rules for several attack families at once | multivector | 64 B | 26000 | 127 | 33.5 | 73.7 | 643 |
| scenarios | tsweep |  | rule-diversity sweep | fixed-flood-31 | 64 B | 26000 | 127 | 119.4 | 6.33 | 119 |
| scenarios | tsweep |  | rule-diversity sweep | cold-scan | 64 B | 26000 | 127 | 127 | 0.322 | 115 |
| scenarios | tsweep |  | rule-diversity sweep | multivector | 64 B | 26000 | 127 | 27.9 | 78.1 | 313 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | fixed-flood-31 | 64 B | 26000 | 127 | 127 | 0.321 | 125 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | cold-scan | 64 B | 26000 | 127 | 127 | 0.327 | 125 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | multivector | 64 B | 26000 | 127 | 26.8 | 78.9 | 232 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | fixed-flood-31 | 64 B | 26000 | 127 | 127 | 0.334 | 351 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | cold-scan | 64 B | 26000 | 127 | 127 | 0.339 | 350 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | multivector | 64 B | 26000 | 127 | 26.9 | 78.9 | 453 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 1000 | 127 | 127 | 0.323 | 142 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 10000 | 127 | 127 | 0.321 | 145 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 26000 | 127 | 127 | 0.323 | 231 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 32000 | 127 | 127 | 0.323 | 260 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 50000 | 127 | 127 | 0.324 | 319 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 100000 | 127 | 127 | 0.324 | 394 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 500000 | 127 | 125.6 | 1.48 | 428 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 983040 | 127 | 126 | 1.22 | 424 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 1000 | 127 | 127 | 0.322 | 107 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 10000 | 127 | 127 | 0.325 | 108 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 26000 | 127 | 127 | 0.323 | 112 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 32000 | 127 | 127 | 0.323 | 115 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 50000 | 127 | 127 | 0.324 | 165 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 100000 | 127 | 127 | 0.323 | 187 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 500000 | 127 | 127 | 0.325 | 208 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 983040 | 127 | 127 | 0.328 | 208 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 64 B |  | 127 | 127 | 0.328 | 120 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 64 B |  | 127 | 112.1 | 12.0 | 66 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 128 B |  | 82.2 | 82.3 | 0.338 | 120 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 128 B |  | 82.2 | 82.1 | 0.468 | 68 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 256 B |  | 44.7 | 44.7 | 0.321 | 124 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 256 B |  | 44.6 | 44.7 | 0.326 | 69 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 512 B |  | 23.3 | 23.3 | 0.308 | 130 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 512 B |  | 23.3 | 23.3 | 0.302 | 75 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 1024 B |  | 11.9 | 11.9 | 0.27 | 138 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 1024 B |  | 11.9 | 11.9 | 0.274 | 84 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 1500 B |  | 8.2 | 8.2 | 0.246 | 145 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 1500 B |  | 8.2 | 8.2 | 0.241 | 91 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-imix | IMIX 7:4:1 |  | 33.2 | 33.2 | 0.309 | 164 |
| frames | 0rules |  | no rules (forwarding baseline) | cold-scan-imix | IMIX 7:4:1 |  | 33.2 | 33.2 | 0.317 | 74 |

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
