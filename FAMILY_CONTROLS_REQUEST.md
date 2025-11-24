# Requesting Family Controls Entitlement

## App Bundle Identifier
`com.se7en.app.screentime`

## Quick Steps

1. Go to: https://developer.apple.com/account/resources/identifiers/list
2. Find or create identifier: `com.se7en.app.screentime`
3. Enable "Family Controls" capability
4. Submit justification (see below)

## Justification Text (Copy & Paste)

```
Our app (Se7en) helps users manage their screen time and app usage habits through Apple's Screen Time API. The app allows users to set daily limits for specific apps, monitor their usage, and provides accountability features through a credit system and pet companion. 

We need the Family Controls entitlement to:
- Monitor app usage using DeviceActivity framework
- Block apps when daily limits are exceeded
- Provide real-time usage data to help users stay accountable
- Integrate with Screen Time API for accurate usage tracking

This app is designed for personal use to help individuals develop healthier digital habits.
```

## Notes

- Approval typically takes 2-7 business days
- You must have an active Apple Developer Program membership ($99/year)
- Once approved, the capability will appear in Xcode's capability list
- The app can still be tested without this entitlement, but Screen Time features will be limited

## Direct Link
https://developer.apple.com/account/resources/identifiers/list

