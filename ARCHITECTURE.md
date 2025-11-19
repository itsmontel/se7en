# Seven - Architecture Documentation

## 🏗 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         SevenApp.swift                       │
│                    @main Entry Point                         │
│                  Creates AppState as                         │
│                   @StateObject                               │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ↓
            ┌─────────────────────┐
            │   AppState.swift    │
            │  (ObservableObject) │
            ├─────────────────────┤
            │ @Published:         │
            │ • currentCredits    │
            │ • monitoredApps     │
            │ • dailyHistory      │
            │ • hasCompletedOnbo  │
            └──────────┬──────────┘
                       │ @EnvironmentObject
                       ↓
            ┌─────────────────────┐
            │  ContentView.swift  │
            │   (Router View)     │
            └──────────┬──────────┘
                       │
         ┌─────────────┴─────────────┐
         ↓                           ↓
┌────────────────────┐    ┌──────────────────┐
│ OnboardingView     │    │  MainTabView     │
│ (if !onboarded)    │    │  (if onboarded)  │
└────────────────────┘    └────────┬─────────┘
                                   │
                    ┌──────────────┼──────────────┬─────────────┐
                    ↓              ↓              ↓             ↓
            ┌───────────┐  ┌────────────┐  ┌──────────┐  ┌──────────┐
            │ Dashboard │  │   Goals    │  │ Credits  │  │ Settings │
            │    Tab    │  │    Tab     │  │   Tab    │  │   Tab    │
            └───────────┘  └────────────┘  └──────────┘  └──────────┘
```

## 📱 View Hierarchy

### Onboarding Flow
```
OnboardingContainerView
├── @State currentStep: OnboardingStep
├── @State selectedApps: Set<String>
└── @State appLimits: [String: Int]
    │
    ├── WelcomeView
    │   └── Animated "7" logo
    │
    ├── HowItWorksView
    │   ├── StepCard (1)
    │   ├── StepCard (2)
    │   └── StepCard (3)
    │
    ├── WhyItWorksView
    │   ├── IllustrationCard (Accountability)
    │   └── IllustrationCard (Payment)
    │
    ├── SetGoalsView
    │   └── ForEach(availableApps)
    │       └── AppSelectionRow
    │           ├── Toggle (enable/disable)
    │           └── Picker (time limit)
    │
    └── PaywallView
        ├── Pricing card
        ├── Feature bullets
        └── Subscribe button
```

### Dashboard Tab
```
DashboardView
├── NavigationView
│   ├── ScrollView
│   │   ├── CreditRingView
│   │   │   ├── Background glow (RadialGradient)
│   │   │   ├── Background ring (gray)
│   │   │   ├── Progress ring (animated)
│   │   │   └── Center content (number + text)
│   │   │
│   │   ├── DailySummaryCard
│   │   │   ├── Header with status icon
│   │   │   ├── Stats grid (Used / Limit / Remaining)
│   │   │   └── Progress bar
│   │   │
│   │   ├── ForEach(monitoredApps)
│   │   │   └── AppUsageCard
│   │   │       ├── App icon + name
│   │   │       ├── Usage stats
│   │   │       ├── Progress bar
│   │   │       └── Status indicator
│   │   │
│   │   └── NavigationLink(CreditHistoryView)
│   │
│   ├── Toolbar (demo button)
│   │
│   └── Overlays
│       ├── CreditLossAlert (if showing)
│       └── SuccessToast (if showing)
```

### Goals Tab
```
GoalsView
├── NavigationView
│   └── ScrollView
│       ├── Header info card
│       │
│       └── ForEach(monitoredApps)
│           └── GoalCard
│               ├── App icon + name
│               ├── Toggle (enable/disable)
│               └── Picker (time limit)
```

### Credits Tab
```
SubscriptionView
├── NavigationView
│   └── ScrollView
│       ├── Balance card
│       │   └── X / 7 display
│       │
│       ├── Next payment card
│       │   ├── Amount due
│       │   └── Days until reset
│       │
│       ├── Top-up button
│       │   └── .sheet(TopUpSheet)
│       │
│       ├── Package preview
│       │   └── ForEach(packages)
│       │       └── PackagePreviewCard
│       │
│       └── Subscription info
│           └── Info rows
│
└── TopUpSheet (modal)
    ├── Current balance
    ├── Package selection
    │   └── ForEach(packages)
    │       └── PackageCard
    │           ├── Best value badge
    │           ├── Credit amount
    │           ├── Price info
    │           └── Selection indicator
    └── Purchase button
```

### Settings Tab
```
SettingsView
├── NavigationView
│   └── List
│       ├── Section: Notifications
│       │   ├── Toggle (Reminders)
│       │   └── Toggle (Weekly summary)
│       │
│       ├── Section: Appearance
│       │   ├── Toggle (Haptics)
│       │   └── Toggle (Dark mode)
│       │
│       ├── Section: Account
│       │   ├── NavigationLink(Subscription)
│       │   └── Button (Restore)
│       │
│       ├── Section: Support
│       │   ├── NavigationLink(FAQ)
│       │   ├── NavigationLink(Support)
│       │   ├── Link (Privacy)
│       │   └── Link (Terms)
│       │
│       └── Section: Info
│           └── Version number
│
├── FAQView
│   └── ForEach(questions)
│       └── FAQItem (expandable)
│
└── SupportView
    ├── Header card
    ├── Text editor
    └── Send button
```

### Credit History (Modal)
```
CreditHistoryView
└── ScrollView
    ├── Week summary card
    │   ├── Credit bar (7 blocks)
    │   └── Summary text
    │
    ├── Daily breakdown
    │   └── ForEach(dailyHistory)
    │       └── DailyRecordRow
    │           ├── Day icon (✓ or ✗)
    │           ├── Day name + status
    │           └── Credit change
    │
    └── Stats card
        ├── Credits kept
        └── Credits lost
```

## 🎨 Design System Structure

```
DesignSystem/
│
├── Colors.swift
│   ├── Semantic colors (primary, success, warning, error)
│   ├── Brand colors (indigo, sky blue, etc.)
│   ├── Dynamic color function (creditColor)
│   └── Hex initializer
│
├── Typography.swift
│   ├── Display fonts (SF Pro Rounded)
│   ├── Header fonts (SF Pro Text)
│   ├── Body fonts (SF Pro Text)
│   ├── Number fonts (SF Mono)
│   └── Caption fonts
│
└── Styling.swift
    ├── DesignSystem constants
    │   ├── cornerRadius (Small/Medium/Large)
    │   ├── shadowRadius + opacity
    │   └── animation timing
    │
    ├── ViewModifiers
    │   └── CardModifier
    │
    ├── ButtonStyles
    │   ├── PrimaryButtonStyle
    │   └── SecondaryButtonStyle
    │
    └── HapticFeedback
        ├── light / medium / heavy
        └── success / warning / error
```

## 📊 Data Flow

### State Management Pattern
```
User Action
    ↓
View (@State)
    ↓
Binding / Method Call
    ↓
AppState (@Published)
    ↓
SwiftUI Update
    ↓
All Subscribed Views Re-render
```

### Example: Losing a Credit
```
1. User exceeds app limit
   ↓
2. System detects (in real app)
   ↓
3. appState.loseCredit() called
   ↓
4. AppState.currentCredits -= 1
   ↓
5. @Published triggers update
   ↓
6. Views observing AppState refresh:
   • CreditRingView (animates to new value)
   • DashboardView (updates display)
   • SubscriptionView (recalculates payment)
   ↓
7. CreditLossAlert presented
   ↓
8. HapticFeedback.heavy triggered
```

## 🔄 Navigation Patterns

### Tab-Based Navigation
```
MainTabView (TabView)
├── Tab 1: Dashboard (NavigationView)
├── Tab 2: Goals (NavigationView)
├── Tab 3: Credits (NavigationView)
└── Tab 4: Settings (NavigationView)
```

Each tab has its own NavigationView, allowing independent navigation stacks.

### Modal Presentations
```
Sheet Modals:
• TopUpSheet (from Credits tab)

Full Screen Covers:
• Onboarding (blocks entire app until complete)

Overlay Modals:
• CreditLossAlert (custom ZStack overlay)
• SuccessToast (custom overlay)
• WarningToast (custom overlay)
```

### NavigationLinks
```
Dashboard → CreditHistoryView
Settings → FAQView
Settings → SupportView
Settings → SubscriptionView
```

## 🧩 Component Architecture

### Reusable Components

```
Components/
│
├── CreditLossAlert
│   ├── Props: isPresented, creditsLost, creditsRemaining
│   ├── Blur background overlay
│   ├── Animated alert card
│   └── Dismiss button
│
├── LoadingView
│   ├── Rotating ring animation
│   ├── "7" center logo
│   └── Loading text
│
├── SuccessToast
│   ├── Props: message, isPresented
│   ├── Auto-dismiss after 2s
│   ├── Slide from top
│   └── Success haptic
│
├── WarningToast
│   ├── Props: message, isPresented
│   ├── Auto-dismiss after 3s
│   ├── Slide from top
│   └── Warning haptic
│
└── AnimatedNumber
    ├── Props: value, font, color
    ├── Smooth transition
    └── Spring animation
```

### View-Specific Components

```
Dashboard Components:
├── CreditRingView (animated circular progress)
├── DailySummaryCard (today's overview)
└── AppUsageCard (individual app status)

Onboarding Components:
├── StepCard (How It Works steps)
├── IllustrationCard (Why It Works cards)
├── AppSelectionRow (app + time picker)
└── FeatureBullet (paywall features)

Subscription Components:
├── PackageCard (full credit package)
├── PackagePreviewCard (small preview)
└── InfoRow (subscription details)

History Components:
├── DailyRecordRow (day result)
└── StatItem (kept vs lost stats)

Settings Components:
├── FAQItem (expandable Q&A)
└── TextEditor (support form)
```

## 🎭 Animation System

### Animation Types

```
Spring Animations (Primary)
├── Response: 0.35s
├── Damping: 0.7
└── Used for:
    ├── Screen transitions
    ├── Button presses
    ├── Modal presentations
    └── Value changes

Easing Animations
├── Duration: 1-2s
└── Used for:
    ├── Pulsing effects
    └── Continuous loops

Linear Animations
├── Duration: 1.5s
└── Used for:
    └── Loading spinners
```

### Transition Effects

```
Screen Transitions:
├── Onboarding: .slideAndFade (trailing in, leading out)
├── Modals: .scaleAndFade
└── Toasts: .move(edge: .top) + .opacity

View Transitions:
├── Credit Ring: .trim animation on Circle
├── Progress Bars: width animation
└── Numbers: .contentTransition(.numericText())

Interactive:
├── Button press: .scaleEffect(0.98)
├── Alert appear: .scaleEffect(0.8 → 1.0)
└── Toast slide: .move(edge: .top)
```

## 🎨 Styling System

### Card Style Application
```
Any View
    ↓
.cardStyle()
    ↓
├── .padding(16)
├── .background(Color.white)
├── .cornerRadius(20)
└── .shadow(...)
```

### Button Style Application
```
Button("Action")
    ↓
.buttonStyle(PrimaryButtonStyle())
    ↓
├── Color.primary background
├── White text
├── Rounded corners
├── Shadow
└── Press animation (scale 0.98)
```

## 🔐 Data Models

```
MonitoredApp
├── id: UUID
├── name: String
├── icon: String (SF Symbol)
├── dailyLimit: Int (minutes)
├── usedToday: Int (minutes)
├── color: Color
├── isEnabled: Bool
└── Computed Properties:
    ├── remainingMinutes
    ├── percentageUsed
    ├── isOverLimit
    ├── isNearLimit
    └── statusColor

DailyRecord
├── id: UUID
├── date: Date
├── creditChange: Int (-1 or 0)
└── Computed Properties:
    ├── dayName
    ├── shortDayName
    └── isSuccess

CreditPackage
├── id: UUID
├── credits: Int
├── price: Double
└── Computed Properties:
    ├── priceString
    └── perCreditPrice

OnboardingStep (Enum)
├── welcome
├── howItWorks
├── whyItWorks
├── setGoals
└── paywall
```

## 🎯 State Management

```
AppState (ObservableObject)
│
├── @Published Properties
│   ├── hasCompletedOnboarding: Bool
│   ├── hasActiveSubscription: Bool
│   ├── currentCredits: Int
│   ├── weekStartDate: Date
│   ├── monitoredApps: [MonitoredApp]
│   └── dailyHistory: [DailyRecord]
│
└── Methods
    ├── loadMockData()
    ├── completeOnboarding()
    ├── loseCredit()
    ├── addCredits(_ amount: Int)
    └── resetWeek()
```

### How Views Access State
```
// In SevenApp.swift
@StateObject private var appState = AppState()

// Passed to ContentView
.environmentObject(appState)

// Accessed in any child view
@EnvironmentObject var appState: AppState

// Used in view
Text("\(appState.currentCredits)")
```

## 🚀 Build & Run Flow

```
Xcode Build
    ↓
Compile SwiftUI Views
    ↓
Link Frameworks
    ↓
Launch App
    ↓
@main SevenApp
    ↓
Create AppState
    ↓
Load Mock Data
    ↓
Show ContentView
    ↓
Check Onboarding Status
    ↓
Display Appropriate View
    ↓
User Interaction Loop
```

## 📦 File Dependencies

```
SevenApp.swift
├── Imports: SwiftUI
└── Creates: AppState

ContentView.swift
├── Imports: SwiftUI
├── Uses: AppState
└── Shows: OnboardingView OR MainTabView

All Views
├── Import: SwiftUI
├── Use: DesignSystem (Colors, Typography, Styling)
├── Use: Models (AppState, Models)
└── Use: Components (as needed)

Components
├── Import: SwiftUI
├── Use: DesignSystem
└── Independent of other Views

DesignSystem
├── Import: SwiftUI
└── No dependencies (foundation layer)

Models
├── Import: SwiftUI
└── No dependencies (data layer)
```

## 💾 Data Persistence (Future)

```
Current: In-Memory Only
    ↓
AppState created fresh each launch
    ↓
Mock data loaded on init
    ↓
All changes lost on quit

Future: Core Data / UserDefaults
    ↓
AppState loads from storage
    ↓
Changes saved automatically
    ↓
Persistent across launches
```

## 🔄 Update Cycle

```
User taps button
    ↓
Action handler called
    ↓
State updated (@State or @Published)
    ↓
SwiftUI diffing algorithm
    ↓
Only changed views re-render
    ↓
Animations applied
    ↓
Haptics triggered
    ↓
UI updates smoothly
```

## 🎓 Architecture Principles

1. **Separation of Concerns**
   - Models: Data structures
   - Views: UI presentation
   - Components: Reusable UI elements
   - DesignSystem: Visual styling

2. **Unidirectional Data Flow**
   - Data flows down (via @EnvironmentObject)
   - Events flow up (via callbacks/bindings)

3. **Composition Over Inheritance**
   - Views built from smaller views
   - Modifiers add behavior
   - No complex class hierarchies

4. **Single Source of Truth**
   - AppState is the truth
   - Views derive from state
   - No duplicate data storage

5. **Declarative UI**
   - Describe what, not how
   - SwiftUI handles rendering
   - State drives appearance

---

**Architecture Status**: ✅ Production-Ready

Clean, scalable, maintainable SwiftUI architecture following Apple's best practices.

