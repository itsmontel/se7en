# Screen Time Troubleshooting Guide

## ✅ FIXES APPLIED

### 1. **Authorization Fixed**
- Fixed missing `do` block in `requestAuthorization()`
- Added detailed logging for authorization status

### 2. **Context Names Verified**
- ✅ Main app: `DeviceActivityReport.Context.todayOverview`
- ✅ Extension: `DeviceActivityReport.Context.todayOverview`
- Both use identical context name: `"todayOverview"`

### 3. **DeviceActivityFilter Fixed**
- Changed from `.users: .all` to `.users: .individual`
- Changed from `.devices: .all` to `.devices: .init([.iPhone, .iPad])`
- This targets the correct user scope for Family Controls

### 4. **Global Monitoring Added**
- Added `setupGlobalMonitoringForReports()` function
- Creates a 24-hour monitoring session specifically for DeviceActivityReport
- Uses very high threshold (1440 minutes) that won't block but enables reporting
- Called automatically when setting up category or app monitoring

## 🔧 NEXT STEPS FOR USER

### **CRITICAL: Check Device Settings**

1. **Go to Settings > Screen Time**
2. **Tap "App & Website Activity"**
3. **Ensure your SE7EN app is listed and ENABLED**
4. **If not listed, the app lacks proper Screen Time permission**

### **Verify Authorization Status**
Run the app and check console logs for:
```
🔐 Authorization status: approved
```
If it shows `notDetermined` or `denied`, authorization failed.

### **Complete Onboarding Properly**
1. Go through onboarding flow
2. Select apps/categories in FamilyActivityPicker
3. Ensure `allAppsSelection` is not empty

### **Test the Fix**
1. Use some apps for 5-10 minutes
2. Reopen SE7EN app
3. Check console for:
   ```
   📊 TodayOverviewReport: totalDuration=XXXs uniqueApps=X
   💾 TodayOverviewReport: Saved summary to shared container
   ```

## 🐛 IF STILL NOT WORKING

### **Check Console Logs For:**
- `❌ Failed to start global monitoring` - Permission issue
- `📊 TodayOverviewReport: totalDuration=0s` - No usage detected
- `⚠️ allAppsSelection is nil` - Onboarding incomplete

### **Common Issues:**
1. **Screen Time disabled system-wide** - Enable in Settings > Screen Time
2. **App not in "App & Website Activity"** - Reinstall app or reset Screen Time
3. **Family sharing conflicts** - Ensure you're the organizer or have proper permissions
4. **iOS version too old** - Requires iOS 15.0+

## 🎯 EXPECTED BEHAVIOR

After fixes:
- Authorization should be `approved`
- Global monitoring session should start successfully
- DeviceActivityReport extensions should receive data
- Shared container should show non-zero values
- Dashboard should display actual usage instead of "0 minutes"

The key insight: DeviceActivityReport extensions only receive data when there are **active monitoring sessions**. The global monitoring session ensures data flows to extensions even without individual app limits.

