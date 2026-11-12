# Notes for Claude Code: App Store screenshots

This folder renders the App Store screenshots for Now Departing. Read `README.md` for the layout of the folder and the current status of each capture.

## Commands

- Render everything: `python3 build.py`
- Render some: `python3 build.py 01-widgets 03-lines`
- Chrome elsewhere: `CHROME=/path/to/chrome python3 build.py`

`build.py` exits non-zero if a capture is missing or an output is the wrong size. It prints `stand-in` for any screen whose `"standin"` flag is still `true`.

## Rules

- Captures must be real screens from the app or the device. Never draw or mock the app's UI, the widgets, the subway route bullets, or other apps' icons.
- Copy lives in `screens.json` only. `\n` in a headline forces a line break. Keep headlines to three lines at most so they clear the device frame.
- Output must stay exactly the size in `screens.json` (1320 × 2868) with no alpha channel. `build.py` checks both.
- Do not show debug text, notification badges, or personal data in a capture. Retake the capture instead of editing the image.
- Keep the order. Screens 01 to 03 are what people see in App Store search results.
- Fonts in `fonts/` are bundled so rendering needs no network. Do not swap them for a web link.

## Layouts

| `layout` | Captures | Notes |
| --- | --- | --- |
| `phone` | 1 | Whole phone visible |
| `phone-bleed` | 1 | Larger phone that runs off the bottom edge. Shows roughly the top 79% of the capture. Used for the Home Screen so the dock stays out of frame |
| `watch-pair` | 2 | Two watch screens stacked |

To add a layout, add its CSS and a branch in `page()` in `build.py`.

## Suggested work for the next release

These are suggestions for Jon to approve, not standing instructions.

1. Add a screenshot mode to the app, for example a `-screenshots` launch argument, that loads fixed sample departures and a fixed location. That makes captures repeatable. (The "Location updated ... (#N)" label seen in the old listing captures is no longer in `Now Departing/NearbyView.swift` on main, so fresh captures should already be clean.)
2. Done in Nov 2026: captures 02 to 06 were retaken from the current build in fresh iPhone 18 Pro Max (iOS 27) and Apple Watch Series 11 46mm (watchOS 27) Simulators. The watch favorites were seeded with `defaults write` into the watch app's container preferences.
3. The two watch captures are already at the watch's native size (416 × 496), so they can also go in the App Store's Apple Watch slot.
4. If the repo uses fastlane, copy `out/*.png` into its screenshots folder as part of the release lane.
