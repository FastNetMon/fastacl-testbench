#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ROLE="${1:-}"
case "$ROLE" in lava|flame|dell|alice|bob) export GEN="$ROLE" ;; esac
source "$SCRIPT_DIR/../vars.sh"

if [[ ! "$ROLE" =~ ^(lava|flame|dell|alice|bob|dut)$ ]]; then
  echo "Usage: $0 [lava|flame|dell|alice|bob|dut]"
  echo "  lava   — packet generator + receiver (lava machine)"
  echo "  flame  — packet generator + receiver (flame machine)"
  echo "  dell   — packet generator + receiver (dell machine)"
  echo "  dut    — VPP DUT with FastACL (server machine)"
  exit 1
fi

echo "=== FastACL hw-lab install ($ROLE) ==="
echo ""

NEED_REBOOT=0

echo "[1/5] Docker..."

if command -v docker &>/dev/null; then
  echo "  Docker already installed: $(docker --version)"
else
  echo "  Installing Docker (via get.docker.com)..."
  curl -fsSL https://get.docker.com | sh
  echo "  Docker installed."
fi

REAL_USER="${SUDO_USER:-$USER}"
if id -nG "$REAL_USER" | grep -qw docker; then
  echo "  $REAL_USER already in docker group."
else
  usermod -aG docker "$REAL_USER"
  echo "  Added $REAL_USER to docker group. Re-login for group to take effect."
  echo "  (Or run: newgrp docker)"
fi

echo ""
echo "[2/5] Persistent kernel cmdline tunings..."

GRUB_FILE="/etc/default/grub"
GRUB_CHANGED=0

if [ "$ROLE" = "dut" ]; then
  HP_1G_NR="$HUGEPAGES_NR"
else
  HP_1G_NR="${GEN_HUGEPAGES_1G:-$HUGEPAGES_NR}"
fi

WANTED_PARAMS=("iommu=pt")
[ "$HP_1G_NR" -gt 0 ] && WANTED_PARAMS+=("hugepagesz=1G" "hugepages=$HP_1G_NR")
if [ "$ROLE" = "dut" ] && [ -n "${DUT_WORKER_CORES:-}" ]; then
  WANTED_PARAMS+=(
    "isolcpus=$DUT_WORKER_CORES"
    "nohz_full=$DUT_WORKER_CORES"
    "rcu_nocbs=$DUT_WORKER_CORES"
    "processor.max_cstate=1"
    "irqaffinity=$DUT_MAIN_CORE"
  )
elif [ -n "${TREX_WORKER_CORES:-}" ]; then
  # The generator needs the same isolation as the DUT: an un-isolated TRex core
  # that takes a timer tick or an IRQ under-runs its stream and the offered load
  # becomes jittery, which reads as DUT loss.  Latency core is isolated too.
  GEN_ISOL_CORES="$TREX_WORKER_CORES${TREX_LATENCY_CORE:+,$TREX_LATENCY_CORE}"
  WANTED_PARAMS+=(
    "isolcpus=$GEN_ISOL_CORES"
    "nohz_full=$GEN_ISOL_CORES"
    "rcu_nocbs=$GEN_ISOL_CORES"
    "processor.max_cstate=1"
    "irqaffinity=${TREX_MASTER_CORE:-0}"
  )
fi

for P in ${WANTED_PARAMS[@]+"${WANTED_PARAMS[@]}"}; do
  KEY="${P%%=*}="
  if grep -qE "(GRUB_CMDLINE_LINUX[A-Z_]*=\".*)$KEY" "$GRUB_FILE" 2>/dev/null; then
    continue
  fi
  echo "  + $P"
  sed -i "s|GRUB_CMDLINE_LINUX=\"\(.*\)\"|GRUB_CMDLINE_LINUX=\"\1 $P\"|" "$GRUB_FILE"
  GRUB_CHANGED=1
done

if [ $GRUB_CHANGED -eq 1 ]; then
  if command -v update-grub &>/dev/null; then
    update-grub >/dev/null
    echo "  GRUB updated.  REBOOT REQUIRED for the new cmdline to take effect."
  elif command -v grub2-mkconfig &>/dev/null; then
    grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null
    echo "  GRUB updated.  REBOOT REQUIRED for the new cmdline to take effect."
  else
    echo "  WARNING: Could not find grub update command. Update GRUB manually."
  fi
else
  echo "  Kernel cmdline already has all desired tunings (no change)."
fi

# Intel I225/I226 (igc) management ports drop off the PCIe bus with ASPM L1 on
# ("PCIe link lost, device now detached"), taking SSH and Tailscale with them
# while the host keeps running -- seen on bob during a large image copy.  Keep
# L1 off for igc ports only, from boot on and right now.
IGC_RULE=/etc/udev/rules.d/80-igc-no-aspm-l1.rules
IGC_LINE='ACTION=="add|bind", SUBSYSTEM=="pci", DRIVER=="igc", ATTR{link/l1_aspm}="0"'
if [ "$(cat "$IGC_RULE" 2>/dev/null)" != "$IGC_LINE" ]; then
  echo "$IGC_LINE" > "$IGC_RULE"
  udevadm control --reload
  echo "  + $IGC_RULE (ASPM L1 off on igc ports)"
fi
for d in /sys/bus/pci/drivers/igc/0000:*; do
  if [ -w "$d/link/l1_aspm" ]; then echo 0 > "$d/link/l1_aspm"; fi
done

echo ""
echo "[3/5] Allocating hugepages now..."

HUGEPAGE_FILE="/sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages"
current_hp=$(cat "$HUGEPAGE_FILE" 2>/dev/null || echo 0)

if [ "$HP_1G_NR" -eq 0 ]; then
  echo "  1GB hugepages not needed for this role/generator (GEN_HUGEPAGES_1G=0) — skipping."
elif [ "$current_hp" -ge "$HP_1G_NR" ]; then
  echo "  Already have $current_hp x 1GB hugepages (OK)."
else
  echo "  Allocating $HP_1G_NR x 1GB hugepages (currently $current_hp)..."
  echo "$HP_1G_NR" > "$HUGEPAGE_FILE"
  current_hp=$(cat "$HUGEPAGE_FILE")
  if [ "$current_hp" -lt "$HP_1G_NR" ]; then
    echo "  WARNING: Only got $current_hp of $HP_1G_NR hugepages."
    echo "  Memory may be fragmented — a reboot will use the kernel cmdline params."
    [ "$current_hp" -eq 0 ] && echo "  ERROR: 0 hugepages. VPP will fail to start without a reboot." || true
  else
    echo "  Allocated $current_hp x 1GB hugepages."
  fi
fi

if ! mount | grep -q "hugetlbfs"; then
  mkdir -p /dev/hugepages
  mount -t hugetlbfs nodev /dev/hugepages
  echo "  hugetlbfs mounted at /dev/hugepages."
else
  echo "  hugetlbfs already mounted."
fi

echo ""
echo "[4/5] MLNX_OFED (host kernel modules)..."

if { [ "$ROLE" != "dut" ] && [ "${GEN_SKIP_OFED:-0}" = "1" ]; } || { [ "$ROLE" = "dut" ] && [ "${DUT_SKIP_OFED:-0}" = "1" ]; }; then
  echo "  Skipped for this host (inbox mlx5 is sufficient)."
elif command -v ofed_info &>/dev/null; then
  echo "  MLNX_OFED already installed: $(ofed_info -s 2>/dev/null || echo unknown)"
else
  OS_VER=$(. /etc/os-release && echo "$VERSION_ID")
  ARCH=$(uname -m)

  echo "  Fetching current MLNX_OFED version for Ubuntu ${OS_VER}..."
  OFED_VER=$(curl -fsSL \
    "https://linux.mellanox.com/public/repo/mlnx_ofed/latest/ubuntu${OS_VER}/mellanox_mlnx_ofed.list" \
    | grep -oP '(?<=mlnx_ofed/)[0-9]+\.[0-9]+-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

  if [ -z "$OFED_VER" ]; then
    echo "  ERROR: Could not determine MLNX_OFED version. Check network/OS." >&2
    exit 1
  fi
  echo "  Version: $OFED_VER"

  OFED_TGZ="MLNX_OFED_LINUX-${OFED_VER}-ubuntu${OS_VER}-${ARCH}.tgz"
  OFED_URL="https://content.mellanox.com/ofed/MLNX_OFED-${OFED_VER}/${OFED_TGZ}"
  OFED_DIR="/tmp/mlnx_ofed_install"

  echo "  Downloading ${OFED_TGZ} (~1 GB, this takes a few minutes)..."
  mkdir -p "$OFED_DIR"
  curl -fL --progress-bar -o "${OFED_DIR}/${OFED_TGZ}" "$OFED_URL"

  echo "  Extracting..."
  tar -xzf "${OFED_DIR}/${OFED_TGZ}" -C "$OFED_DIR"

  echo "  Installing build dependencies..."
  apt-get install -y --no-install-recommends \
    dkms gcc make python3 linux-headers-"$(uname -r)" perl libc6-dev pciutils

  OFED_INSTALLER=$(find "$OFED_DIR" -name "mlnxofedinstall" -type f | head -1)
  echo "  Running mlnxofedinstall --dpdk (uses pre-built DEBs where available)..."
  "$OFED_INSTALLER" \
    --dpdk \
    --without-fw-update \
    --force \
    2>&1

  echo "  MLNX_OFED ${OFED_VER} installed."
  rm -rf "$OFED_DIR"
  NEED_REBOOT=1
fi

echo ""
echo "[5/5] Runtime directories..."
mkdir -p /run/vpp
echo "  /run/vpp ready."

echo ""
echo "=== Install complete for $ROLE ==="
echo ""
echo "Current hugepages: $(cat $HUGEPAGE_FILE)"
echo ""
echo "Next steps:"
if [ "$ROLE" = "dut" ]; then
  echo "  docker compose -f labs/hw/compose.yaml run --rm dut"
else
  echo "  docker compose -f labs/hw/compose.yaml run --rm gen"
fi
echo ""
if [ "$current_hp" -lt "$HP_1G_NR" ]; then
  echo "NOTE: Reboot recommended to guarantee $HP_1G_NR x 1GB hugepages."
  NEED_REBOOT=1
fi
if [ "$NEED_REBOOT" -eq 1 ]; then
  echo "REBOOT REQUIRED — run:  sudo reboot"
  echo "  After reboot: verify with 'ofed_info -s' and restart the lab service."
fi
