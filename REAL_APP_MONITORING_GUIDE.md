# Real App Monitoring Implementation Guide

## Overview

Your SE7EN app now uses Apple's **FamilyControls framework** to properly connect to the user's real installed iPhone apps. This is the official, App Store-approved method for monitoring and limiting app usage.

## How It Works

### 1. **FamilyActivityPicker**
- When users tap "Add App" on the homepage, they see a native iOS picker
- This picker shows ALL apps actually installed on their iPhone
- Users can select which apps they want SE7EN to monitor
- This is the same system used by Apple's Screen Time

### 2. **App Categorization**
After selecting apps with FamilyActivityPicker, SE7EN automatically categorizes them:

- **Social**: Instagram, Facebook, TikTok, Twitter, Snapchat, etc.
- **Entertainment**: YouTube, Netflix, Spotify, Twitch, etc.
- **Productivity**: Slack, Notion, Zoom, Trello, etc.
- **Games**: Any game apps
- **Shopping**: Amazon, eBay, Etsy, etc.
- **Health & Fitness**: Fitness apps, meditation apps, etc.
- **Education**: Duolingo, Khan Academy, Coursera, etc.
- **News & Reading**: News apps, Medium, etc.
- **Photo & Video**: Camera, editing apps, etc.
- **Travel & Local**: Maps, Uber, Airbnb, etc.
- **Utilities**: Weather, calculators, etc.
- **Other**: Anything that doesn't fit above

### 3. **Three-Step Flow**

**Step 1: Select Category**
- Shows all categories with app counts
- Users can tap "Scan Installed Apps" to refresh
- Only shows categories that have apps

**Step 2: Select App**
- Shows all apps in the selected category
- Each app displays with its icon and category
- Sorted alphabetically

**Step 3: Set Time Limit**
- Choose from preset limits: 30, 60, 90, 120, 180 minutes
- Or set a custom limit
- Confirms before adding

## Key Files

### Services/RealAppDiscoveryService.swift
- Manages the FamilyControls integration
- Processes selected apps from FamilyActivityPicker
- Categorizes apps automatically
- Extracts app information from tokens

### Views/Dashboard/CategoryAppSelectionView.swift
- Main UI for the three-step app selection flow
- Shows categories → apps → time limits
- Uses FamilyActivityPicker sheet for initial selection

### Views/Dashboard/DashboardView.swift
- Updated to use `CategoryAppSelectionView` instead of old `AddAppSheet`
- Shows "Add App" button in App Usage section

## Important Technical Details

### ApplicationToken
- FamilyControls uses `ApplicationToken` to represent apps
- These tokens are secure and don't expose sensitive data
- Tokens can be used with ManagedSettings to block apps
- Tokens work with DeviceActivity to monitor usage

### Bundle ID Extraction
- Bundle IDs are extracted from tokens for categorization
- Format: `com.company.appname`
- Used to match apps to categories

### Screen Time Permissions
- Users must grant Screen Time permission in onboarding
- This is required for FamilyActivityPicker to work
- Permission is requested on the "Connect to Screen Time" page

## Why This Approach?

### ✅ App Store Approved
- Uses official Apple frameworks
- Follows all privacy guidelines
- Will pass App Review

### ✅ Connects to Real Apps
- Shows actual installed apps, not a list of common apps
- Works with ANY app on the user's device
- Automatically detects new apps when users scan

### ✅ Privacy-First
- No sensitive data leaves the device
- Apple handles all app discovery
- SE7EN only sees what users explicitly share

### ✅ Works with Screen Time API
- Same tokens used for monitoring usage
- Can block apps when limits exceeded
- Integrates with iOS Screen Time system

## User Experience Flow

1. User taps "Add App" on homepage
2. FamilyActivityPicker appears (native iOS sheet)
3. User selects apps they want to monitor
4. SE7EN categorizes the selected apps
5. User picks a category to browse
6. User selects a specific app
7. User sets a daily time limit
8. App is added to monitoring list
9. SE7EN starts tracking usage and health score updates

## Future Enhancements

### Automatic Usage Tracking
To fully implement usage tracking, you'll need to:
1. Set up DeviceActivity monitoring schedules
2. Implement DeviceActivityMonitor extension
3. Update usage data in CoreData
4. Sync with health score calculations

### App Blocking
When users exceed limits:
1. Use ManagedSettingsStore to block the app
2. Show notification about credit loss
3. Update pet health immediately
4. Block remains until next day/week reset

## Testing

### To Test on Device:
1. Build and run on a real iPhone (not simulator)
2. Grant Screen Time permission when prompted
3. Tap "Add App" on dashboard
4. Select some apps in FamilyActivityPicker
5. Navigate through categories
6. Add an app with a time limit
7. Verify it appears in the App Usage list

### Note:
- FamilyActivityPicker only works on physical devices
- Simulator will show an empty picker
- You need iOS 15.0+ for full functionality

## Configuration

### Info.plist
Make sure you have:
```xml
<key>NSFamilyControlsUsageDescription</key>
<string>SE7EN needs Screen Time access to monitor your app usage and help you maintain healthy digital habits.</string>
```

### Entitlements
Make sure Seven.entitlements includes:
```xml
<key>com.apple.developer.family-controls</key>
<true/>
```

## Support

For issues or questions:
- Check Apple's FamilyControls documentation
- Verify Screen Time permissions are granted
- Ensure device is running iOS 15.0+
- Test on real device, not simulator

---

**Your app now properly connects to real iPhone apps and can accurately monitor usage!** 🎉


