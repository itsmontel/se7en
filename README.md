# VirtuPet: Screen Time Control

VirtuPet is a gamified screen time management app that helps users reduce phone addiction by taking care of a virtual pet. The healthier your screen time habits, the happier your pet!

## 🎯 Concept

Users commit to daily goals (e.g., "Use Instagram for no more than 2 hours"). If they stick to the goal, they keep a credit. If they break it, they lose a credit. Each week, users must maintain their 7-credit balance to continue using the app.

## ✨ Key Features

### 1. **7-Credit System**
- Weekly subscription grants 7 credits
- Daily accountability: keep or lose credits based on app usage
- End-of-week reset requires returning to 7 credits
- Pay only for lost credits ($0.99 per credit)

### 2. **App Usage Monitoring**
- Track daily usage of selected apps
- Real-time progress updates
- Visual indicators for status (on track/warning/over limit)

### 3. **Daily Goal Setting**
- Customizable time limits for each app
- Easy-to-use time picker interface
- Enable/disable monitoring per app

### 4. **Credit History**
- Weekly progress dashboard
- Daily breakdown of credit changes
- Statistics and insights

### 5. **Subscription Management**
- Transparent billing
- Credit top-up store
- Consumable in-app purchases

## 🎨 Design System

### Color Palette
- **Primary**: Deep Indigo (#4F46E5)
- **Secondary**: Sky Blue (#0EA5E9)
- **Success**: Emerald (#10B981)
- **Warning**: Amber (#F59E0B)
- **Error**: Rose (#F43F5E)
- **Neutral**: Charcoal (#111827), Silver (#F3F4F6)

### Typography
- **Display**: SF Pro Rounded
- **Body**: SF Pro Text
- **Numbers**: SF Mono

### Design Principles
- Ultra-minimalist aesthetic
- High contrast with clean white space
- Rounded corners (20-28px)
- Soft shadows
- Apple-like neumorphism accents
- Smooth spring animations (0.3s-0.45s)
- Haptic feedback on all interactions

## 📱 App Structure

### Screens

1. **Onboarding Flow**
   - Welcome screen
   - How it works
   - Why it works
   - Set first goal
   - Paywall/subscription

2. **Dashboard**
   - Credit ring (circular progress)
   - Daily summary card
   - App usage list
   - Week progress link

3. **Goals**
   - Monitored apps list
   - Time limit settings
   - Enable/disable toggle

4. **Credits**
   - Current balance display
   - Next payment info
   - Top-up store
   - Credit packages
   - Subscription details

5. **Settings**
   - Notifications
   - Appearance
   - Account management
   - Support & FAQ

### Components

- `CreditRingView` - Animated circular progress indicator
- `CreditLossAlert` - Modal alert for credit loss
- `AppUsageCard` - Individual app usage display
- `DailySummaryCard` - Today's overall progress
- `LoadingView` - Animated loading state
- `SuccessToast` - Success notifications
- `WarningToast` - Warning notifications

## 🛠 Technical Stack

- **Framework**: SwiftUI
- **Platform**: iOS 16.0+
- **Design Pattern**: MVVM with ObservableObject
- **State Management**: @StateObject, @EnvironmentObject
- **Animations**: Spring animations with custom timing
- **Haptics**: UIFeedbackGenerator

## 💰 Business Model

### Revenue Streams
1. Weekly subscription ($7/week base)
2. Consumable in-app purchases (credit top-ups)

### Pricing
- 1 credit: $0.99
- 4 credits: $3.99
- 7 credits: $6.99

### Why It Scales
- High retention through loss aversion psychology
- Predictable recurring revenue
- Frequent micro-transactions
- Highly engaging system
- App Store compliant (no gambling, no refunds)

## 🧠 Psychology

Seven relies on powerful behavioral principles:

- **Loss Aversion**: Users strongly avoid losing credits
- **Score Maintenance**: The number "7" becomes a psychological anchor
- **Gamification**: Credits feel like a streak or health bar
- **Weekly Reset**: Creates constant engagement
- **Investment**: Users stay committed to their progress

## 🚀 Getting Started

### Prerequisites
- Xcode 15.0 or later
- iOS 16.0 or later
- Apple Developer account (for Screen Time API access)

### Installation

1. Clone the repository
2. Open `VirtuPet.xcodeproj` in Xcode
3. Build and run on simulator or device

### Note on Screen Time API

This prototype uses mock data. In production, you'll need to:
1. Request Family Controls entitlement from Apple
2. Implement Screen Time API integration
3. Request user authorization for device activity monitoring

## 📋 Project Structure

```
VirtuPet App/
├── VirtuPetApp.swift           # App entry point
├── Models/
│   ├── AppState.swift          # Global app state
│   └── Models.swift            # Data models
├── Views/
│   ├── ContentView.swift       # Root view
│   ├── Onboarding/             # Onboarding flow
│   ├── Dashboard/              # Home dashboard
│   ├── Goals/                  # Goal management
│   ├── Credits/                # Credit history
│   ├── Subscription/           # Billing & top-ups
│   └── Settings/               # Settings & support
├── Components/                 # Reusable components
├── DesignSystem/              # Colors, typography, styling
└── Extensions/                # View extensions
```

## 🎯 User Journey

### Onboarding
1. Subscribe → Receive 7 credits
2. Select apps to control
3. Set daily limits
4. Start first 24-hour challenge

### Daily Cycle
1. Use apps within limits
2. Keep credit or lose credit
3. See real-time updates
4. Receive warnings when close to limit

### Weekly Cycle
1. End of week → Refill to 7 credits
2. Pay only for credits lost
3. Begin next 7-day challenge

## 📊 Metrics to Track

- Weekly retention rate
- Credits lost per user per week
- Average top-up purchases
- Daily active users
- Goal completion rate
- Subscription churn rate

## 🔒 Privacy & Compliance

- No user data shared with third parties
- Screen time data stored locally
- Transparent billing and pricing
- No refunds policy clearly stated
- Complies with App Store Review Guidelines

## 📄 License

This is a prototype/concept app. All rights reserved.

## 👥 Support

For questions or support:
- Email: support@virtupet.app
- FAQ: Available in-app
- Terms: https://virtupet.app/terms
- Privacy: https://virtupet.app/privacy

---

**Built with SwiftUI** • **Designed for iOS** • **Powered by Accountability**

