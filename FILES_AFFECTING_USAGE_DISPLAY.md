# Files That Affect App Usage Not Showing

## 🎯 Critical Files (Core Data Flow)

### 1. **Report Extension** (Processes Screen Time Data)
- **`SE7ENDeviceActivityReportExtension/TodayOverviewReport.swift`**
  - **Purpose**: Processes DeviceActivity data and calculates usage
  - **Key Functions**:
    - `makeConfiguration()` - Receives data from iOS Screen Time API
    - `sanitizedAppName()` - Filters placeholder app names
    - `saveSummaryToSharedContainer()` - Saves to shared UserDefaults
  - **What to check**: Extension being invoked, data received, shared container writes

- **`SE7ENDeviceActivityReportExtension/TotalActivityReport.swift`**
  - **Purpose**: Alternative report context for total activity
  - **Key Functions**: Same as TodayOverviewReport
  - **What to check**: Same as above

- **`SE7ENDeviceActivityReportExtension/SE7ENDeviceActivityReportExtension.swift`**
  - **Purpose**: Main extension entry point
  - **Key**: Registers report scenes (`TodayOverviewReport`, `TotalActivityReport`)
  - **What to check**: Extension initializes, scenes registered correctly

### 2. **Monitor Extension** (Triggers Events)
- **`SE7ENDeviceActivityMonitorExtension/SE7ENDeviceActivityMonitorExtension.swift`**
  - **Purpose**: Handles threshold events (warning/limit reached)
  - **Key Functions**: `handleUpdate()`, `handleWarning()`, `handleLimit()`
  - **What to check**: Events firing, shared container updates

### 3. **Main App Service** (Orchestrates Everything)
- **`Services/ScreenTimeService.swift`**
  - **Purpose**: Central Screen Time management
  - **Key Functions**:
    - `requestAuthorization()` - Gets Screen Time permission
    - `setupGlobalMonitoringForReports()` - **CRITICAL**: Enables report extension data flow
    - `refreshAllMonitoring()` - Restarts monitoring sessions
    - `getTotalScreenTimeToday()` - Reads usage data
    - `updateUsageFromAllAppsSelection()` - Processes category/app selection
  - **What to check**: 
    - Authorization status
    - Monitoring sessions active
    - `allAppsSelection` populated (apps OR categories)

### 4. **Dashboard View** (Displays Data)
- **`Views/Dashboard/DashboardView.swift`**
  - **Purpose**: Main UI that shows usage
  - **Key Functions**:
    - `loadScreenTimeData()` - Fetches and displays usage
    - `readUsageFromSharedContainer()` - Reads from app group
    - `todayOverviewReportView` - Embeds `DeviceActivityReport(.todayOverview)`
    - `getTopAppsFromAllApps()` - Shows top distractions
  - **What to check**:
    - `DeviceActivityReport` views rendered
    - Shared container reads working
    - Filter scope matches authorization (`.all` not `.children`)

### 5. **App State** (State Management)
- **`Models/AppState.swift`**
  - **Purpose**: Manages app-wide state
  - **Key Functions**:
    - `loadAppGoals()` - Loads monitored apps
    - `refreshScreenTimeData()` - Triggers data refresh
    - `getCurrentUsage()` - Gets usage for individual apps
  - **What to check**: State updates triggering refreshes

---

## 🔧 Supporting Files

### 6. **Report Service** (Helper)
- **`Services/DeviceActivityReportExtension.swift`**
  - **Purpose**: Helper methods for fetching usage from reports
  - **Key Functions**: `fetchUsageForApp()`, `updateUsageRecord()`
  - **What to check**: Usage record updates

### 7. **Core Data Manager** (Storage)
- **`Models/CoreDataManager.swift`**
  - **Purpose**: Persistent storage for goals and usage records
  - **Key Functions**: `getTodaysUsageRecord()`, `createUsageRecord()`
  - **What to check**: Usage records created/updated correctly

### 8. **Usage Summary** (Data Model)
- **`SE7ENDeviceActivityReportExtension/UsageSummary.swift`**
  - **Purpose**: Data structure for report summary
  - **What to check**: Structure matches what's saved/read

### 9. **Report Views** (UI)
- **`SE7ENDeviceActivityReportExtension/TodayOverviewView.swift`**
- **`SE7ENDeviceActivityReportExtension/TotalActivityView.swift`**
  - **Purpose**: SwiftUI views for displaying report data
  - **What to check**: Views render correctly

---

## ⚙️ Configuration Files

### 10. **Entitlements** (Permissions)
- **`SE7ENDeviceActivityReportExtension/SE7ENDeviceActivityReportExtension.entitlements`**
  - **Must have**: 
    - `com.apple.developer.family-controls` = YES
    - `com.apple.security.application-groups` = `["group.com.se7en.app"]`

- **`SE7ENDeviceActivityMonitorExtension/SE7ENDeviceActivityMonitorExtension.entitlements`**
  - **Must have**: Same as above

- **`Seven.entitlements`** (Main app)
  - **Must have**: Same as above

### 11. **Info.plist Files**
- **`SE7ENDeviceActivityReportExtension/Info.plist`**
  - **Must have**: Extension point configured correctly
- **`SE7ENDeviceActivityMonitorExtension/Info.plist`**
  - **Must have**: Extension point configured correctly

### 12. **Project Configuration**
- **`Seven.xcodeproj/project.pbxproj`**
  - **What to check**: 
    - Extensions included in build
    - App Groups configured
    - Signing certificates match

---

## 🔍 Debugging Checklist

### **If usage shows 0:**

1. **Check Extension Invocation**
   - Look for: `🚀 TodayOverviewReport.makeConfiguration: EXTENSION INVOKED!`
   - If missing: Extension not being triggered by `DeviceActivityReport` view

2. **Check Monitoring Sessions**
   - Look for: `✅ Started global monitoring for DeviceActivityReport extensions`
   - If missing: `setupGlobalMonitoringForReports()` not called

3. **Check Authorization**
   - Look for: `🔐 Authorization status: approved`
   - If not approved: User needs to grant Screen Time permission

4. **Check Data Received**
   - Look for: `📦 Processing deviceActivityData...`
   - If missing: No data from iOS Screen Time API

5. **Check Shared Container**
   - Look for: `💾 TodayOverviewReport: Saved summary to shared container`
   - If missing: App Group not configured or write failing

6. **Check Dashboard Reads**
   - Look for: `📊 Found total_usage in shared container`
   - If missing: Dashboard not reading from shared container

7. **Check Filter Scope**
   - Verify: `DeviceActivityFilter(users: .all)` not `.children`
   - Mismatch causes no data for `.individual` authorization

8. **Check App Selection**
   - Verify: `allAppsSelection` has apps OR categories
   - Empty selection = no data to monitor

---

## 🚨 Most Common Issues

1. **Extension not invoked** → `DeviceActivityReport` view not rendered or monitoring not active
2. **No monitoring session** → `setupGlobalMonitoringForReports()` not called
3. **Filter mismatch** → Using `.children` with `.individual` authorization
4. **Empty selection** → `allAppsSelection` is nil or empty
5. **App Group mismatch** → Different group IDs in entitlements
6. **No data yet** → Need to use apps AFTER monitoring starts (no historical data)

---

## 📊 Data Flow Path

```
iOS Screen Time API
    ↓
DeviceActivityReport Extension (TodayOverviewReport.swift)
    ↓ (processes data)
Shared UserDefaults (group.com.se7en.app)
    ↓
DashboardView.swift (reads shared container)
    ↓
UI Display
```

**Critical**: Monitoring must be active for extension to receive data!







