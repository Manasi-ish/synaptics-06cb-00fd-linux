# Synaptics `06cb:00fd` fingerprint reader on Linux — working

**USB ID:** `06cb:00fd` (Synaptics, "Tudor" match-in-sensor)
**Seen on:** Lenovo IdeaPad 3 14ITL6, ThinkPad E14 Gen 3, ThinkBook 15 G13

Upstream `libfprint` does **not** support this sensor, and it used to be listed as
*"no known fix"*. It **now works on Linux** — enrollment, boot/login, the lock/suspend
screen and `sudo` — via the [synaTudor][synatudor] relinker, which runs Synaptics' own
Windows driver at runtime and exposes it to `fprintd` as a `libfprint-tod` module.

---

## Status (verified)

Ubuntu 26.04 · fprintd 1.94.5 · libfprint 1.95.1+tod1 · Regolith/sway + GDM · IdeaPad 3 14ITL6:

```
$ fprintd-list $USER
found 1 devices
Device at /net/reactivated/Fprint/Device/0
```

- ✅ enrollment (`fprintd-enroll` / GNOME Settings → Fingerprint)
- ✅ boot / login screen (GDM)
- ✅ lock & suspend/resume screen (gtklock)
- ✅ `sudo` / terminal login (PAM)

## How to use it

```bash
# 1) get the fork that targets 06cb:00fd (uses the IdeaPad driver package, DLLs v139)
git clone -b relink https://github.com/n00b-t00b/synaTudor.git
cd synaTudor
# apply the fixes from the PRs below (they are all in github.com/Manasi-ish/synaTudor)

# 2) build & install (TOD module, launcher, udev rule)
meson setup build -DUNMOUNTFS=true
ninja -C build && sudo ninja -C build install
sudo udevadm control --reload && sudo udevadm trigger
sudo systemctl restart fprintd

# 3) enroll
fprintd-list "$USER"      # -> found 1 devices
fprintd-enroll            # touch the sensor ~8-10x, centred and flat

# 4) make it usable at login / lock / sudo
sudo ./contrib/enable-fingerprint-login.sh
```

## The fix (what was actually missing)

The relinked driver kept hitting unimplemented Windows APIs. The pieces:

**Generic (any Tudor sensor):**
- **WDF index 50 `WdfDeviceAssignInterfaceProperty`** (+ 51/52) — the wall that blocked
  every prior attempt. Implemented as a keyed property store.
- Claim the **USB interface up-front** (fixes capture: `usbfs … did not claim interface 0`).
- **`GetModuleHandleW(NULL)`** fix + USER32/power/WTS/registry stubs.
- Raised IPC record/message **size caps** (the v139 driver makes ~194 KB records).
- Build fixes for modern GCC.

**`06cb:00fd`-specific:**
- IdeaPad consumer driver package (`xalc0l0fqu9mwjc0.exe`, DLLs **v139**) instead of the
  ThinkPad package.
- Add `06cb:00fd` to the TOD id table + udev rule.

## Links

- Upstream PRs: **Popax21/synaTudor#70** (generic relinker fixes) · **#71** (`06cb:00fd` support)
- Full fork + write-up: **github.com/Manasi-ish/synaTudor** (branch `06cb-00fd-support`):
  - `STATUS_WORKING.md` — complete list of fixes + reproduce steps
  - `REVERSE_ENGINEERING_HANDBOOK.md` — the method
  - `contrib/` — boot warm-up service + `enable-fingerprint-login.sh`

## Why not in `libfprint` itself?

The relink runs Synaptics' **proprietary** Windows binaries; upstream `libfprint` only
accepts free/open drivers. The clean long-term route is a clean-room open driver (like
`python-validity` did for the Prometheus family) — see `06cb:009a` for precedent. Until
then, the relink is the working solution.

## Caveats

- Runs Synaptics' proprietary Windows DLLs; **x86-64 only**. The project warns about
  bricked sensors / corrupted firmware — keep a Windows fallback in mind.
- Different OEM packages (IdeaPad vs ThinkPad) may ship different DLL versions; the
  DLL-name bump in the PR is what ties them together.

[synatudor]: https://github.com/Popax21/synaTudor
