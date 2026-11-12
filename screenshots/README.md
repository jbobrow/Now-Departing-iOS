# Now Departing: App Store screenshots

Six iPhone screenshots for the App Store listing, rendered at 1320 × 2868 (the 6.9-inch slot) from real captures plus a headline.

```
python3 build.py              # render all six into out/
python3 build.py 03-lines     # render one
```

Needs Python 3 and Google Chrome. No packages to install.

## What is in here

| Path | What it is |
| --- | --- |
| `screens.json` | The copy, order and layout of each screenshot. Edit headlines here |
| `captures/` | One raw screen capture per slot. Replace these to update a screenshot |
| `build.py` | Builds the pages and renders them with headless Chrome |
| `out/` | The finished PNGs to upload |
| `fonts/` | Bricolage Grotesque (SIL Open Font License), the typeface from apps.jonbobrow.com |
| `build/` | Generated pages. Safe to delete |

## Status

| Screenshot | Capture | State |
| --- | --- | --- |
| 01 Widgets | `captures/01-widgets.png` | Real Home Screen capture. Ready |
| 02 Nearby | `captures/02-nearby.png` | iPhone 18 Pro Max Simulator, iOS 27, Grand Central. Ready |
| 03 Lines | `captures/03-lines.png` | iPhone 18 Pro Max Simulator, iOS 27. Ready |
| 04 Countdown | `captures/04-countdown.png` | iPhone 18 Pro Max Simulator, iOS 27, uptown 5 at Grand Central. Ready |
| 05 Apple Watch | `captures/05-watch-countdown.png`, `captures/05-watch-list.png` | Series 11 46mm Simulator, watchOS 27, seeded favorites. Native 416 × 496, so slightly soft at frame size. Ready |
| 06 Free | `captures/06-free.png` | iPhone 18 Pro Max Simulator, iOS 27, Times Square. Ready |

All six are upload-ready (Nov 2026). `build.py` prints which screens still use stand-ins.

## Replacing a capture

1. Take the screenshot (see below).
2. Save it into `captures/` under the slot's name, for example `captures/02-nearby.png`. PNG or JPEG both work. Delete the old `.jpg` so only one file has that name.
3. In `screens.json`, set that screen's `"standin"` to `false`.
4. Run `python3 build.py`.

Captures do not have to be 1320 × 2868, because each one sits inside a frame. Any current iPhone size is fine.

From the Simulator:

```
xcrun simctl status_bar booted override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
xcrun simctl io booted screenshot captures/02-nearby.png
xcrun simctl status_bar booted clear
```

The widget screenshot (01) is a Home Screen capture. It is cropped above the Search pill, so the dock never shows.

## Before uploading

- Every screen says `ready` when you run `build.py`.
- No capture shows debug text. The old listing captures did; the label is gone from the current code.
- Upload the six files in `out/` to the 6.9-inch iPhone slot in App Store Connect, in numbered order. The first three are the ones shown in search results.
- The Apple Watch slot takes its own watch-sized captures. Screenshot 05 is part of the iPhone set only.
