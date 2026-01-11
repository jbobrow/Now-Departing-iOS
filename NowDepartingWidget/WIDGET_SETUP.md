# Now Departing iOS Widget Setup Guide

This guide will help you add the Now Departing widget extension to your Xcode project.

## Overview

The widget displays real-time train arrival times for your favorite NYC subway stations directly on your iPhone homescreen. It supports three widget sizes:
- **Small**: Compact view with line badge, next train time, and station name
- **Medium**: Horizontal layout with line info and upcoming trains
- **Large**: Full view with detailed arrival times and station information

## Files Created

All widget files are located in the `NowDepartingWidget/` directory:
- `NowDepartingWidget.swift` - Main widget and timeline provider
- `WidgetViews.swift` - UI views for small, medium, and large widgets
- `Info.plist` - Widget extension configuration
- `Assets.xcassets/` - Widget assets and icons

## Setup Instructions

### Step 1: Add Widget Extension Target

1. Open `Now Departing.xcodeproj` in Xcode
2. Go to **File → New → Target**
3. Select **Widget Extension** and click **Next**
4. Configure the target:
   - **Product Name**: `NowDepartingWidget`
   - **Team**: Your development team
   - **Language**: Swift
   - **Include Configuration Intent**: ❌ (unchecked)
   - Click **Finish**
5. When prompted "Activate NowDepartingWidget scheme?", click **Activate**

### Step 2: Replace Generated Files

1. In the Project Navigator, delete the auto-generated files in the `NowDepartingWidget` folder:
   - Delete `NowDepartingWidget.swift` (the template version)
   - Delete `NowDepartingWidgetBundle.swift` (if it exists)
   - Keep `Assets.xcassets` and `Info.plist`

2. Add the new widget files to the target:
   - Right-click on `NowDepartingWidget` folder in Project Navigator
   - Select **Add Files to "Now Departing"...**
   - Navigate to and select:
     - `NowDepartingWidget/NowDepartingWidget.swift`
     - `NowDepartingWidget/WidgetViews.swift`
   - Make sure **Target Membership** includes `NowDepartingWidget`
   - Click **Add**

### Step 3: Add Shared Files to Widget Target

The widget needs access to shared models and configurations:

1. In Project Navigator, select these files from the `Shared/` folder one by one:
   - `FavoriteItem.swift`
   - `SubwayConfiguration.swift`

2. For each file, open the **File Inspector** (right sidebar)

3. Under **Target Membership**, check the box for `NowDepartingWidget`

4. Also add from `Now Departing/` folder:
   - `Models.swift`

### Step 4: Configure App Groups

App Groups allow data sharing between the main app and widget.

#### For the Main App Target:

1. Select the **Now Departing** project in Project Navigator
2. Select the **Now Departing** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **App Groups**
6. Click **+** and add: `group.com.jonathanbobrow.NowDeparting`
   (Replace `jonathanbobrow` with your actual bundle identifier prefix)

#### For the Widget Target:

1. Select the **NowDepartingWidget** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** and add the same group: `group.com.jonathanbobrow.NowDeparting`

### Step 5: Update App Group ID (if needed)

If you're using a different bundle identifier or team:

1. Open `NowDepartingWidget.swift`
2. Find line ~109: `guard let sharedDefaults = UserDefaults(suiteName: "group.com.jonathanbobrow.NowDeparting")`
3. Update the group name to match your App Group ID

4. Open `Shared/FavoriteItem.swift`
5. Find line 33: `private let appGroupId = "group.com.jonathanbobrow.NowDeparting"`
6. Update to match your App Group ID

### Step 6: Build and Run

1. Select the **NowDepartingWidget** scheme from the scheme selector
2. Choose a simulator or device
3. Click **Run** (or press ⌘R)
4. The widget preview will appear
5. Select **Now Departing** from the widget list

### Step 7: Add Widget to Homescreen (on Device)

1. Run the main **Now Departing** app
2. Navigate to a station and add it to your favorites
3. Exit the app and go to your homescreen
4. Long press on the homescreen
5. Tap the **+** button in the top left
6. Search for **Now Departing**
7. Select the widget size you want
8. Tap **Add Widget**
9. The widget will display your first favorite station

## Widget Features

### Automatic Updates
- Refreshes every 30 seconds to show current train times
- Uses iOS system intelligence for battery-efficient updates

### Widget Sizes

**Small (160x160)**
- Line badge with subway line color
- Next train time (e.g., "5 min", "Arriving")
- Station name
- Directional background (curve indicates N/S direction)

**Medium (338x160)**
- Line badge and station information
- Terminal destination
- Next train times

**Large (338x340)**
- Large line badge
- Station name and destination
- Primary train time (72pt font)
- Up to 5 additional upcoming trains
- Error states with visual feedback

### Data Source
- Uses the same API as the main app: `api.wheresthefuckingtrain.com`
- Displays only trains for the selected line and direction
- Shows countdown in minutes until arrival

## Troubleshooting

### Widget shows "Add a favorite in the app"
- Open the main app
- Navigate to Lines → Select a line → Select a station → Select direction
- Tap "Add to Favorites"
- Wait 30 seconds for the widget to refresh

### Widget shows "--" or error message
- Check your internet connection
- Make sure the station has available train times
- The API may be temporarily unavailable

### Widget not updating
- Check that App Groups are configured correctly
- Verify both targets use the same App Group ID
- Try removing and re-adding the widget

### Build errors
- Make sure all shared files are added to the widget target
- Verify App Groups capability is enabled for both targets
- Clean build folder (⇧⌘K) and rebuild

## Technical Details

### Data Flow
1. Main app saves favorites to App Group UserDefaults
2. Widget timeline provider reads favorites from App Group
3. Widget fetches train times from API
4. Widget displays formatted times with countdown
5. Widget refreshes every 30 seconds

### Widget Timeline
- Uses `TimelineProvider` protocol
- Provides snapshot for widget gallery
- Provides placeholder for initial display
- Creates timeline entries with 30-second refresh policy

### Shared Components
- `FavoriteItem`: Data model for favorite stations
- `SubwayConfiguration`: Line colors and styling
- `Models.swift`: API response models
- `DirectionHelper`: Terminal station names

## Next Steps

Consider adding:
- Multiple widget instances for different favorites
- Widget configuration to select which favorite to display
- Complications for Apple Watch
- Live Activities for actively departing trains

## Questions?

If you encounter any issues during setup, check:
1. Xcode version (requires iOS 14+ for widgets)
2. Bundle identifiers match your signing certificate
3. App Groups are enabled in Apple Developer portal
4. Widget target has correct file memberships
