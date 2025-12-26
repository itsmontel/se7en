# Shield Extensions Setup Guide

This guide explains how to set up the Shield Configuration and Shield Action extensions to show your custom puzzle UI instead of the default iOS restriction screen.

## Overview

When an app hits its limit, iOS shows a shield screen. By default, this is a generic "Restricted" screen. With these extensions, you can:
1. **Customize the shield UI** (ShieldConfigurationExtension)
2. **Handle button taps** to open your app and show the puzzle (ShieldActionExtension)

## Files Created

1. `SE7ENShieldConfigurationExtension/SE7ENShieldConfigurationExtension.swift` - Customizes shield appearance
2. `SE7ENShieldActionExtension/SE7ENShieldActionExtension.swift` - Handles button taps
3. `Shared/SharedStorageHelper.swift` - Shared utilities for puzzle tracking

## Setup Steps in Xcode

### 1. Create Shield Configuration Extension

1. In Xcode: **File → New → Target**
2. Select **"Shield Configuration Extension"**
3. Name it: `SE7ENShieldConfigurationExtension`
4. Language: **Swift**
5. Click **Finish**

6. **Replace the generated file** with:
   - `SE7ENShieldConfigurationExtension/SE7ENShieldConfigurationExtension.swift`

7. **Update Info.plist** (if needed):
   - The extension should automatically have the correct `NSExtension` settings
   - Ensure `NSExtensionPointIdentifier` = `com.apple.shield-configuration`

8. **Add to App Group**:
   - Select the extension target
   - Go to **Signing & Capabilities**
   - Add **App Groups** capability
   - Add: `group.com.se7en.app`

### 2. Create Shield Action Extension

1. In Xcode: **File → New → Target**
2. Select **"Shield Action Extension"**
3. Name it: `SE7ENShieldActionExtension`
4. Language: **Swift**
5. Click **Finish**

6. **Replace the generated file** with:
   - `SE7ENShieldActionExtension/SE7ENShieldActionExtension.swift`

7. **Update Info.plist** (if needed):
   - Ensure `NSExtensionPointIdentifier` = `com.apple.shield-action`

8. **Add to App Group**:
   - Select the extension target
   - Go to **Signing & Capabilities**
   - Add **App Groups** capability
   - Add: `group.com.se7en.app`

### 3. Update Main App

The main app (`SevenApp.swift`) has already been updated to:
- Check for pending puzzles when the app becomes active
- Show the puzzle UI when a puzzle is requested from the shield

The `AppState` class has a new method `checkForPendingPuzzles()` that:
- Reads puzzle flags from shared storage
- Posts `.appBlocked` notifications
- The `DashboardView` listens to these notifications and shows `LimitReachedPuzzleView`

## How It Works

### Flow:

1. **App hits limit** → `DeviceActivityMonitorExtension` blocks the app
2. **User taps blocked app** → iOS shows custom shield (from ShieldConfigurationExtension)
3. **User taps "Solve Puzzle"** → ShieldActionExtension:
   - Sets `needsPuzzle_<tokenHash>` flag in shared container
   - Stores app name for lookup
   - Returns `.defer` to open the main app
4. **Main app opens** → `checkForPendingPuzzles()`:
   - Finds pending puzzle flags
   - Posts `.appBlocked` notification
   - DashboardView shows `LimitReachedPuzzleView`
5. **User solves puzzle** → App is unblocked for 15 minutes

## Testing

1. Set a very short limit (e.g., 1 minute) for an app
2. Use the app until it hits the limit
3. Try to open the app again
4. You should see the custom shield with "Solve Puzzle" button
5. Tap the button
6. The SE7EN app should open and show the puzzle UI

## Troubleshooting

### Shield doesn't appear / Shows default iOS screen
- Ensure both extensions are properly signed
- Check that extensions are included in the build
- Verify App Group is set up correctly in all targets

### Puzzle doesn't show when app opens
- Check console logs for "🎯 AppState: Showing puzzle..."
- Verify `needsPuzzle_<tokenHash>` is set in shared container
- Ensure DashboardView is listening to `.appBlocked` notifications

### Extensions not found
- Make sure extensions are added to the correct target
- Clean build folder (Cmd+Shift+K) and rebuild
- Check that extension bundle IDs are correct in project settings

## Notes

- The extensions run in separate processes from the main app
- They communicate via App Group shared container (`group.com.se7en.app`)
- The shield UI is shown by iOS, not your app
- The puzzle UI is shown in your main app after the shield action










