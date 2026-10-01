# FastACL hardware bench reports

Every **full-suite** run of the `hw-line-rate` workflow (or of `labs/hw/run.sh <rig> full`)
publishes one folder here, named `<date>_<time UTC>_<rig>_<suite>`. Gate runs are not
published; they keep their report in the workflow summary and as a run artifact.

Each run measures the **licensed FastACL release bundle** that customers receive, on one of the
reference rigs. Methodology, topology and thresholds: [test strategy](../docs/test-strategy.md),
[lab](../docs/lab.md).

| Rig | DUT | Generator |
|---|---|---|
| `server1` | AMD EPYC 7742 (64 cores), ConnectX-7, VPP on x86 | Ryzen 7 5800X + ConnectX-7, TRex |
| `epyc-sp5` | AMD EPYC 9534 (64 cores), BlueField-3 in NIC mode, VPP on x86 | Ryzen 9 9950X + 2× ConnectX-5 Ex, TRex |
| `bluefield3` | BlueField-3 Arm (16× Cortex-A78AE) in DPU mode, VPP on the Arm cores | Ryzen 9 9950X + 2× ConnectX-5 Ex, TRex |

## What is in a report folder

### `report.md` — the human-readable report

| Section | Contents |
|---|---|
| Verdict line | **PASS**, **FAIL** or **CALIBRATION RUN**, with the number of gate checks passed and failed, recorded measurements, and the run start time |
| Rig table | topology, DUT CPU and core count, NIC and link speed, kernel, generator CPU and NIC, TRex version, VPP version, worker threads and ring sizes, FastACL version and release tag, licence type and expiry, testbench commit, workflow run link |
| Summary | the headline tables: rules sweep, attack types (5 rules vs 983K rules), active flows (IPv4 and IPv6), packet size (drop and forward, Mpps and wire Gbps); on `bluefield3`, the per-frame-size drop rate on the Arm cores. Each row says what limited it: the DUT, the offered rate, or the generator |
| Method | frame-size convention, offered rates, the meaning of every metric, trial warm-up and sample lengths |
| Gate sections | one table per gate with value, limit and verdict: one-port drop and forward, prefix-set tuple count, working-set (active flows, IPv4, IPv6, IMIX), psample sampling under load, ceiling proof, BlueField-3 drop line rate |
| All survey measurements | every point of the rule, attack, scenario, flow and frame-size sweeps |
| Scenarios and traffic | what each rule set and traffic profile used in the run contains |

### `results.csv` — one row per measurement

The same data as the report, one row per measurement (the rig description is only in
`run.jsonl`). Empty cells mean the column does not apply to that test.

| Column | Meaning |
|---|---|
| `ts` | Unix time of the measurement |
| `dut`, `gen` | rig name and generator name |
| `bench` | test type (see below) |
| `sweep` | survey dimension: `rules`, `attacks`, `scenarios`, `flows` or `frames` |
| `scenario` | rule set loaded on the DUT |
| `rules` | description of that rule set |
| `nrules` | number of rules loaded (rule-count sweep) |
| `attack` | traffic profile |
| `frame` | frame size (pre-FCS) or `IMIX 7:4:1` |
| `flows` | simultaneously active flows offered |
| `offered_mpps` | rate the generator sent, Mpps |
| `dut_mpps` | rate the DUT received and processed (dropped by a rule or forwarded), Mpps |
| `tx_mpps` | rate the DUT transmitted (ceiling proof), Mpps |
| `nic_lost_pct` | packets that reached the DUT port but never reached VPP, % |
| `cyc_pkt` | cycles per packet in the filter node |
| `tuples` | tuples created by a prefix set |
| `floor`, `max_cyc`, `max_nic_lost_pct`, `max_tuples` | the gate limits the value was checked against |
| `verdict` | `PASS`, `FAIL` or `INFO` (recorded without a limit) |
| `detail` | the reason behind the verdict |

### `run.jsonl` — raw records

One JSON object per line, exactly as the bench wrote it during the run, including the rig record.
This is the source the other two files are generated from (`labs/hw/report.py`).

| `bench` | Record |
|---|---|
| `rig` | DUT and generator hardware, kernel, link speed, VPP and FastACL versions, workers, ring sizes, TRex version, target rates, licence |
| `oneport` | one-port drop or forward gate at a fixed offered rate |
| `sets-tuples` | tuple count of a prefix-set scenario |
| `flows` | working-set gate: a number of simultaneously active flows |
| `psample` | packet sampling delivered to the host under load |
| `ceiling` | ingress vs egress budget of the rig (generator capability) |
| `survey` | one point of a sweep, recorded without a verdict |
| `dpu` | BlueField-3 drop rate on the Arm cores for one frame size |
| `load` | a setup step that failed (bring-up, rule load, mode switch); always `FAIL` |

## Units and conventions

- Frame sizes are **pre-FCS**: 64 B is 68 B on the wire, so 100 % of 100 GbE is 142.05 Mpps.
- Wire Gbps counts frame + 24 B (FCS, preamble, inter-frame gap).
- `cyc_pkt` is CPU TSC cycles on x86; on `bluefield3` it is Arm generic-timer ticks (330 MHz),
  about 6.5 core cycles each at the A78AE's 2.13 GHz.
- A **calibration run** records everything without a verdict; its numbers set the rig's floors.

## Index

| Report | Rig | Suite | FastACL | VPP | Result |
|---|---|---|---|---|---|
| [2026-10-01_1146_bluefield3_full](2026-10-01_1146_bluefield3_full/) | bluefield3 | full | 0.6.1 | v25.10-release | PASS: 3 checks passed, 0 failed, 4 recorded measurements. 2026-10-01 11:32 UTC. |
| [2026-10-01_1125_bluefield3_full](2026-10-01_1125_bluefield3_full/) | bluefield3 | full | 0.6.1 | v26.06-release | PASS: 3 checks passed, 0 failed, 4 recorded measurements. 2026-10-01 11:12 UTC. |
| [2026-09-30_1933_bluefield3_full](2026-09-30_1933_bluefield3_full/) | bluefield3 | full | 0.6.1 | v25.10-release | PASS: 3 checks passed, 0 failed, 4 recorded measurements. 2026-09-30 19:21 UTC. |
| [2026-09-30_1901_server1_full](2026-09-30_1901_server1_full/) | server1 | full | 0.6.0 | v25.10-release | PASS: 9 checks passed, 0 failed, 95 recorded measurements. 2026-09-30 19:01 UTC. |
| [2026-09-30_1337_epyc-sp5_full](2026-09-30_1337_epyc-sp5_full/) | epyc-sp5 | full | 0.6.0 | v25.10-release | CALIBRATION RUN (no verdict): 8 checks passed, 1 failed, 97 recorded measurements. 2026-09-30 13:37 UTC. |
