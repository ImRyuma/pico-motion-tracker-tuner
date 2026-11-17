# Pico Motion Tracker Tuner

A Magisk module for a **rooted Pico 4 Pro** (tested on A8110, Pico OS 5.13.7, Magisk 30.7) that stops **Pico Motion Trackers** from going to sleep, and therefore dropping out of SteamVR, when they stay still for a long time (for example while lying down). It also ships investigation and measurement tools.

> ⚠️ Personal project, not affiliated with PICO / ByteDance. Use at your own risk, on a rooted headset.

## What the module does

Pico OS switches the trackers to a reduced frequency (sleep) after about a minute of stillness. During a SteamVR session while lying down, they can then disappear from SteamVR while staying connected to the headset.

The **smart mode** (`smart.sh`) watches the `pvrtrackingservice` tracking service:

| Situation | Action |
|---|---|
| Active session, trackers moving | None: Pico OS is already at full frequency |
| Active session, trackers still for `STILL_HOLD` s | Hold full frequency, released as soon as they move again |
| No session, tracker charging, or no tracker | Stock behavior |

A session is detected from the `tracking_mode` condition of the Pico service (an app is using the trackers), with a fallback on the foreground app (PICO Connect).

The hold uses the system tool `pvrtracking_swift_test setKeepTrackerFullFrequencyFlag`. It only lasts while the process is alive: stopping the daemon hands control back to the system.

## Installation

1. Download `pico_tracker_tuner.zip` from the **Releases** page.
2. Install it:

```bash
adb push pico_tracker_tuner.zip /data/local/tmp/
adb shell su -c "magisk --install-module /data/local/tmp/pico_tracker_tuner.zip"
adb reboot
```

Or install the zip from the Magisk app.

## Settings

`/data/adb/modules/pico_tracker_tuner/smart.conf` is reloaded live, no reboot needed:

| Key | Default | Purpose |
|---|---|---|
| `MODE` | `auto` | `auto`, `always` (permanent hold) or `off` |
| `STILL_HOLD` | `20` | Seconds of stillness before holding |
| `SESSION_LINGER` | `300` | How long a session stays active after the last sign of activity |
| `POLL_MOVE` / `POLL_STILL` / `POLL_HOLD` | `15` / `5` / `10` | Polling intervals (s) |

The module's **Action** button in Magisk cycles the mode: auto → always → off.

Live state:

```bash
adb shell su -c "cat /data/adb/modules/pico_tracker_tuner/.smart.state"
```

## Tools (`tools/`)

- `investigate.sh`: general read-only investigation (properties, services, packages, libraries).
- `investigate_swift.sh`: focused investigation of the tracking service and the "Swift" libraries (code name of the trackers).
- `optical_check.sh [seconds]`: measures how often each tracker is seen by the infrared cameras, per role (hip, ankles). Run it during a session, for example to compare hip tracker placements.

The investigation reports contain your headset and tracker serial numbers: do not publish them as is.

## Known limitations

- No IR/IMU weighting setting is exposed: fusion happens inside closed Pico libraries.
- Re-centering the hip relative to the body is not accessible; the Pico algorithm already does it with its body model.
- Holding full frequency uses more tracker battery.

## Uninstall

```bash
adb shell su -c "touch /data/adb/modules/pico_tracker_tuner/remove"
adb reboot
```

The module is systemless: no partition is modified. A guard disables the module after 3 incomplete boots.

## License

[MIT](LICENSE): you are free to use, modify and redistribute this project, including in your own projects, as long as the license notice is kept.
