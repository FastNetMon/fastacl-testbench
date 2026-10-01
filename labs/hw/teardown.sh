#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/vars.sh"
SSH="ssh $SSH_OPTS"
SCRATCH_DIR="${HOST_REPO:-fastacl-testbench}"

for host in "$DUT_HOST" "$SENDER_HOST"; do
  [ -z "${host:-}" ] && continue
  echo ">> $host: removing lab containers, images and ~/$SCRATCH_DIR ..."
  $SSH "$LAB_SSH_USER@$host" "SCRATCH_DIR='$SCRATCH_DIR' bash -s" <<'REMOTE' || true
    set -uo pipefail
    # Containers: graceful stop (lets VPP release the CX5 — a SIGKILL wedges the
    # mlx5 fw), then force-rm any leftover; kill the DUT tmux session.
    for f in hw-dut-run hw-gen; do
      sg docker -c "docker ps -q  --filter name=$f | xargs -r docker stop -t 10" 2>/dev/null || true
      sg docker -c "docker ps -aq --filter name=$f | xargs -r docker rm -f"      2>/dev/null || true
    done
    tmux kill-session -t fastacl-dut 2>/dev/null || true
    tmux kill-session -t fastacl-gen 2>/dev/null || true
    # Reclaim hugepages.  A container stopped mid-run leaves rtemap_* files that
    # keep every page they mapped reserved; the next bring-up then dies with
    # "Main heap allocation failure!" and HugePages_Free far under
    # HugePages_Total, which looks like a misconfigured heap rather than a leak.
    # Safe here: every DPDK process was just stopped above.
    sudo -n rm -f /dev/hugepages/rtemap_* /dev/hugepages1G/rtemap_* 2>/dev/null \
      || rm -f /dev/hugepages/rtemap_* /dev/hugepages1G/rtemap_* 2>/dev/null || true
    echo "   hugepages free after cleanup:" \
         "$(awk '/HugePages_Free/ {print $2}' /proc/meminfo)/$(awk '/HugePages_Total/ {print $2}' /proc/meminfo)"
    # Images: base (so the next run force-pulls fresh from GHCR), GHCR base,
    # hw-gen, hw-dut, plus dangling + build cache. Drop any GHCR login too.
    sg docker -c "docker images --format '{{.Repository}}:{{.Tag}}' | grep -iE 'fastacl-dev|fastacl-dut|trex|hw-gen|hw-dut' | xargs -r docker rmi -f" 2>/dev/null || true
    sg docker -c "docker image prune -f"   >/dev/null 2>&1 || true
    sg docker -c "docker builder prune -f" >/dev/null 2>&1 || true
    sg docker -c "docker logout ghcr.io"   >/dev/null 2>&1 || true
    # Remove both lab checkouts so the host keeps no fastacl code between runs.
    # The container builds the plugin into build/ as root, so fall back to sudo.
    d="$HOME/${SCRATCH_DIR}"
    [ -d "$d" ] && { rm -rf "$d" 2>/dev/null || sudo -n rm -rf "$d" 2>/dev/null || true; }
    echo "   containers=[$(docker ps -aq --filter name=hw 2>/dev/null | tr '\n' ' ')]" \
         "images=[$(docker images --format '{{.Repository}}' 2>/dev/null | grep -iE 'fastacl|trex|hw-' | tr '\n' ' ')]" \
         "checkouts=[$(cd "$HOME" && ls -d "${SCRATCH_DIR}" 2>/dev/null | tr '\n' ' ')]"
REMOTE
done

if [ -n "${CI:-}" ]; then
  rm -rf "$SCRIPT_DIR/../../bundle" "$SCRIPT_DIR/license" "$SCRIPT_DIR/lab.env"
  echo ">> runner: removed the downloaded bundle, licence and lab.env"
fi
echo ">> Teardown complete."
