# BlueField-3 DPU bench

Runs FastACL on the **BlueField-3 Arm cores** (16× Cortex-A78AE) instead of the x86 host and
measures the drop rate per frame size. Results are published like every other rig, in
[`reports/`](../../../reports/) (`<date>_<time>_bluefield3_full`).

## Topology

```
 lava1 (Ryzen 9950X, 2× CX-5 Ex, TRex)        epyc-sp5 BlueField-3 (DPU mode, Arm owns the uplinks)
   card B ──100G DAC──►  p1 uplink 03:00.1   (ingress)
   card A ◄─100G DAC───  p0 uplink 03:00.0   (egress)
```

Management of the Arm runs over `oob_net0`, independent of the uplinks. Host names, MACs and
credentials come from `labs/hw/lab.env` (see [docs/lab.md](../../../docs/lab.md)).

## Running

```
labs/hw/run.sh bluefield3 gate     # 64 B, IMIX, 1500 B with floors
labs/hw/run.sh bluefield3 full     # 64–1500 B and IMIX
```

or `hw-line-rate.yml` with `dut=bluefield3` (or `dut=all`). The `bluefield3` profile makes
`suite.sh` do the following:

1. `labs/hw/bf-mode.sh dpu` — read `INTERNAL_CPU_MODEL` with `mlxconfig` on the Arm, set it,
   cold power-cycle epyc-sp5 over IPMI, wait for fresh boots of host and Arm, verify. A no-op
   when the card is already in DPU mode; refuses while other users are logged in unless
   `BF_MODE_FORCE=1`.
2. `labs/hw/sync-hosts.sh` — copy the testbench and the arm64 release bundle to the Arm and to
   the generator (after the mode switch, so the power cut cannot lose freshly written files).
3. `run-dpu-bench.sh` — on the Arm: 2 MB hugepages, detach `p0`/`p1` from the OVS bridges,
   build `fastacl-dut:current` from the bundle (`labs/hw/dut-image.sh`), start VPP with
   `startup-arm.conf` (12 workers, 1 RSS queue each, L2 cross-connect, filter on both ports),
   record the rig, then for each frame size restart TRex on lava1 and measure the NIC's
   `rx_good_packets` over 15 s with a UDP drop rule. Teardown stops VPP and re-attaches the
   uplinks to OVS.
4. `labs/hw/bf-mode.sh nic` on exit, so every run leaves the card in NIC mode for epyc-sp5.

## Notes

- Only 2 MB hugetlbfs is mounted on the BlueField OS; there is no 1 GB mount.
- mlx5 is a bifurcated driver: the uplinks stay on `mlx5_core`, the container needs
  `--privileged`, the host network and `/dev/infiniband`.
- `show runtime` clocks on the Arm are 330 MHz generic-timer ticks, about 6.5 core cycles each
  at 2.13 GHz; they do not compare directly with x86 TSC cycles.
