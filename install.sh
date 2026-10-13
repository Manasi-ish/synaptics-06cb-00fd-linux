#!/usr/bin/env bash
#
# install.sh - one-command install for the Synaptics 06cb:00fd fingerprint reader
# on Linux (Ubuntu/Debian based).
#
# It clones upstream synaTudor at a pinned commit, applies this repo's patches
# (patches/0001* = generic relinker fixes, patches/0002* = 06cb:00fd support),
# builds, installs the libfprint TOD module + host launcher + udev rule, installs
# a boot-time warm-up service, and enables fingerprint auth for login / lock / sudo.
#
# Usage:   sudo ./install.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO:-https://github.com/Popax21/synaTudor.git}"
BASE_COMMIT="${BASE_COMMIT:-31dfdb06107fd1c35c9f9ceae72617e98eccc43a}"
SRC="${SRC:-/root/synaTudor-00fd}"

[ "$(id -u)" -eq 0 ] || { echo "Please run as root:  sudo ./install.sh"; exit 1; }

echo "==> Installing build dependencies"
apt-get update -qq
apt-get install -y --no-install-recommends \
    git build-essential meson ninja-build pkg-config innoextract wget ca-certificates \
    libglib2.0-dev libusb-1.0-0-dev libssl-dev libcap-dev libseccomp-dev \
    libdbus-1-dev libsystemd-dev libudev-dev libjson-glib-dev libgusb-dev \
    libfprint-2-dev libfprint-2-tod-dev fprintd

echo "==> Fetching upstream synaTudor (pinned at $BASE_COMMIT)"
if [ -d "$SRC/.git" ]; then
    git -C "$SRC" fetch origin
else
    git clone "$REPO" "$SRC"
fi
git -C "$SRC" checkout -f "$BASE_COMMIT"
git -C "$SRC" clean -fdx

echo "==> Applying this repo's patches"
for p in "$HERE"/patches/*.patch; do
    echo "    $(basename "$p")"
    git -C "$SRC" apply --whitespace=nowarn "$p"
done

echo "==> Building (downloads the Lenovo IdeaPad driver package to extract the DLLs)"
cd "$SRC"
rm -rf build
meson setup build -DUNMOUNTFS=true
ninja -C build

echo "==> Installing (TOD module, host launcher, udev rule)"
ninja -C build install
udevadm control --reload
udevadm trigger

echo "==> Boot-time warm-up service (driver needs ~4s to load before GDM/lock ask)"
install -m 0644 "$HERE/tudor-warm.service" /etc/systemd/system/tudor-warm.service
systemctl daemon-reload
systemctl enable --now tudor-warm.service || true

echo "==> Enabling fingerprint for login / lock screen / sudo (PAM)"
if [ -f /usr/share/pam-configs/fprintd ]; then
    DEBIAN_FRONTEND=noninteractive pam-auth-update --enable fprintd
fi

systemctl restart fprintd 2>/dev/null || true

echo
echo "Done."
echo "Now enroll a finger:"
echo "    fprintd-enroll"
echo "(touch the sensor ~8-10 times, centred and flat)"
