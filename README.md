# Synaptics `06cb:00fd` Fingerprint Reader on Linux

Linux support for the **Synaptics `06cb:00fd`** fingerprint reader (Lenovo IdeaPad 3
14ITL6 / ThinkBook 15 G13 and similar), built on [synaTudor](https://github.com/Popax21/synaTudor)
with the fixes needed for this specific device.

Upstream `libfprint` does not support this sensor and it used to be listed as *"no known fix"*.
This repo gets it working — **enrollment, boot/login, lock/suspend and sudo**.

## Tested hardware

| Field | Value |
|-------|-------|
| USB ID | `06cb:00fd` |
| Family | Synaptics "Tudor" match-in-sensor |
| Tested on | Lenovo IdeaPad 3 14ITL6 — Ubuntu 26.04, Regolith/sway + GDM |
| fprintd / libfprint | 1.94.5 / 1.95.1+tod1 |

```
$ fprintd-list $USER
found 1 devices
Device at /net/reactivated/Fprint/Device/0
```

## What this adds

synaTudor upstream supports `06cb:00be`. The patches in `patches/` extend it to `06cb:00fd`:

- **IdeaPad driver package** — `download_driver.sh` uses the Lenovo *consumer* package
  (`xalc0l0fqu9mwjc0.exe`) which contains the `00fd` id (Synaptics DLLs **v139**).
- **DLL names** — bumped to v139 (`synaFpAdapter139.dll`, `synaWudfBioUsb139.dll`).
- **libfprint-tod** — added `06cb:00fd` to the id table + udev rule.
- **WDF interface-property store** — implemented `WdfDeviceAssignInterfaceProperty` and
  friends (table index 50–52). This is the wall that blocks every Tudor attempt.
- **USB interface claim** — fixes capture (`usbfs: ... did not claim interface 0`).
- **`GetModuleHandle(W/A)(NULL)`** fix + USER32 / power / WTS / registry stubs.
- **Size caps** — raised for the v139 driver's larger (~194 KB) enrollment records.
- **Boot warm-up service** — the driver needs ~4 s to load before the login/lock screen
  asks for it.

## Requirements

- An x86-64 machine (the relink runs Synaptics' Windows DLLs).
- Ubuntu/Debian-based with systemd. (Package names below assume `apt`.)
- The sensor is a **Tudor match-in-sensor** — network/Windows only for the vendor driver;
  no upstream free driver exists yet.

## Installation

```bash
git clone https://github.com/Manasi-ish/synaptics-06cb-00fd-linux.git
cd synaptics-06cb-00fd-linux
sudo ./install.sh
```

The script will:

1. install build dependencies,
2. clone upstream synaTudor at a pinned commit and apply `patches/`,
3. build (this downloads the Lenovo IdeaPad driver package to extract the DLLs),
4. install the TOD module + host launcher + udev rule,
5. install/enable the `tudor-warm.service` warm-up service,
6. enable fingerprint auth for login / lock screen / sudo via PAM.

## Enroll your fingerprint

```bash
fprintd-enroll
# touch the sensor ~8-10 times, centred and flat
```

Or with the raw CLI (debugging):

```bash
sudo /sbin/tudor/tudor_cli /var/lib/tudor/data.db -P00fd
```

## PAM (login / lock / sudo)

`install.sh` runs `pam-auth-update --enable fprintd`, which adds `pam_fprintd` to
`/etc/pam.d/common-auth`. `login`, `gdm`/GDM and `gtklock` inherit it, so the lock and
login screens offer the finger, with password fallback.

## Manual / other distros

If you don't use the script: build the `06cb-00fd` branch of
[synaTudor](https://github.com/Manasi-ish/synaTudor) with `meson setup build -DUNMOUNTFS=true
&& ninja -C build && sudo ninja -C build install`, then `udevadm control --reload &&
udevadm trigger`. See the branch's `STATUS_WORKING.md` and `contrib/`.

## Credits

- [synaTudor](https://github.com/Popax21/synaTudor) by **Popax21** — the relinker for the
  Synaptics Tudor family; this project is a small addition on top.
- `06cb:00fd` bring-up + the generic relinker fixes by **Manasi-ish** —
  upstream PRs [Popax21/synaTudor#70](https://github.com/Popax21/synaTudor/pull/70)
  (generic) and [#71](https://github.com/Popax21/synaTudor/pull/71) (`06cb:00fd`).

## Notes / caveats

- x86-64 only; runs Synaptics' proprietary Windows binaries (the project warns about
  bricked sensors / corrupted firmware — keep a Windows fallback in mind).
- The sensor stores host pairing data on-chip; pairing with Linux can invalidate a
  Windows Hello pairing (dual-boot caveat, same as other Tudor sensors).
- A proper open (clean-room) libfprint driver would be the ideal long-term fix; this
  works today.
