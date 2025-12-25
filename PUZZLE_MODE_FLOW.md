# Puzzle Mode Flow - Direct Puzzle in Blocked App Context

## Overview

When a user hits their app limit and taps the blocked app, they see a custom shield with a "Solve Puzzle" button. Tapping this button:
1. Opens SE7EN app in **puzzle mode** (fullscreen puzzle, no main UI)
2. User solves the puzzle
3. App is unblocked and **automatically opens**
4. SE7EN app goes to background

## Flow Diagram

```
User taps blocked app (e.g., YouTube)
    ↓
iOS shows custom shield (ShieldConfigurationExtension)
    ↓
User taps "Solve Puzzle for 15 More Minutes"
    ↓
ShieldActionExtension:
  - Sets puzzle flags in shared container
  - Opens SE7EN via URL scheme: se7en://puzzle?tokenHash=...&appName=YouTube
    ↓
SE7EN app opens in Puzzle Mode:
  - ContentView detects puzzleMode flag
  - Shows PuzzleModeView (fullscreen, no tabs/UI)
  - User sees "Daily Limit Reached" → taps "Solve Puzzle"
    ↓
User solves puzzle (Sudoku/Memory/Pattern)
    ↓
Puzzle completes:
  - Grants 15-minute extension
  - Unblocks the app
  - Opens YouTube automatically via URL scheme
  - SE7EN goes to background
    ↓
User is now in YouTube with 15 more minutes!
```

## Files Created/Modified

### New Files:
1. **`Views/Puzzles/PuzzleModeView.swift`**
   - Fullscreen puzzle view (no main app UI)
   - Shows limit reached message → puzzle selection → puzzle
   - Handles completion and opens blocked app

### Modified Files:
1. **`Views/ContentView.swift`**
   - Checks for `puzzleMode` flag on launch
   - Shows `PuzzleModeView` when in puzzle mode
   - Handles opening blocked app after puzzle completion

2. **`SE7ENShieldActionExtension/SE7ENShieldActionExtension.swift`**
   - Opens SE7EN via URL scheme instead of deferring
   - Sets puzzle flags in shared container

3. **`SevenApp.swift`**
   - Handles `se7en://puzzle` URL scheme
   - Sets puzzle mode flags

4. **`Info.plist`**
   - Added `CFBundleURLTypes` with `se7en://` scheme

## Key Implementation Details

### Puzzle Mode Detection
```swift
// ContentView checks for puzzle mode:
if defaults.bool(forKey: "puzzleMode"),
   let tokenHash = defaults.string(forKey: "puzzleTokenHash"),
   let appName = defaults.string(forKey: "puzzleAppName_\(tokenHash)") {
    // Show puzzle mode
}
```

### Opening Blocked App
After puzzle completion, the app tries to open via URL scheme:
- YouTube → `youtube://`
- Instagram → `instagram://`
- TikTok → `tiktok://`
- etc.

If no URL scheme is available, the app is still unblocked and the user can tap it manually.

### URL Scheme Format
```
se7en://puzzle?tokenHash=<hash>&appName=<encoded_name>
```

## User Experience

**Before:**
1. User taps blocked app
2. iOS shows default "Restricted" screen
3. User needs to manually open SE7EN
4. Solve puzzle in SE7EN
5. Manually go back to blocked app

**After:**
1. User taps blocked app
2. Custom shield appears with "Solve Puzzle" button
3. User taps button → Puzzle appears immediately (SE7EN opens but only shows puzzle)
4. User solves puzzle
5. Blocked app opens automatically
6. User continues using the app with 15 more minutes

## Testing

1. Set a very short limit (1-2 minutes) for an app
2. Use the app until limit is reached
3. Try to open the app → Custom shield should appear
4. Tap "Solve Puzzle" → SE7EN should open showing only the puzzle
5. Solve the puzzle → Blocked app should open automatically
6. Verify the app is unblocked and usable

## Notes

- SE7EN app briefly opens but only shows the puzzle UI (no tabs, no main UI)
- After puzzle completion, SE7EN automatically goes to background
- The blocked app opens via URL scheme (if available)
- If URL scheme isn't available, app is still unblocked (user can tap it)
- Extension grants 15 minutes of additional usage time








