# Seven - Quick Start Guide

## 🚀 Getting Started in 5 Minutes

### Prerequisites
- macOS with Xcode 15.0+
- iOS 16.0+ Simulator or Device
- No additional dependencies required!

### Step 1: Open in Xcode
1. Navigate to `/Users/anthonymaxson/Downloads/SE7EN App/`
2. Double-click `SevenApp.swift` to open in Xcode
3. Wait for Xcode to index the project

### Step 2: Run the App
1. Select an iPhone simulator (iPhone 14 Pro recommended)
2. Press `⌘R` or click the Play button
3. The app will compile and launch

### Step 3: Experience the App

#### 🎭 Onboarding Flow
1. **Welcome Screen** - See the animated "7" logo
2. Tap "Continue"
3. **How It Works** - Read the 3-step explanation
4. Tap "Next"
5. **Why It Works** - Understand the psychology
6. Tap "Next"
7. **Set Goals** - Toggle Instagram, TikTok, or Snapchat
8. Set time limits using the pickers
9. Tap "Activate Monitoring"
10. **Paywall** - Tap "Start for $7"
11. ✅ You're in!

#### 🏠 Main App
After onboarding, explore the 4 main tabs:

**1. Dashboard Tab**
- See the animated credit ring (starts at 7)
- View daily summary
- Check app usage cards
- **Try this**: Tap the ⚠️ icon in top-right to simulate credit loss!

**2. Goals Tab**
- Toggle apps on/off
- Adjust time limits
- See changes reflected immediately

**3. Credits Tab**
- View current balance
- See next payment amount
- Tap "Add Credits Early" to see the top-up sheet
- Select a credit package
- Tap "Purchase" to add credits (simulated)

**4. Settings Tab**
- Toggle notifications
- Enable/disable haptics
- Try dark mode (coming soon)
- Tap FAQ to see expandable items
- Explore Support screen

## 🎨 Design Features to Notice

### Animations
- **Credit Ring**: Smooth fill animation with color change
- **Screen Transitions**: Slide effect between onboarding screens
- **Button Presses**: Subtle scale effect (0.98x)
- **Alerts**: Scale + fade with blur background
- **Progress Bars**: Animated fill with gradient

### Haptics
- Feel subtle vibrations on every tap (on device)
- Different patterns for success/warning/error
- Heavy haptic when losing a credit

### Color System
Watch the credit ring change color:
- **7 credits** = Deep indigo (perfect!)
- **5 credits** = Amber (warning)
- **2 credits** = Rose (urgent)

### Micro-interactions
- App cards show status icons (✓, ⚠️, ✗)
- Progress bars change color based on usage
- Cards have soft shadows that feel premium
- Numbers animate smoothly when changing

## 🧪 Testing the Demo

### Simulate Credit Loss
1. Go to Dashboard tab
2. Tap the ⚠️ warning icon (top-right)
3. Watch the alert appear with blur
4. See the credit ring update from 7 → 6
5. Feel the heavy haptic feedback

### Test Credit Top-Up
1. Go to Credits tab
2. Tap "Add Credits Early"
3. Select the 7-credit package (Best Value)
4. Tap "Purchase 7 Credits for $6.99"
5. Credits are added instantly!

### Try Goal Adjustment
1. Go to Goals tab
2. Toggle off Instagram
3. Card becomes slightly transparent
4. Toggle back on
5. Adjust time limit to 2 hours
6. Changes save automatically

## 📱 Navigation Flow

```
Launch App
    ↓
Is Onboarded?
    NO → Onboarding Flow (5 screens)
    YES → Main Tab View
            ↓
    ┌───────┴───────┬───────────┬──────────┐
    │               │           │          │
Dashboard        Goals       Credits   Settings
    │               │           │          │
    ├─ Credit Ring  ├─ Toggle   ├─ Balance ├─ Notifications
    ├─ Daily Card   ├─ Limits   ├─ Payment ├─ Appearance
    ├─ App Cards    └─ Save     ├─ Top-Up  ├─ Account
    └─ History                  └─ Info    └─ Support
        ↓                           ↓          ↓
   Credit History              Top-Up       FAQ
    (Modal)                     Sheet     Contact
```

## 🎯 Key Screens Explained

### Dashboard
**What**: Home screen with all important info
**See**: 
- Large credit ring at top
- Today's usage summary
- Individual app cards
- Week progress link

**Try**: Tap any app card to see detailed stats

### Goals
**What**: Configure which apps to monitor
**See**:
- List of available apps
- Toggle switches
- Time limit pickers

**Try**: Disable an app, then re-enable it

### Credits
**What**: Subscription and billing management
**See**:
- Big credit balance (X / 7)
- Next payment calculation
- Credit package options

**Try**: Open the top-up sheet and select packages

### Settings
**What**: App configuration and support
**See**:
- Notification toggles
- Haptic settings
- FAQ section
- Contact form

**Try**: Expand FAQ items to read Q&As

## 💡 Pro Tips

### For Designers
- Check the `DesignSystem/` folder for all colors and typography
- All spacing uses consistent values (12, 16, 20, 24, 32)
- Corner radius is 20px (medium) or 28px (large)
- Shadows have 0.08 opacity

### For Developers
- Start in `SevenApp.swift` (entry point)
- Global state is in `Models/AppState.swift`
- Reusable components in `Components/`
- All views use `.cardStyle()` modifier for consistency

### For Product Managers
- The 7-credit system is fully functional (mock data)
- Onboarding explains the psychology clearly
- Billing is transparent (shows exact amounts)
- Users can test the flow without real purchases

## 🐛 Common Issues

### App Won't Build?
- Make sure you're using Xcode 15.0+
- Select an iOS 16.0+ simulator
- Clean build folder: `⌘⇧K`

### Animations Look Choppy?
- Use a newer simulator (iPhone 14 Pro)
- Or test on a physical device
- Debug builds can be slower

### Haptics Not Working?
- Haptics only work on physical devices
- Simulator won't vibrate
- Check Settings → Sounds & Haptics on device

## 📊 Mock Data Explained

The app currently uses fake data so you can test everything:

- **Credits**: Starts at 7
- **Apps**: Instagram (64/120 min), TikTok (45/60 min), Snapchat (30/90 min)
- **History**: 7 days with 2 credits lost
- **Subscription**: Active, $7/week

Everything works, it's just not reading real Screen Time data yet!

## 🎓 Understanding the Code

### Quick Code Tour

```
SevenApp.swift
  ↓ creates AppState
  ↓ passes to ContentView
  
ContentView.swift
  ↓ checks hasCompletedOnboarding
  ↓ shows Onboarding OR MainTabView
  
MainTabView.swift
  ↓ 4 tabs with NavigationViews
  ↓ each tab is self-contained
  
AppState.swift (the brain)
  ↓ stores current credits
  ↓ stores monitored apps
  ↓ stores daily history
  ↓ methods to update state
```

### Key Files

- `Models/AppState.swift` - Global state (7 credits, apps, history)
- `Models/Models.swift` - Data structures
- `DesignSystem/Colors.swift` - All colors + hex support
- `DesignSystem/Styling.swift` - Buttons, cards, haptics
- `Components/CreditRingView.swift` - The animated ring

## 🎨 Customization Ideas

Want to tweak the design? Try these:

### Change Primary Color
Edit `DesignSystem/Colors.swift`:
```swift
static let sevenIndigo = Color(hex: "#YOUR_COLOR")
```

### Adjust Animation Speed
Edit `DesignSystem/Styling.swift`:
```swift
static let springResponse: Double = 0.5 // slower
static let springResponse: Double = 0.2 // faster
```

### Add More Apps
Edit `Views/Onboarding/SetGoalsView.swift`:
```swift
let availableApps = [
    ("Your App", "icon.name", Color.blue),
    // ... add more
]
```

## ✅ What's Included

- ✅ All 15+ screens designed and coded
- ✅ Smooth animations throughout
- ✅ Haptic feedback on interactions
- ✅ Mock data for testing
- ✅ Reusable component library
- ✅ Comprehensive documentation
- ✅ Production-ready architecture

## ❌ What's NOT Included (Yet)

These require additional setup:

- ❌ Real Screen Time API integration
- ❌ Actual in-app purchases (StoreKit)
- ❌ Push notifications
- ❌ Data persistence (Core Data)
- ❌ Cloud sync (CloudKit)
- ❌ Backend server

But the UI is 100% ready for these features!

## 🎯 Next Steps

### For Prototyping
You're done! The app is fully testable.

### For Production
1. Set up Apple Developer account
2. Request Screen Time API entitlement
3. Configure StoreKit products
4. Implement data persistence
5. Add push notifications
6. Submit to App Store

See `IMPLEMENTATION_NOTES.md` for technical details.

## 💬 Need Help?

Check these files:
- `README.md` - Full feature overview
- `IMPLEMENTATION_NOTES.md` - Technical deep dive
- `PROJECT_SUMMARY.md` - What's included

## 🎉 Have Fun!

This is a fully-functional prototype. Every screen works, every animation is smooth, every interaction has feedback. Enjoy exploring the Seven app! 

**Remember**: Tap that ⚠️ icon on the Dashboard to see the credit loss animation in action!

---

**Built with ❤️ using SwiftUI**

*Time to build the app that helps people build better habits!* 🚀

