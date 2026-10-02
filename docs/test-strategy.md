# FastACL Test Strategy

This document describes how FastACL is tested: what each layer of testing proves, the
topologies and methods behind every number, how pass/fail thresholds are set, and how results
are reported. It follows the structure of the FD.io CSIT test methodology. Topologies,
measurement types, packet sizes, trial rules and the reporting and trending model are each
defined once and referred to everywhere else.

## 1. Scope

FastACL is a VPP plugin that filters traffic against an RFC 8955/8956 FlowSpec rule set at
line rate. Testing has to show three things:

1. **Correctness.** Every match type, action, API message and CLI command behaves as specified,
   for IPv4 and IPv6, in both the routed and the bridged datapath.
2. **Robustness.** Malformed input, reconfiguration under traffic, licence edge cases and memory
   errors never crash VPP or corrupt its state.
3. **Performance.** The filter holds line rate on the reference hardware across rule counts,
   rule diversity, active-flow working sets, attack types and packet sizes, and the cost per
   packet stays within budget.

## 2. Test layers

| # | Layer | Where | Trigger | Build under test | Proves |
|---|-------|-------|---------|------------------|--------|
| L0 | Static | fastacl CI `checkstyle`, testbench `lint` | every push | source | clang-format; no lab secrets in the tree |
| L1 | Build + codegen | fastacl CI `package` | every push | throwaway-key .deb, VPP 25.10 and 26.06 | builds clean; hot node fits the L1 instruction cache |
| L2 | Functional | fastacl CI `test` | every push | throwaway-key .deb | 306 pytest cases (`test/` in the FastACL repository), run once per datapath (bridge, routed) |
| L3 | Sanitizers | fastacl CI `sanitize` | every push | clang `-fsanitize=address,alignment` build on an ASan VPP | no memory or alignment errors across the whole L2 suite |
| L4 | SW performance sanity | fastacl CI `test` (perf step) | every push | throwaway-key .deb | `test/test_perf.py` cycle and rule-scale trends, tracked by github-action-benchmark (alert at 130 %) |
| L5 | HW line-rate gate | testbench `hw-line-rate` (`suite=gate`) | on demand | **licensed release bundle** | floors on the reference DUTs (section 6) |
| L6 | HW full range | testbench `hw-line-rate` (`suite=full`) | on demand, per release | licensed release bundle | the whole matrix of section 5, published |
| L7 | DPU | testbench `hw-line-rate` (`dut=bluefield3`) | on demand | licensed arm64 release bundle | drop line rate on the BlueField-3 Arm cores |
| L8 | BNG pipeline | testbench `run.sh bluefield3 bng` | on demand | licensed arm64 release bundle | routed forwarding with a per-subscriber rate limit and NAT44-ED on the Arm cores; policer accuracy |
| L9 | Generator pair | testbench `run.sh alice pair` | on demand | none (TRex only) | what the alice/bob generators can send and receive, so DUT results are read against it |

L0–L4 need a FastACL build made with throwaway licence keys, so they run in the FastACL source
repository, next to the code they test. L5–L9 run here, in the `hw-line-rate` workflow of this
repository. They install the **same release bundle customers receive**: VPP debs plus a
plugin that trusts only the production licence key. The DUT therefore runs exactly what is
shipped, and nothing in this repository can build, fetch or unlock an unlicensed FastACL.

### 2.1 Functional suite (L2)

The suite lives in the FastACL repository under `test/`, organised by feature with one module
per area; its `test/README.md` lists every module and class. Rules that apply across the suite:

- **Every test runs in both datapaths.** `FASTACL_MODE=bridge` injects Ethernet frames on the
  `l2-input` arcs, and `FASTACL_MODE=routed` injects IP on the `ip4/ip6-unicast` arcs. Test bodies
  are mode-agnostic, and a mode-specific skip must say why.
- **Every negative assertion has a positive pair.** A "must not match" test is only meaningful
  next to a test proving the same rule does match its target.
- **Grammar and traffic are separate.** Parser tests prove the API or CLI accepts a rule;
  traffic tests prove the rule matches on packets.
- **No blind sleeps.** Injection waits on counters (`wait_for_injection`), so a pass means the
  packets were classified.
- **Licence enforcement is tested with real signatures**, including the vendor tool, the
  evaluation role cap, machine binding, tampering and expiry (`test_license.py`).

### 2.2 Sanitizers (L3)

The L2 suite is rebuilt with clang `-fsanitize=address,alignment` and run against an
ASan-instrumented VPP. The job checks that both families of checks are present in the plugin
and that no sanitizer runtime is linked twice, so the gate cannot silently check nothing.

## 3. Topologies

HW testing uses CSIT's **2-node topology (2n)**: one traffic generator (TG) and one device under
test (DUT), connected back to back by 100 GbE DACs, with no switch in between.

```
  TG (TRex)                                  DUT (VPP + FastACL)
  sender  port ──────── 100G DAC ────────►  eth-left   (ingress, filtered)
  receiver port ◄─────── 100G DAC ────────  eth-right  (egress, forwarded)
```

| Topology | TG | DUT | NIC on the DUT | Used by |
|----------|----|-----|----------------|---------|
| `2n-rome-cx7` | flame1 | server1, AMD EPYC 7742 (Rome) | ConnectX-7, dual port | L5, L6 |
| `2n-genoa-bf3` | lava1 | epyc-sp5, AMD EPYC 9534 (Genoa) | BlueField-3 in NIC mode (host owns the ports) | L5, L6 |
| `2n-bf3-arm` | lava1 | BlueField-3 Arm, 16× Cortex-A78 | BlueField-3 in DPU mode (Arm owns the ports) | L7, L8 |
| `2n-zen5-cx8` | bob or alice | alice or bob, AMD Ryzen 9 9950X | ConnectX-8, dual port, 400G | L6, L9 |

The DUT runs **bridged**: an L2 cross-connect with FastACL on the `l2-input` arcs. Lab machines, cabling
and access are described in `docs/lab.md`.

## 4. Methodology

### 4.1 Measurement types

| Type | Definition | FastACL use |
|------|------------|-------------|
| **MRR**, maximum receive rate | offer a fixed load, measure what the DUT absorbs (drop path) or forwards (forward path) | every gate and survey point |
| **Floor** | a minimum absorbed rate for an MRR measurement at a pinned offered load | the pass condition of a gate |
| **Loss ratio** | `(rx_phy − rx_good) / rx_phy` at the DUT ingress port: loss inside the adapter before VPP sees the packet | gates on the adapter keeping up |
| **Cost** | `fastacl-filter` clocks per packet from `show runtime`, in the same window | budget gates; catches regressions before they cost throughput |
| **Ceiling proof** | at a fixed offered load, drain egress stream by stream and watch ingress | separates a device limit from a host limit |

CSIT's NDR/PDR binary search is not used. The DUT's limit is set by the adapter, and at a fixed
offered load the drop path shows a load-independent loss floor. A pinned MRR plus a loss ceiling
is more repeatable than a search on this hardware, and it is what the reference results use.

### 4.2 Packet sizes and rates

- **64 B means 64 B before FCS**, 68 B on the wire, so 100 % of 100 GbE line rate is
  **142.05 Mpps**.
- **Fixed-size profiles are pinned by packet rate** (`TREX_TARGET_MPPS`). The rate is chosen per
  topology as the highest load the adapter carries without load-dependent loss: 127 Mpps on
  `2n-rome-cx7`, and 142 Mpps on `2n-genoa-bf3`, where the Gen5 BF-3 carries full line rate.
- **Mixed-size profiles (IMIX 7:4:1, average 354 B) are pinned by bit rate** (95 Gbps). A packet
  rate is only a fixed bit rate when every frame is the same size.
- **Forwarding is offered below the device ceiling.** On `2n-rome-cx7`, forwarding offers 105
  Mpps because the dual-port adapter moves each packet twice and clips at ~111.5 Mpps.

### 4.3 Trials

| Suite | Warm-up | Sample |
|-------|---------|--------|
| one-port gates | 5 s | 10 s |
| working-set gates | 20 s | 30 s |
| surveys | 10 s | 15 s |
| DPU | 4 s | 15 s |

Rates are deltas of interface and node counters over the sample window. They are never
instantaneous readings.

### 4.4 Traffic profiles

Profiles are defined in `labs/hw/gen/conf/attacks.py`. They include the volumetric floods
(`udp-rand`, `syn-flood`, `ack-flood`, `icmp-flood`, `frag-flood`, `ipv6-flood`), fixed-flow and
Toeplitz-balanced sets (`fixed-flood-31`, `fwd-flood-32`, `tcp-flows-31`), working-set scans
(`cold-scan`, `cold-scan-scatter`, `cold-scan-imix`, `ip6-cold-scan`), and mixes
(`reflection-mix`, `multivector`, `mix-sizes`, `mix-protos`, `mix-udptcp`, `mix-burst`).

### 4.5 Rule scenarios

Scenarios are loaded through the binary API by `labs/hw/dut/load-scenario.py`:

| Scenario | Rules |
|----------|-------|
| `0rules` | none: the forwarding baseline |
| `5rules-drop` | 5 hot port-range rules |
| `1m-rules-drop` | 983,040 cold /24 rules plus 5 hot rules |
| `1m-rules-drop-ip6` | the IPv6 equivalent |
| `1m-rules-drop-proto` | destination + protocol rules (the folded compact key) |
| `tsweep` | rule diversity: many distinct mask shapes |
| `multivector` | several attack families at once |
| `country-set-drop` / `country-rules-drop` | a country prefix list as one named set / as individual rules |
| `5rules-ratelimit-conform` / `-exceed` | the rate-limit action |

## 5. Test matrix

| Suite | Test | Scenario × profile | Pass condition |
|-------|------|--------------------|----------------|
| gate | one-port drop | `5rules-drop` × `fixed-flood-31` | absorbed ≥ floor, loss ≤ 1 %, cost ≤ budget, dropped inside the node |
| gate | one-port forward | `0rules` × `fixed-flood-31` at the forward rate | forwarded ≥ floor, cost ≤ budget, forwarded onward |
| gate | prefix sets | `country-set-drop` × `fixed-flood-31` | rate and cost gates, plus the set costs exactly one tuple |
| gate | working set, IPv4 | `1m-rules-drop` × `cold-scan`, and × `cold-scan-scatter`, at 32k flows | absorbed ≥ floor, loss ≤ 0.6 %, cost ≤ budget |
| gate | working set, IMIX | `1m-rules-drop` × `cold-scan-imix` | absorbed ≥ floor, cost ≤ budget |
| gate | working set, IPv6 | `1m-rules-drop-ip6` × `ip6-cold-scan` at 56k flows | absorbed ≥ floor, cost ≤ budget |
| gate | psample | sampling action under load | samples delivered, zero send failures |
| full | ceiling proof | `0rules` → 3 drop rules × `fixed-flood-31` | recorded |
| full | attack survey | every scenario in `FULL_SCENARIOS` × every profile | recorded |
| full | working-set sweep | `1m-rules-drop` × `cold-scan`, and IPv6, at 1k … 983k flows | recorded |
| dpu | drop line rate | UDP drop at 64 B, IMIX, 1500 B | absorbed ≥ floor |

"Recorded" results carry no verdict. They are the published performance data, and the source of
new floors.

## 6. Thresholds and calibration

- **Thresholds live in one place per DUT**: `labs/hw/profiles/<dut>.env`. The workflow and
  `labs/hw/suite.sh` read nothing else.
- **A floor is set from measurement, never from a target.** It sits below the measured value by
  the run-to-run spread plus a margin, and it must sit close enough that a real regression fails
  it. A floor that can never fail documents nothing.
- **New hardware starts in calibration mode** (`CALIBRATE=1` in its profile, or the `calibrate`
  workflow input). The full suite runs and the report is published, but it carries no verdict.
  Floors are written into the profile from that report, and `CALIBRATE` is then set to 0.
  epyc-sp5 was calibrated from its first full run on 2026-09-30 (FastACL v0.6.0).
- **The generator is part of the rig.** On `2n-genoa-bf3`, lava1 sustains about 200 Mpps of
  transmit plus receive. While it also receives the forwarded traffic, a throttled TRex delivers
  about 71 % of the rate it is asked for (100 → 72.5, 120 → 85, 142 → 99.3 Mpps, measured
  2026-09-30), so the forwarding gate leaves the generator unthrottled at 142 Mpps and expects
  about 100 Mpps back. Reports mark any point where the generator, not the DUT, set the rate
  ("limited by: generator").
- **Recalibrate when the rig changes**: a card swap, firmware, BIOS, generator, cabling or the
  VPP version. Do not recalibrate because a gate failed. A failed gate is first compared with
  the previous release on the same rig. Only when both fail the same way is the rig suspect.
- **Suspect the rig before the plugin.** Adapter loss with `rx_prio0_buf_discard` climbing while
  `rx_out_of_buffer` stays flat is an adapter DMA limit, not a FastACL regression. The reports
  carry both counters for that reason.

## 7. Reporting and trending

Every HW run writes a report automatically when it ends, including when it fails:

- `report.md`: rig, release tag, plugin version, and every measurement with its verdict. It is
  shown in the workflow run summary.
- `results.csv` and `run.jsonl`: the same data, machine-readable.
- An artifact on the workflow run. A **full** suite run also commits
  **`reports/<date>_<time UTC>_<rig>_full/`** to `main`, holding `report.md`, `results.csv` and `run.jsonl`, indexed by `reports/README.md`; gate runs are not published. Each report shows how FastACL performs and exactly how it
  was measured.

The floors of each rig come from its calibration run, which is itself a published report in
`reports/`.

## 8. Reproducing a run

The HW suites need only a licensed FastACL release bundle and a lab with the topology of
section 3:

1. Copy `labs/hw/lab.env.example` to `labs/hw/lab.env` and fill in your hosts.
2. Extract the release bundle into `bundle/`.
3. Put your licence in `labs/hw/license/`. Without one, the bundle's evaluation licence is used.
4. Run `labs/hw/dut-image.sh` on the DUT, `labs/hw/bringup-guarded.sh`, start TRex, and then:

```sh
PROFILE=<your-profile> labs/hw/suite.sh full
python3 labs/hw/report.py results/run.jsonl --out-dir out
```

## 9. Traceability

| Requirement source | Covered by |
|--------------------|------------|
| RFC 8955/8956 match types 1–12, IPv4 and IPv6 | L2 `test_fastacl.py`, `test_dual_stack_scope.py`, `test_truncated_l4_fields.py` |
| Actions: drop, permit, DSCP mark, rate limit, sampling | L2 `test_action_rewrite.py`, `test_permit_action.py`, `test_sampling.py`; L5 psample |
| Binary API and CLI | L2 `test_api_edge.py`, `test_reconciliation.py` |
| Named prefix sets | L2 `test_sets.py`; L5 prefix-set gate |
| Licensing | L2 `test_license.py` |
| Line rate with ~1M rules and a large working set | L5 working-set gates; L6 sweeps |
| Monthly acceptance criteria | `docs/fastacl-month*-spec.md` in the FastACL repository |
