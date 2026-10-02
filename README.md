# fastacl-testbench

Hardware-lab tooling, HW line-rate CI and published performance results for
[FastACL](https://fastnetmon.com/), the FlowSpec DDoS filter plugin for VPP.

| | |
|---|---|
| Strategy | [docs/test-strategy.md](docs/test-strategy.md): layers, topologies, methodology, thresholds, reporting |
| Lab | [docs/lab.md](docs/lab.md): machines, cabling, access |
| Reports | [reports/](reports/): one folder per full-suite hardware run, named by date and time |

## Layout

```
labs/hw/         hardware bench: bring-up, generator, DUT, suites, report
labs/hw/dpu/     BlueField-3 Arm bench
labs/hw/profiles per-DUT thresholds
docker/          TRex generator image, DUT image (built from a FastACL release bundle)
docs/            strategy, lab
```

## How it is used

- **FastACL CI** (in the FastACL repository) runs the functional suite, sanitizers and
  performance sanity on every push, against builds made with throwaway licence keys.
- **Hardware runs** are GitHub Actions workflows in this repository: `hw-line-rate`, started
  manually (gate or full suite, on server1, epyc-sp5, the bluefield3 DPU, alice and bob); the BNG
  and generator-pair suites run from `run.sh`. They install the
  licensed FastACL release bundle on the DUT, the same one customers receive. Nothing here
  builds or unlocks FastACL.
- **One command per rig**: `labs/hw/run.sh <server1|epyc-sp5|bluefield3|alice|bob> <gate|full|bng|pair>` downloads
  the release bundle, syncs the lab hosts, switches the BlueField-3 between NIC and DPU mode when
  needed, brings up the DUT and generator, runs the suite, writes the report (published to
  `reports/` for the full, bng and pair suites; never for the gate), and tears down. The workflow calls exactly this; it runs the same from any machine
  with `labs/hw/lab.env`, the lab SSH key and `gh` access to the FastACL releases.

## Where VPP and FastACL come from

The bench never compiles anything. Every run installs a **release bundle** built and published
by the CI of the FastACL source repository, [FastNetMon/fastacl](https://github.com/FastNetMon/fastacl)
(private; the workflow reads it with the `FASTACL_RELEASE_TOKEN` secret):

1. **VPP**: the `base-image` workflow builds upstream FD.io VPP from its release tag
   (`v25.10`, `v26.06`) with `make pkg-deb`, inside Ubuntu 24.04, on native GitHub runners:
   `ubuntu-24.04` for amd64 and `ubuntu-24.04-arm` for arm64.
2. **Plugin**: the `ci.yml` release job builds the FastACL plugin out of tree against that VPP,
   with the production licence key, on the same runner architecture.
3. **Bundle**: the same job repacks the VPP packages (`vpp`, `libvppinfra`, `vpp-plugin-core`,
   `vpp-plugin-dpdk`, `vpp-crypto-engines`) with `dpkg-repack`, adds `fastacl-plugin`, the
   install scripts and a 30-day evaluation licence, and publishes one tarball per VPP version
   and architecture:
   - every push to `main` replaces the assets of the rolling `latest-main` release
     (`fastacl-main-vpp2510.tar.gz`, `fastacl-main-vpp2510-arm64.tar.gz`, ...);
   - every tag `vX.Y.Z` creates a versioned release (`fastacl-vX.Y.Z-vpp2510.tar.gz`, ...).

The workflow inputs `release_tag` (default `latest-main`) and `vpp` (`2510`, `2606` or `2610`) pick
the bundle; the rig profile adds the `-arm64` suffix for `bluefield3`.

## How they reach the DUT

| Step | Code | What happens |
|---|---|---|
| Download | `labs/hw/run.sh` `fetch_bundle` | `gh release download` of the bundle into `bundle/`, extracted to `bundle/debs/*.deb` |
| Copy | `labs/hw/sync-hosts.sh` | `rsync` of the whole testbench, `bundle/` included, to `~/fastacl-testbench` on the DUT and the generator; for `bluefield3` this runs after the switch to DPU mode |
| Image | `labs/hw/dut-image.sh` + `docker/Dockerfile.dut` | on the DUT itself: Ubuntu 24.04 + `apt-get install /tmp/debs/*.deb` + the bundle licence, tagged `fastacl-dut:current` |
| Start | `labs/hw/bringup-guarded.sh` (x86) / `labs/hw/dpu/run-dpu-bench.sh` (Arm) | x86: `docker compose run dut` with `labs/hw/dut/start.sh`; BlueField-3: `docker run … fastacl-dut:current vpp -c labs/hw/dpu/startup-arm.conf` |

The report records the installed `vpp` and `fastacl-plugin` versions and the release tag, so
every published number traces back to one bundle. Teardown removes the image, the bundle and
the checkout from the lab hosts.

## Licence

Apache-2.0. FastACL itself is licensed separately.
