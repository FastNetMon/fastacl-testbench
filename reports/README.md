# FastACL hardware bench reports

Every **full**, **bng** and **pair** run of `labs/hw/run.sh <rig> <suite>` (the `hw-line-rate`
workflow runs the full suite) publishes one folder here, named `<date>_<time UTC>_<rig>_<suite>`. Gate runs are not
published; they keep their report in the workflow summary and as a run artifact.

Each run measures the **licensed FastACL release bundle** that customers receive, on one of the
reference rigs. Methodology, topology and thresholds: [test strategy](../docs/test-strategy.md),
[lab](../docs/lab.md).

| Rig | DUT | Generator |
|---|---|---|
| `server1` | AMD EPYC 7742 (64 cores), ConnectX-7, VPP on x86 | Ryzen 7 5800X + ConnectX-7, TRex |
| `epyc-sp5` | AMD EPYC 9534 (64 cores), BlueField-3 in NIC mode, VPP on x86 | Ryzen 9 9950X + 2× ConnectX-5 Ex, TRex |
| `bluefield3` | BlueField-3 Arm (16× Cortex-A78AE) in DPU mode, VPP on the Arm cores | Ryzen 9 9950X + 2× ConnectX-5 Ex, TRex |
| `epyc-cx8` | AMD EPYC 9534 (64 cores), ConnectX-8 at 400G, VPP on x86 (32 workers unless the report says otherwise) | bob: Ryzen 9 9950X + ConnectX-8, TRex built from source |
| `epyc-platform` | AMD EPYC 9534 (64 cores), 2× ConnectX-8 + BlueField-3 (NIC mode), six ingress ports, VPP on x86 (62 workers) | server1: EPYC 7742 + 2× ConnectX-7 + 3× ConnectX-5 Ex, TRex built from source |
| `alice` | Ryzen 9 9950X (16 cores), ConnectX-8 at 400G, VPP on x86 (15 workers) | bob: Ryzen 9 9950X + ConnectX-8, TRex built from source |
| `bob` | Ryzen 9 9950X (16 cores), ConnectX-8 at 400G, VPP on x86 (15 workers) | alice: Ryzen 9 9950X + ConnectX-8, TRex built from source |

| Suite | What it measures |
|---|---|
| `full` | the gates plus every sweep: rules, attacks, scenarios, active flows, frame sizes |
| `bng` | on `bluefield3`: a routed subscriber pipeline (per-subscriber rate limit, NAT44-ED) on the Arm cores |
| `pair` | on `alice`/`bob`: what the two TRex hosts send and receive, 64 B to 1518 B, one port and both |

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
| `bng` | one BNG pipeline point: forwarded and received Mpps, NIC loss, per-packet ticks of the filter, NAT and whole graph, RSS hash, workers receiving |
| `pair` | one generator-pair point: direction, ports, frame, sent and received Mpps, receiver drops |
| `load` | a setup step that failed (bring-up, rule load, mode switch); always `FAIL` |

## Units and conventions

- Frame sizes are **pre-FCS**: 64 B is 68 B on the wire, so 100 % of 100 GbE is 142.05 Mpps.
- Wire Gbps counts frame + 24 B (FCS, preamble, inter-frame gap).
- `cyc_pkt` is CPU TSC cycles on x86; on `bluefield3` it is Arm generic-timer ticks (330 MHz),
  about 6.5 core cycles each at the A78AE's 2.13 GHz.
- A **calibration run** records everything without a verdict; its numbers set the rig's floors.

## Index

| Report | Rig | Suite | FastACL | VPP | DUT software | Result |
|---|---|---|---|---|---|---|
| [2026-10-09_1110_epyc-platform_platform](2026-10-09_1110_epyc-platform_platform/) | epyc-platform | platform |  |  | kernel 6.8.0-142-generic | CALIBRATION RUN (no verdict): 0 checks passed, 0 failed, 23 recorded measurements. 2026-10-09 10:52 UTC. |
| [2026-10-09_1017_epyc-platform_platform](2026-10-09_1017_epyc-platform_platform/) | epyc-platform | platform |  |  | kernel 6.8.0-142-generic | CALIBRATION RUN (no verdict): 0 checks passed, 0 failed, 23 recorded measurements. 2026-10-09 10:00 UTC. |
| [2026-10-07_1544_epyc-cx8_full](2026-10-07_1544_epyc-cx8_full/) | epyc-cx8 | full | 0.6.1 | v25.10-release · dpdk | Ubuntu 24.04.4 LTS, NIC firmware 40.50.1002 | CALIBRATION RUN (no verdict): 5 checks passed, 6 failed, 101 recorded measurements. 2026-10-07 13:32 UTC. |
| [2026-10-07_1057_epyc-cx8_full](2026-10-07_1057_epyc-cx8_full/) | epyc-cx8 | full | 0.6.1 | v25.10-release · dpdk | Ubuntu 24.04.4 LTS, NIC firmware 40.50.1002 | CALIBRATION RUN (no verdict): 9 checks passed, 2 failed, 101 recorded measurements. 2026-10-07 09:02 UTC. |
| [2026-10-05_1526_bob_full](2026-10-05_1526_bob_full/) | bob | full | 0.6.1 | v25.10-release · dpdk | Ubuntu 24.04.4 LTS, NIC firmware 40.50.1002 | CALIBRATION RUN (no verdict): 8 checks passed, 1 failed, 6 recorded measurements. 2026-10-05 15:16 UTC. |
| [2026-10-05_1416_bob_full](2026-10-05_1416_bob_full/) | bob | full | 0.6.1 | v25.10-release · dpdk | Ubuntu 24.04.4 LTS, NIC firmware 40.50.1002 | CALIBRATION RUN (no verdict): 3 checks passed, 6 failed, 6 recorded measurements. 2026-10-05 14:05 UTC. |
| [2026-10-05_1335_alice_full](2026-10-05_1335_alice_full/) | alice | full | 0.6.1 | v25.10-release · dpdk | Ubuntu 24.04.4 LTS, NIC firmware 40.50.1002 | CALIBRATION RUN (no verdict): 8 checks passed, 1 failed, 6 recorded measurements. 2026-10-05 13:25 UTC. |
| [2026-10-05_1307_alice_full](2026-10-05_1307_alice_full/) | alice | full | 0.6.1 | v25.10-release · dpdk | Ubuntu 24.04.4 LTS, NIC firmware 40.50.1002 | CALIBRATION RUN (no verdict): 3 checks passed, 6 failed, 6 recorded measurements. 2026-10-05 12:56 UTC. |
| [2026-10-03_0021_bob_full](2026-10-03_0021_bob_full/) | bob | full | 0.6.1 | v25.10-release · dpdk | Ubuntu 24.04.4 LTS, NIC firmware 40.50.1002 | CALIBRATION RUN (no verdict): 5 checks passed, 6 failed, 101 recorded measurements. 2026-10-02 22:26 UTC. |
| [2026-10-02_2219_alice_full](2026-10-02_2219_alice_full/) | alice | full | 0.6.1 | v25.10-release · dpdk | Ubuntu 24.04.4 LTS, NIC firmware 40.50.1002 | CALIBRATION RUN (no verdict): 5 checks passed, 6 failed, 101 recorded measurements. 2026-10-02 20:25 UTC. |
| [2026-10-02_1716_alice_full](2026-10-02_1716_alice_full/) | alice | full | 0.6.1 | v25.10-release · dpdk | Ubuntu 24.04.4 LTS, NIC firmware 40.50.1002 | CALIBRATION RUN (no verdict): 4 checks passed, 5 failed, 99 recorded measurements. 2026-10-02 15:25 UTC. |
| [2026-10-02_1520_alice_pair](2026-10-02_1520_alice_pair/) | alice | pair |  |  |  | CALIBRATION RUN (no verdict): 0 checks passed, 0 failed, 20 recorded measurements. 2026-10-02 15:11 UTC. |
| [2026-10-02_1314_bluefield3_bng](2026-10-02_1314_bluefield3_bng/) | bluefield3 | bng | 0.6.1 | v26.10-rc1~0-g28e8c47f7 · rdma dv | DOCA 3.4.0112, NIC firmware 32.49.1014 | PASS: 0 checks passed, 0 failed, 16 recorded measurements. 2026-10-02 12:38 UTC. |
| [2026-10-02_0639_bluefield3_full](2026-10-02_0639_bluefield3_full/) | bluefield3 | full | 0.6.1 | v26.10-rc1~0-g28e8c47f7 · rdma dv | DOCA 3.4.0112, NIC firmware 32.49.1014 | PASS: 3 checks passed, 0 failed, 4 recorded measurements. 2026-10-02 06:21 UTC. |
| [2026-10-02_0620_bluefield3_full](2026-10-02_0620_bluefield3_full/) | bluefield3 | full | 0.6.1 | v26.10-rc1~0-g28e8c47f7 · dpdk | DOCA 3.4.0112, NIC firmware 32.49.1014 | PASS: 3 checks passed, 0 failed, 4 recorded measurements. 2026-10-02 06:05 UTC. |
| [2026-10-01_1301_bluefield3_full](2026-10-01_1301_bluefield3_full/) | bluefield3 | full | 0.6.1 | v25.10-release | DOCA 3.4.0112, NIC firmware 32.49.1014 | PASS: 3 checks passed, 0 failed, 4 recorded measurements. 2026-10-01 12:43 UTC. |
| [2026-10-01_1242_bluefield3_full](2026-10-01_1242_bluefield3_full/) | bluefield3 | full | 0.6.1 | v26.06-release | DOCA 3.4.0112, NIC firmware 32.49.1014 | PASS: 3 checks passed, 0 failed, 4 recorded measurements. 2026-10-01 12:28 UTC. |
| [2026-10-01_1202_bluefield3_full](2026-10-01_1202_bluefield3_full/) | bluefield3 | full | 0.6.1 | v26.06-release | DOCA 24.11 | PASS: 3 checks passed, 0 failed, 4 recorded measurements. 2026-10-01 11:47 UTC. |
| [2026-10-01_1146_bluefield3_full](2026-10-01_1146_bluefield3_full/) | bluefield3 | full | 0.6.1 | v25.10-release | DOCA 24.11 | PASS: 3 checks passed, 0 failed, 4 recorded measurements. 2026-10-01 11:32 UTC. |
| [2026-10-01_1125_bluefield3_full](2026-10-01_1125_bluefield3_full/) | bluefield3 | full | 0.6.1 | v26.06-release | DOCA 24.11 | PASS: 3 checks passed, 0 failed, 4 recorded measurements. 2026-10-01 11:12 UTC. |
| [2026-09-30_1933_bluefield3_full](2026-09-30_1933_bluefield3_full/) | bluefield3 | full | 0.6.1 | v25.10-release | kernel 5.15.0-1057-bluefield | PASS: 3 checks passed, 0 failed, 4 recorded measurements. 2026-09-30 19:21 UTC. |
| [2026-09-30_1901_server1_full](2026-09-30_1901_server1_full/) | server1 | full | 0.6.0 | v25.10-release | kernel 6.8.0-139-generic | PASS: 9 checks passed, 0 failed, 95 recorded measurements. 2026-09-30 19:01 UTC. |
| [2026-09-30_1337_epyc-sp5_full](2026-09-30_1337_epyc-sp5_full/) | epyc-sp5 | full | 0.6.0 | v25.10-release | kernel 6.8.0-139-generic | CALIBRATION RUN (no verdict): 8 checks passed, 1 failed, 97 recorded measurements. 2026-09-30 13:37 UTC. |
