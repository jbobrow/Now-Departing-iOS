# Live Activity Setup for StandBy Mode

This document explains how to set up and use the Live Activity feature for iOS StandBy mode.

## What is StandBy Mode?

StandBy is an iOS 17+ feature that displays full-screen information when your iPhone is:
- Charging
- Placed horizontally (landscape orientation)
- On a stand or MagSafe charger

## Features

The Now Departing Live Activity shows:
- **Line badge** with the train line color and label
- **Station name** and destination
- **Real-time countdown** with the primary train time in large text
- **Additional upcoming trains** (up to 2 more trains)
- **Auto-updating** every time the train times refresh

## Required Configuration

### 1. Info.plist Configuration

Add the following key to your app's `Info.plist`:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

### 2. App Group (Already Configured)

The app uses the App Group `group.com.move38.Now-Departing` to share data between the main app and the widget extension.

## How to Use

### Starting a Live Activity

1. Open the Now Departing app
2. Navigate to a train line and station
3. Select a direction
4. Tap the **"Start Live Activity"** button
5. The Live Activity will appear in:
   - Your lock screen
   - The Dynamic Island (iPhone 14 Pro and later)
   - **StandBy mode when your phone is charging horizontally**

### Using in StandBy Mode

1. Start a Live Activity (see above)
2. Place your iPhone horizontally on a charger
3. The full-screen display will show:
   - Left side: Line badge and station info
   - Right side: Large countdown timer with upcoming trains

### Stopping a Live Activity

1. Return to the TimesView screen
2. Tap **"Stop Live Activity"**
3. Or simply navigate away from the screen (it will auto-stop)

## Layout Details

### StandBy/Lock Screen Layout
- Black background with white text
- Line badge: 80x80pt circle on the left
- Station name in 28pt bold font
- Primary time in 72pt bold font on the right
- Additional times in 22pt font

### Dynamic Island Layout
- **Compact Leading**: Line badge (20x20pt)
- **Compact Trailing**: Primary time (abbreviated)
- **Expanded Leading**: Line badge (32x32pt)
- **Expanded Trailing**: Primary time in 24pt
- **Expanded Bottom**: Station name and additional times

## Technical Details

### Files Modified/Created

1. **`NowDepartingWidgetLiveActivity.swift`** - Live Activity UI and configuration
2. **`LiveActivityManager.swift`** - Manager class for starting/stopping/updating Live Activities
3. **`LinesBrowseView.swift`** - Added UI button and integration

### Data Structure

**ActivityAttributes** (fixed properties):
- Line ID, label, colors (RGB components)
- Station name and display name
- Direction and destination station

**ContentState** (dynamic properties):
- Array of train times (minutes, seconds)
- Last updated timestamp

### Update Frequency

- Live Activities update automatically when the `TimesViewModel` refreshes train times
- The view model refreshes data every 5 minutes from the API
- The timer updates the countdown display every second locally

## Requirements

- iOS 16.2 or later for Live Activities
- iOS 17 or later for StandBy mode
- iPhone 14 Pro or later for Dynamic Island
- Active internet connection for real-time train data

## Troubleshooting

### Live Activity button not showing
- Ensure you're running iOS 16.2 or later
- Check that `NSSupportsLiveActivities` is set in Info.plist
- Verify Live Activities are enabled in Settings > Face ID & Passcode > Live Activities

### StandBy mode not showing
- Ensure you're running iOS 17 or later
- Place iPhone horizontally while charging
- Check that StandBy is enabled in Settings > StandBy

### Times not updating
- Verify you have an active internet connection
- Check that the app has location permissions (if required)
- Ensure the subway line has active service

## Future Enhancements

Potential improvements:
- Push notifications for arriving trains
- Service alerts in Live Activity
- Multiple train routes in one Live Activity
- Background updates using push tokens
