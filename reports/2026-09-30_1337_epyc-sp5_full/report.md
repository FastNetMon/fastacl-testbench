# FastACL hardware bench: epyc-sp5, full suite

**CALIBRATION RUN (no verdict)**: 8 checks passed, 1 failed, 97 recorded measurements. 2026-09-30 13:37 UTC.

| | |
|---|---|
| Topology | 2-node: lava (TRex) cabled back to back to epyc-sp5, no switch |
| DUT CPU | AMD EPYC 9534 64-Core Processor (128 CPUs) |
| DUT NIC | Mellanox Technologies MT43244 BlueField-3 integrated ConnectX-7 network controller (rev 01), link 100 Gbps |
| DUT kernel | 6.8.0-139-generic |
| Generator | AMD Ryzen 9 9950X 16-Core Processor (32 CPUs), Mellanox Technologies MT28800 Family [ConnectX-5 Ex], TRex 3.06 |
| VPP | v25.10-release, 32 worker threads, RX/TX ring 4096/4096 |
| FastACL | 0.6.0 from release v0.6.0, licence evaluation (30-day maximum) (expires 2026-10-29) |
| Testbench | 64682b4 |
| Run | local |

## Summary

### Rules (64 B, drop)

| rules | traffic | offered Mpps | absorbed Mpps | cycles/pkt | limited by |
|---|---|---|---|---|---|
| 5 | fixed-flood-31 | 142 | 142 | 92 | offered rate |
| 1000 | fixed-flood-31 | 142 | 142 | 99 | offered rate |
| 10000 | fixed-flood-31 | 142 | 142 | 100 | offered rate |
| 100000 | fixed-flood-31 | 142 | 142 | 116 | offered rate |
| 983045 | fixed-flood-31 | 142 | 142 | 117 | offered rate |

### Attack types (64 B unless the profile says otherwise)

| traffic | 5 rules: offered | absorbed Mpps | cyc/pkt | limited by | 983K rules: offered | absorbed Mpps | cyc/pkt | limited by |
|---|---|---|---|---|---|---|---|---|
| udp-rand | 142 | 142 | 126 | offered rate | 142 | 142 | 142 | offered rate |
| syn-flood | 97 | 96.8 | 61 | generator | 96.6 | 96.5 | 105 | generator |
| ack-flood | 96.6 | 96.5 | 61 | generator | 96.8 | 96.7 | 105 | generator |
| icmp-flood | 136.6 | 136.7 | 60 | generator | 136.5 | 136.5 | 104 | generator |
| frag-flood | 142 | 142 | 85 | offered rate | 142 | 142 | 116 | offered rate |
| fixed-flood-31 | 142 | 142 | 86 | offered rate | 142 | 142 | 117 | offered rate |
| fwd-flood-32 | 100.2 | 100.1 | 115 | generator | 100.3 | 100.3 | 131 | generator |
| tcp-flows-31 | 96.6 | 96.5 | 61 | generator | 96.8 | 96.6 | 106 | generator |
| cold-scan | 100 | 99.9 | 115 | generator | 142 | 142 | 107 | offered rate |
| cold-scan-scatter | 99.8 | 99.7 | 115 | generator | 142 | 142 | 107 | offered rate |
| cold-scan-imix | 31.6 | 31.6 | 122 | offered rate | 32.9 | 32.9 | 128 | offered rate |
| ipv6-flood | 142 | 142 | 131 | offered rate | 142 | 142 | 131 | offered rate |
| ip6-cold-scan | 108.6 | 108.1 | 115 | generator | 109 | 108.9 | 115 | generator |
| reflection-mix | 12.2 | 12.2 | 138 | offered rate | 12.2 | 12.2 | 167 | offered rate |
| multivector | 82.1 | 82.2 | 145 | generator | 97 | 97 | 300 | generator |
| mix-sizes | 17.6 | 17.6 | 132 | offered rate | 17.6 | 17.6 | 194 | offered rate |
| mix-protos | 119.4 | 119.3 | 136 | generator | 142 | 133.5 | 237 | DUT |
| mix-udptcp | 97.7 | 97.5 | 138 | generator | 142 | 141.4 | 275 | offered rate |
| mix-burst | 11.1 | 11.1 | 250 | generator | 11.3 | 11.3 | 507 | generator |

### Active flows (983K rules, 64 B, drop)

| active flows | IPv4 Mpps | IPv4 cyc/pkt | IPv6 Mpps | IPv6 cyc/pkt | limited by |
|---|---|---|---|---|---|
| 1000 | 142 | 98 | 142 | 75 | offered rate |
| 10000 | 142 | 103 | 142 | 77 | offered rate |
| 26000 | 142 | 107 | 142 | 79 | offered rate |
| 32000 | 142.1 | 110 | 142 | 79 | offered rate |
| 50000 | 142 | 126 | 142 | 83 | offered rate |
| 100000 | 142.1 | 196 | 142 | 102 | offered rate |
| 500000 | 142 | 342 | 142 | 149 | offered rate |
| 983040 | 142 | 369 | 142 | 153 | offered rate |

- IPv4: the offered rate is held up to 983,040 active flows.
- IPv6: the offered rate is held up to 983,040 active flows.

### Packet size (1 × 100G ingress)

| frame | drop Mpps | drop Gbps (wire) | drop limited by | forward Mpps | forward Gbps (wire) | forward limited by |
|---|---|---|---|---|---|---|
| 64 B | 142 | 100.0 | offered rate | 100.5 | 70.8 | generator |
| 128 B | 82.3 | 100.1 | offered rate | 57.1 | 69.4 | generator |
| 256 B | 44.3 | 99.2 | offered rate | 41.9 | 93.9 | generator |
| 512 B | 23.3 | 99.9 | offered rate | 23.3 | 99.9 | offered rate |
| 1024 B | 11.9 | 99.8 | offered rate | 11.9 | 99.8 | offered rate |
| 1500 B | 8.2 | 100.0 | offered rate | 8.2 | 100.0 | offered rate |
| IMIX 7:4:1 | 31.6 | 95.5 | offered rate | 31.5 | 95.2 | offered rate |

*limited by*: **DUT** = the DUT absorbed less than was offered; **offered rate** = the generator reached its target and the DUT absorbed all of it; **generator** = the generator could not reach its target, so the DUT's limit is higher than shown.

## Method

- Frames are sized before FCS: 64 B means 68 B on the wire, so 100 % of 100 GbE is 142.05 Mpps.
- Fixed-size traffic is offered at 142 Mpps; mixed-size traffic is offered at 95 Gbps (a packet rate is only a fixed bit rate when every frame is the same size).
- **absorbed Mpps**: packets the DUT received and processed per second (dropped by a rule or forwarded), from counter deltas over the sample window.
- **NIC loss %**: packets that reached the DUT port but never reached VPP (`rx_phy - rx_good`), i.e. lost inside the adapter.
- **cycles/pkt**: CPU cycles the `fastacl-filter` node spends per packet (`show runtime`).
- A gate passes when every value is within its limit; survey and ceiling rows are recorded without a verdict.
- Trials: oneport 5 s warm-up, 10 s sample; flows 20 s warm-up, 30 s sample; survey 10 s warm-up, 15 s sample; ceiling 5 s warm-up, 15 s sample per row.
- Full methodology: [test strategy](https://github.com/FastNetMon/fastacl-testbench/blob/main/docs/test-strategy.md).

## One-port gates (drop and forward)

| scenario | rules | traffic | frame | offered Mpps | absorbed Mpps | floor Mpps | NIC loss % | loss limit % | cycles/pkt | cycle limit | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 5rules-drop | 5 hot port-range drop rules | fixed-flood-31 | 64 B | 142 | 141.4 | 120 | 0.4 | 1 | 85.4 | 130 | PASS |
| 0rules | no rules (forwarding baseline) | fixed-flood-31 | 64 B | 127 | 90.1 | 120 | 0.561 | 1 | 46 | 70 | FAIL |
| country-set-drop | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | fixed-flood-31 | 64 B | 142 | 141.5 | 120 | 0.415 | 1 | 82.4 | 160 | PASS |

## Prefix-set tuple count

| scenario | rules | tuples | limit | verdict |
|---|---|---|---|---|
| country-set-drop | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | 1 | 1 | PASS |

## Working-set gates (simultaneously active flows)

| scenario | rules | traffic | frame | active flows | offered Mpps | absorbed Mpps | floor Mpps | NIC loss % | loss limit % | cycles/pkt | cycle limit | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1m-rules-drop | 983,045 rules | cold-scan | 64 B | 32000 | 142 | 141.8 | 124 | 0.166 | 0.6 | 110 | 330 | PASS |
| 1m-rules-drop | 983,045 rules | cold-scan-scatter | 64 B | 32000 | 142 | 142 | 124 | 0.164 | 0.6 | 110 | 330 | PASS |
| 1m-rules-drop | 983,045 rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 32000 | 33 | 33 | 30 | 0.153 | 0.6 | 134 | 900 | PASS |
| 1m-rules-drop-ip6 | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 56000 | 142 | 142 | 124 | 0.162 | 0.6 | 85 | 330 | PASS |

## psample sampling under load

| traffic | verdict |
|---|---|
| fixed-flood-31 | PASS |

## Ceiling proof (ingress vs egress budget)

| egress streams dropped | offered Mpps | RX Mpps | TX Mpps | NIC loss % |
|---|---|---|---|---|
| drop 0/3 | 100.5 | 100.0 | 100.0 | 0.455 |
| drop 1/3 | 100.4 | 100.0 | 66.7 | 0.447 |
| drop 2/3 | 124.9 | 124.5 | 41.5 | 0.366 |
| drop 3/3 | 142 | 141.6 | 0.01 | 0.322 |

## All survey measurements

| sweep | scenario | rules loaded | rules | traffic | frame | active flows | offered Mpps | absorbed Mpps | NIC loss % | cycles/pkt |
|---|---|---|---|---|---|---|---|---|---|---|
| rules | nrules-drop | 5 |  | fixed-flood-31 | 64 B | 0 | 142 | 142 | 0.302 | 92 |
| rules | nrules-drop | 1000 |  | fixed-flood-31 | 64 B | 0 | 142 | 142 | 0.318 | 99 |
| rules | nrules-drop | 10000 |  | fixed-flood-31 | 64 B | 0 | 142 | 142 | 0.302 | 100 |
| rules | nrules-drop | 100000 |  | fixed-flood-31 | 64 B | 0 | 142 | 142 | 0.299 | 116 |
| rules | nrules-drop | 983045 |  | fixed-flood-31 | 64 B | 0 | 142 | 142 | 0.302 | 117 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | fixed-flood-31 | 64 B | 26000 | 100.8 | 100.7 | 0.426 | 94 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | cold-scan | 64 B | 26000 | 142 | 142 | 0.304 | 77 |
| scenarios | 1m-rules-drop-proto |  | 983,040 rules | multivector | 64 B | 26000 | 77.3 | 77.4 | 0.375 | 243 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | fixed-flood-31 | 64 B | 26000 | 100.3 | 100.2 | 0.423 | 46 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | cold-scan | 64 B | 26000 | 99.5 | 99.4 | 0.43 | 46 |
| scenarios | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | multivector | 64 B | 26000 | 79.7 | 79.7 | 0.363 | 99 |
| scenarios | multivector |  | rules for several attack families at once | cold-scan | 64 B | 26000 | 142 | 142 | 0.302 | 178 |
| scenarios | multivector |  | rules for several attack families at once | multivector | 64 B | 26000 | 92 | 92.1 | 0.318 | 364 |
| scenarios | tsweep |  | rule-diversity sweep | fixed-flood-31 | 64 B | 26000 | 100.7 | 100.6 | 0.426 | 93 |
| scenarios | tsweep |  | rule-diversity sweep | cold-scan | 64 B | 26000 | 142 | 142 | 0.303 | 77 |
| scenarios | tsweep |  | rule-diversity sweep | multivector | 64 B | 26000 | 97 | 97 | 0.3 | 204 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | fixed-flood-31 | 64 B | 26000 | 142 | 142.1 | 0.297 | 86 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | cold-scan | 64 B | 26000 | 142 | 142 | 0.304 | 86 |
| scenarios | country-set-drop |  | 20,000 source prefixes (/10 to /24) in one named set, one drop rule | multivector | 64 B | 26000 | 77.2 | 77.2 | 0.373 | 162 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | fixed-flood-31 | 64 B | 26000 | 142 | 142 | 0.3 | 236 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | cold-scan | 64 B | 26000 | 142 | 142 | 0.307 | 236 |
| scenarios | country-rules-drop |  | the same 20,000 source prefixes as one rule each | multivector | 64 B | 26000 | 77.6 | 77.6 | 0.383 | 303 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 1000 | 142 | 142 | 0.307 | 98 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 10000 | 142 | 142 | 0.307 | 103 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 26000 | 142 | 142 | 0.306 | 107 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 32000 | 142 | 142.1 | 0.305 | 110 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 50000 | 142 | 142 | 0.302 | 126 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 100000 | 142 | 142.1 | 0.302 | 196 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 500000 | 142 | 142 | 0.303 | 342 |
| flows | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 983040 | 142 | 142 | 0.303 | 369 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 1000 | 142 | 142 | 0.3 | 75 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 10000 | 142 | 142 | 0.303 | 77 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 26000 | 142 | 142 | 0.302 | 79 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 32000 | 142 | 142 | 0.315 | 79 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 50000 | 142 | 142 | 0.312 | 83 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 100000 | 142 | 142 | 0.31 | 102 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 500000 | 142 | 142 | 0.31 | 149 |
| flows | 1m-rules-drop-ip6 |  | 983,040 IPv6 rules | ip6-cold-scan | 64 B | 983040 | 142 | 142 | 0.31 | 153 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 128 B |  | 82.2 | 82.3 | 0.309 | 88 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 128 B |  | 57.1 | 57.1 | 0.439 | 48 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 256 B |  | 44.3 | 44.3 | 0.295 | 91 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 256 B |  | 41.9 | 41.9 | 0.318 | 49 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 512 B |  | 23.3 | 23.3 | 0.287 | 97 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 512 B |  | 23.3 | 23.3 | 0.283 | 55 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 1024 B |  | 11.9 | 11.9 | 0.251 | 106 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 1024 B |  | 11.9 | 11.9 | 0.302 | 66 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 1500 B |  | 8.2 | 8.2 | 0.224 | 116 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 1500 B |  | 8.2 | 8.2 | 0.222 | 77 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-imix | IMIX 7:4:1 |  | 31.6 | 31.6 | 0.304 | 122 |
| frames | 0rules |  | no rules (forwarding baseline) | cold-scan-imix | IMIX 7:4:1 |  | 31.6 | 31.6 | 0.308 | 53 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 64 B |  | 142 | 142 | 0.305 | 86 |
| frames | 0rules |  | no rules (forwarding baseline) | fixed-flood-31 | 64 B |  | 100.6 | 100.5 | 0.437 | 46 |
| frames | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-imix | IMIX 7:4:1 |  | 31.6 | 31.6 | 0.309 | 122 |
| frames | 0rules |  | no rules (forwarding baseline) | cold-scan-imix | IMIX 7:4:1 |  | 31.6 | 31.5 | 0.314 | 53 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | udp-rand | 64 B | 26000 | 142 | 142 | 0.31 | 126 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | syn-flood | 64 B | 26000 | 97 | 96.8 | 0.458 | 61 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ack-flood | 64 B | 26000 | 96.6 | 96.5 | 0.467 | 61 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | icmp-flood | 64 B | 26000 | 136.6 | 136.7 | 0.324 | 60 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | frag-flood | 64 B | 26000 | 142 | 142 | 0.309 | 85 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | fixed-flood-31 | 64 B | 26000 | 142 | 142 | 0.399 | 86 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | fwd-flood-32 | 64 B | 26000 | 100.2 | 100.1 | 0.441 | 115 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | tcp-flows-31 | 64 B | 26000 | 96.6 | 96.5 | 0.464 | 61 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan | 64 B | 26000 | 100 | 99.9 | 0.445 | 115 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-scatter | 64 B | 26000 | 99.8 | 99.7 | 0.443 | 115 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 26000 | 31.6 | 31.6 | 0.305 | 122 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ipv6-flood | 64 B | 26000 | 142 | 142 | 0.312 | 131 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | ip6-cold-scan | 64 B | 26000 | 108.6 | 108.1 | 0.416 | 115 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | reflection-mix | mixed sizes | 26000 | 12.2 | 12.2 | 0.256 | 138 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | multivector | 64 B | 26000 | 82.1 | 82.2 | 0.362 | 145 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-sizes | mixed sizes | 26000 | 17.6 | 17.6 | 0.271 | 132 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-protos | 64 B | 26000 | 119.4 | 119.3 | 0.373 | 136 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-udptcp | 64 B | 26000 | 97.7 | 97.5 | 0.459 | 138 |
| attacks | 5rules-drop |  | 5 hot port-range drop rules | mix-burst | 64 B | 26000 | 11.1 | 11.1 | 0.255 | 250 |
| attacks | 1m-rules-drop |  | 983,045 rules | udp-rand | 64 B | 26000 | 142 | 142 | 0.312 | 142 |
| attacks | 1m-rules-drop |  | 983,045 rules | syn-flood | 64 B | 26000 | 96.6 | 96.5 | 0.455 | 105 |
| attacks | 1m-rules-drop |  | 983,045 rules | ack-flood | 64 B | 26000 | 96.8 | 96.7 | 0.449 | 105 |
| attacks | 1m-rules-drop |  | 983,045 rules | icmp-flood | 64 B | 26000 | 136.5 | 136.5 | 0.324 | 104 |
| attacks | 1m-rules-drop |  | 983,045 rules | frag-flood | 64 B | 26000 | 142 | 142 | 0.315 | 116 |
| attacks | 1m-rules-drop |  | 983,045 rules | fixed-flood-31 | 64 B | 26000 | 142 | 142 | 0.311 | 117 |
| attacks | 1m-rules-drop |  | 983,045 rules | fwd-flood-32 | 64 B | 26000 | 100.3 | 100.3 | 0.439 | 131 |
| attacks | 1m-rules-drop |  | 983,045 rules | tcp-flows-31 | 64 B | 26000 | 96.8 | 96.6 | 0.454 | 106 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan | 64 B | 26000 | 142 | 142 | 0.31 | 107 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan-scatter | 64 B | 26000 | 142 | 142 | 0.309 | 107 |
| attacks | 1m-rules-drop |  | 983,045 rules | cold-scan-imix | IMIX 64/570/1518 B, 7:4:1 | 26000 | 32.9 | 32.9 | 0.291 | 128 |
| attacks | 1m-rules-drop |  | 983,045 rules | ipv6-flood | 64 B | 26000 | 142 | 142 | 0.31 | 131 |
| attacks | 1m-rules-drop |  | 983,045 rules | ip6-cold-scan | 64 B | 26000 | 109 | 108.9 | 0.401 | 115 |
| attacks | 1m-rules-drop |  | 983,045 rules | reflection-mix | mixed sizes | 26000 | 12.2 | 12.2 | 0.252 | 167 |
| attacks | 1m-rules-drop |  | 983,045 rules | multivector | 64 B | 26000 | 97 | 97 | 0.308 | 300 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-sizes | mixed sizes | 26000 | 17.6 | 17.6 | 0.272 | 194 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-protos | 64 B | 26000 | 142 | 133.5 | 6.28 | 237 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-udptcp | 64 B | 26000 | 142 | 141.4 | 0.741 | 275 |
| attacks | 1m-rules-drop |  | 983,045 rules | mix-burst | 64 B | 26000 | 11.3 | 11.3 | 0.245 | 507 |
| scenarios | multivector |  | rules for several attack families at once | fixed-flood-31 | 64 B | 26000 | 100.4 | 100.3 | 0.438 | 183 |

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
