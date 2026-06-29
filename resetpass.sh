#!/bin/bash
#
# reset-linux-root.sh
#
# Reset the root password of an installed Linux system from SystemRescue, then
# reboot into that OS.
#
# Supported: Ubuntu, Debian, CentOS, AlmaLinux (also Rocky/RHEL), on ext2/3/4 or
# xfs roots, plain partition or LVM. ONLY the root password is changed inside the
# OS — nothing else.
#
# Robust because:
#   * chpasswd is called by ABSOLUTE PATH (/usr/sbin/chpasswd). SystemRescue is
#     Arch-based and its PATH may omit /usr/sbin, where these distros keep
#     chpasswd — a bare `chpasswd` inside chroot fails with exit 127.
#   * The reboot lives in an EXIT trap and is FORCED (reboot -f / sysrq), so the
#     node reboots on every path (success or failure).
#   * EFI BootNext makes the firmware boot the installed OS next, so the box does
#     not fall back into the rescue / PXE boot.
#
# Run as root in the rescue shell:   bash reset-linux-root.sh
#
set -euo pipefail

# SystemRescue's PATH may omit /usr/sbin, where these distros keep chpasswd.
# Force a full PATH so chroot command lookups resolve in the target.
export PATH="/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

# ===================== edit here =====================
NEWPW='TR1Q2w3E4r58'
# =====================================================

MNT='/mnt/target'
PROBE='/mnt/.probe'
ROOT_FS_TYPES="ext2 ext3 ext4 xfs"               # xfs covers CentOS/Alma defaults
ROOT_IDS="ubuntu debian centos almalinux rocky rhel"

ERR_LINE='?'
trap 'ERR_LINE=$LINENO' ERR

# Guaranteed finish: runs on ANY exit -> unmount, set the OS as next boot, then
# FORCE a reboot.
finish() {
  rc=$?
  set +e
  umount -R "$MNT"   2>/dev/null
  umount    "$PROBE" 2>/dev/null
  rmdir     "$PROBE" 2>/dev/null
  if [ "$rc" -eq 0 ]; then
    echo "[+] Done. Reboot into the installed OS."
  else
    echo "[x] FAILED (exit ${rc}) near line ${ERR_LINE}. Rebooting anyway."
  fi
  # Boot the installed OS next (firmware boot choice only; no OS change).
  # Matches entry labels like: ubuntu, debian, CentOS, CentOS Stream, AlmaLinux,
  # Rocky, Red Hat. First match wins; any of a distro's entries boots the same OS.
  if command -v efibootmgr >/dev/null 2>&1 && [ -d /sys/firmware/efi ]; then
    N="$(efibootmgr | grep -iE '^Boot[0-9A-Fa-f]{4}\*?[[:space:]]+(ubuntu|debian|centos|alma|rocky|rhel|red[[:space:]]?hat)' | head -n1 | sed -E 's/^Boot([0-9A-Fa-f]{4}).*/\1/')"
    [ -n "$N" ] && efibootmgr -n "$N" >/dev/null 2>&1 && echo "[*] Next boot set to the OS (Boot$N)."
  fi
  sync
  sleep 3
  # Force the reboot so it cannot be swallowed.
  reboot -f || systemctl reboot -ff 2>/dev/null || { echo b > /proc/sysrq-trigger; }
}
trap finish EXIT

echo "========================================================"
echo "RESET LINUX ROOT PASSWORD"
echo "========================================================"
sleep 3

############################################
# 1) Activate LVM + clear SystemRescue auto-mounts
############################################
echo "[*] Activating LVM and clearing rescue auto-mounts..."
for mp in /home/rescue/partitions/*; do
  if [ -d "$mp" ] && mountpoint -q "$mp"; then
    umount "$mp" 2>/dev/null || umount -l "$mp" 2>/dev/null || true
  fi
done
lvm vgchange -a y >/dev/null 2>&1 || true
udevadm settle 2>/dev/null || true

############################################
# 2) Find the OS root filesystem (content-based; LVM or plain, ext or xfs)
############################################
echo "[*] Finding the OS root filesystem..."
mkdir -p "$PROBE"

probe_mount() {  # mount $1 read-only at $PROBE; handle xfs with an unclean log
  mount -o ro            "$1" "$PROBE" 2>/dev/null && return 0
  mount -o ro,norecovery "$1" "$PROBE" 2>/dev/null && return 0
  return 1
}

ROOT_DEV=""; ROOT_OS=""
while read -r dev fstype; do
  case " $ROOT_FS_TYPES " in *" $fstype "*) ;; *) continue ;; esac
  probe_mount "$dev" || continue
  if [ -f "$PROBE/etc/shadow" ] && [ -f "$PROBE/etc/os-release" ] && [ -d "$PROBE/usr" ]; then
    osid="$(. "$PROBE/etc/os-release" 2>/dev/null; echo "${ID:-}")"
    case " $ROOT_IDS " in
      *" $osid "*)
        ROOT_DEV="$dev"
        ROOT_OS="$(. "$PROBE/etc/os-release" 2>/dev/null; echo "${PRETTY_NAME:-$osid}")"
        umount "$PROBE" 2>/dev/null || true
        break
        ;;
    esac
  fi
  umount "$PROBE" 2>/dev/null || true
done < <(lsblk -rpno NAME,FSTYPE)

[ -n "$ROOT_DEV" ] || { echo "[x] No supported Linux root found."; exit 3; }
echo "[OK] OS root: $ROOT_DEV  ($ROOT_OS)"

############################################
# 3) Mount + chroot + set the root password
############################################
mkdir -p "$MNT"
mount "$ROOT_DEV" "$MNT"
for fs in dev dev/pts proc sys; do mount --bind "/$fs" "$MNT/$fs"; done

# Absolute path: SystemRescue's PATH omits /usr/sbin where chpasswd lives.
echo "root:$NEWPW" | chroot "$MNT" /usr/sbin/chpasswd
echo "[OK] root password updated."

# finish() (EXIT trap) sets next boot to the OS and reboots.
exit 0
