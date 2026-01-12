# ⚠️ Quick Fix Required: Set Target Membership for New Shared Files

The refactoring created 5 new shared utility files that are already visible in Xcode (thanks to automatic file synchronization), but they need target membership configured.

## New Files Created:

Located in the `Shared/` folder:
- ✅ `SharedModels.swift` - Centralized data models
- ✅ `SubwayLineFactory.swift` - Dynamic line generation
- ✅ `TimeFormatter.swift` - Unified time formatting
- ✅ `NavigationModels.swift` - Shared navigation types
- ✅ `TerminalStationsHelper.swift` - Terminal station helper

## Quick Fix (2 minutes):

1. **Open** `Now Departing.xcodeproj` in Xcode

2. **Navigate** to the `Shared` folder in Project Navigator
   - You should see all 5 new files listed there

3. **Select the first file** (e.g., `SharedModels.swift`)

4. **In File Inspector** (right panel, ⌥⌘1):
   - Under "Target Membership", check these boxes:
     - ✅ **Now Departing** (iOS app)
     - ✅ **NowDepartingWidgetExtension** (Widget)
     - ✅ **Now Departing Watch Watch App** (watchOS)

5. **Repeat step 4** for each of the remaining 4 files

6. **Build** (⌘B) - all errors should be resolved! ✨

## Alternative: Select All at Once

1. **Hold Shift** and select all 5 new files in Project Navigator
2. **In File Inspector**, set Target Membership for all at once:
   - ✅ Now Departing
   - ✅ NowDepartingWidgetExtension
   - ✅ Now Departing Watch Watch App

## Verify the Fix:

Build all targets to confirm:
- ✅ iOS app builds successfully
- ✅ Widget extension builds successfully
- ✅ Watch app builds successfully

## Why This Happened:

Your project uses Xcode's **PBXFileSystemSynchronizedRootGroup** feature for the Shared folder. This automatically shows files from the filesystem in Xcode, but target membership must still be set manually in the GUI.

When files are created via CLI/automation, Xcode sees them immediately but doesn't know which targets should compile them.
