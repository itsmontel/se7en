# StoreKit Setup Guide for SE7EN

This guide will walk you through setting up StoreKit 2 for in-app purchases in your SE7EN app.

## Overview

Your app uses **consumable in-app purchases** for credits. Users can purchase 1-7 credits at a time. No subscriptions needed - the app is free!

## Product IDs

You need to create these 8 products in App Store Connect:

### Subscription (Required)
- `se7en_biweekly_subscription` - Bi-weekly subscription ($6.99/£6.99 every 14 days with 7-day free trial)

### Credit Purchases (Consumable)
- `se7en_one_credit` - 1 credit
- `se7en_two_credits` - 2 credits
- `se7en_three_credits` - 3 credits
- `se7en_four_credits` - 4 credits
- `se7en_five_credits` - 5 credits
- `se7en_six_credits` - 6 credits
- `se7en_seven_credits` - 7 credits

## Step 1: Create Products in App Store Connect

### 1.1 Log into App Store Connect

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Sign in with your Apple Developer account
3. Select your app (or create it if you haven't yet)

### 1.2 Navigate to In-App Purchases

1. Click on your app
2. Go to **Features** tab
3. Click **In-App Purchases**
4. Click the **+** button to create a new in-app purchase

### 1.3 Create Subscription Product

First, create the subscription:

#### Product Type
- Select **Auto-Renewable Subscription**

#### Subscription Information
- **Reference Name**: `SE7EN Bi-Weekly Subscription`
- **Product ID**: `se7en_biweekly_subscription` (exact match required)
- **Subscription Group**: Create a new group or use existing
- **Subscription Duration**: 14 days (2 weeks)
- **Cleared for Sale**: ✅ Yes

#### Pricing
- **Price Schedule**: Set base price
  - **USD**: $6.99
  - **GBP**: £6.99
  - Apple will auto-convert to other currencies

#### Free Trial (Introductory Offer)
- **Offer Type**: Free Trial
- **Duration**: 7 days
- **Payment Mode**: Free
- **Eligibility**: All Users

#### Localization
- **Display Name**: `SE7EN Subscription`
- **Description**: `Unlimited access to SE7EN. 7-day free trial, then $6.99 every 14 days. Cancel anytime.`

### 1.4 Create Credit Products

For each credit product (1-7 credits), follow these steps:

#### Product Type
- Select **Consumable** (not Non-Consumable or Subscription)

#### Product Information
- **Reference Name**: `1 Credit` (or `2 Credits`, `3 Credits`, etc.)
- **Product ID**: `se7en_one_credit` (use the exact IDs listed above)
- **Cleared for Sale**: ✅ Yes

#### Pricing
- **Price Schedule**: Set the price
  - **1 Credit**: $0.99 USD / £0.99 GBP
  - **2 Credits**: $1.99 USD / £1.99 GBP
  - **3 Credits**: $2.99 USD / £2.99 GBP
  - **4 Credits**: $3.99 USD / £3.99 GBP
  - **5 Credits**: $4.99 USD / £4.99 GBP
  - **6 Credits**: $5.99 USD / £5.99 GBP
  - **7 Credits**: $6.99 USD / £6.99 GBP

#### Localization
- **Display Name**: `1 Credit` (or `2 Credits`, etc.)
- **Description**: `Purchase 1 credit to restore your balance` (or appropriate description)

**Important**: Apple will automatically convert prices to other currencies based on exchange rates.

### 1.4 Submit for Review (Optional)

You can submit products for review now, or wait until you're ready to submit the app. Products need to be approved before they work in production.

---

## Step 2: Create StoreKit Configuration File (For Testing)

This allows you to test purchases without App Store Connect approval.

### 2.1 Create Configuration File in Xcode

1. In Xcode, go to **File** → **New** → **File...**
2. Select **StoreKit Configuration File**
3. Name it `Products.storekit` (or any name you prefer)
4. Click **Create**

### 2.2 Add Products to Configuration File

1. In the StoreKit Configuration file, click the **+** button
2. For each product, add:

#### Subscription Product
- **Product ID**: `se7en_biweekly_subscription`
- **Type**: Auto-Renewable Subscription
- **Duration**: 14 days
- **Price**: $6.99 / £6.99
- **Free Trial**: 7 days
- **Display Name**: `SE7EN Subscription`
- **Description**: `Unlimited access to SE7EN. 7-day free trial, then $6.99 every 14 days.`

#### Product 1: One Credit
- **Product ID**: `se7en_one_credit`
- **Type**: Consumable
- **Price**: $0.99 / £0.99
- **Display Name**: `1 Credit`
- **Description**: `Purchase 1 credit to restore your balance`

#### Product 2: Two Credits
- **Product ID**: `se7en_two_credits`
- **Type**: Consumable
- **Price**: $1.99 / £1.99
- **Display Name**: `2 Credits`
- **Description**: `Purchase 2 credits to restore your balance`

#### Product 3: Three Credits
- **Product ID**: `se7en_three_credits`
- **Type**: Consumable
- **Price**: $2.99 / £2.99
- **Display Name**: `3 Credits`
- **Description**: `Purchase 3 credits to restore your balance`

#### Product 4: Four Credits
- **Product ID**: `se7en_four_credits`
- **Type**: Consumable
- **Price**: $3.99 / £3.99
- **Display Name**: `4 Credits`
- **Description**: `Purchase 4 credits to restore your balance`

#### Product 5: Five Credits
- **Product ID**: `se7en_five_credits`
- **Type**: Consumable
- **Price**: $4.99 / £4.99
- **Display Name**: `5 Credits`
- **Description**: `Purchase 5 credits to restore your balance`

#### Product 6: Six Credits
- **Product ID**: `se7en_six_credits`
- **Type**: Consumable
- **Price**: $5.99 / £5.99
- **Display Name**: `6 Credits`
- **Description**: `Purchase 6 credits to restore your balance`

#### Product 7: Seven Credits
- **Product ID**: `se7en_seven_credits`
- **Type**: Consumable
- **Price**: $6.99 / £6.99
- **Display Name**: `7 Credits`
- **Description**: `Purchase 7 credits to restore your balance`

### 2.3 Enable StoreKit Testing in Xcode Scheme

1. In Xcode, click on your **Scheme** (next to the play/stop buttons)
2. Select **Edit Scheme...**
3. Go to **Run** → **Options** tab
4. Under **StoreKit Configuration**, select your `Products.storekit` file
5. Click **Close**

---

## Step 3: Test Purchases

### 3.1 Test in Simulator/Device

1. Build and run your app
2. Navigate to the **Credits** page
3. Tap **Add Credits**
4. Select a credit package
5. Tap **Purchase**

### 3.2 StoreKit Testing Features

When using StoreKit Configuration:
- Purchases are instant (no real payment)
- No sandbox account needed
- Test all purchase flows
- Test restore purchases
- Test purchase failures

### 3.3 Test Purchase Scenarios

Test these scenarios:
- ✅ Purchase 1 credit
- ✅ Purchase multiple credits
- ✅ Purchase when credits < 7
- ✅ Purchase when credits = 7 (should show "No Credits Needed")
- ✅ Restore purchases
- ✅ Cancel purchase
- ✅ Network failure during purchase

---

## Step 4: Test with Sandbox Account (Optional)

For more realistic testing before App Store submission:

### 4.1 Create Sandbox Tester

1. In App Store Connect, go to **Users and Access**
2. Click **Sandbox Testers** tab
3. Click **+** to add a tester
4. Enter email (doesn't need to be real, but must be unique)
5. Enter password and other details
6. Save

### 4.2 Test with Sandbox Account

1. On your test device, sign out of App Store
2. When prompted during purchase, sign in with sandbox tester account
3. Purchases will be free but simulate real transactions

---

## Step 5: Production Checklist

Before submitting to App Store:

- [ ] All 7 products created in App Store Connect
- [ ] Products submitted for review (or will be with app)
- [ ] Prices set correctly ($0.99, $1.99, etc.)
- [ ] Product IDs match exactly: `se7en_one_credit`, `se7en_two_credits`, etc.
- [ ] StoreKit Configuration file created for testing
- [ ] Tested all purchase flows
- [ ] Tested restore purchases
- [ ] Tested error handling
- [ ] Privacy policy mentions in-app purchases
- [ ] App description mentions credit purchases

---

## Troubleshooting

### Products Not Loading

**Problem**: `loadProducts()` returns empty array

**Solutions**:
- Check Product IDs match exactly (case-sensitive)
- Ensure products are created in App Store Connect
- For testing, make sure StoreKit Configuration is selected in scheme
- Check console logs for error messages

### Purchase Fails

**Problem**: Purchase button doesn't work or shows error

**Solutions**:
- Check you're signed in to App Store (or sandbox account)
- Verify Product IDs match
- Check network connection
- Review console logs for specific error

### Prices Show Wrong Currency

**Problem**: Prices show in wrong currency

**Solutions**:
- StoreKit automatically uses device's App Store region
- Change device region in Settings → App Store
- Prices will convert automatically based on App Store Connect pricing

### Products Not Approved

**Problem**: Products show "Pending" in App Store Connect

**Solutions**:
- Products need to be approved before working in production
- Use StoreKit Configuration file for testing during development
- Submit products for review along with your app

---

## Code Reference

Your StoreKit implementation is in:
- `Services/StoreKitService.swift` - Main StoreKit service
- `Views/Subscription/SubscriptionView.swift` - Credits page UI
- `Views/Subscription/TopUpSheet.swift` - Purchase sheet

Product IDs are defined in `StoreKitService.swift`:
```swift
private enum ProductIDs {
    static let oneCredit = "se7en_one_credit"
    static let twoCredits = "se7en_two_credits"
    // ... etc
}
```

---

## Additional Resources

- [Apple StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [In-App Purchase Best Practices](https://developer.apple.com/app-store/in-app-purchases/)

---

## Quick Start Checklist

1. ✅ Create 1 auto-renewable subscription in App Store Connect
   - Product ID: `se7en_biweekly_subscription`
   - Duration: 14 days
   - Price: $6.99 / £6.99
   - Free Trial: 7 days
2. ✅ Create 7 consumable products in App Store Connect
3. ✅ Set credit prices: $0.99, $1.99, $2.99, $3.99, $4.99, $5.99, $6.99
4. ✅ Create StoreKit Configuration file in Xcode
5. ✅ Add subscription + all 7 credit products to configuration file
6. ✅ Enable StoreKit Configuration in scheme
7. ✅ Test subscription purchase with free trial in app
8. ✅ Test credit purchases in app
9. ✅ Submit products for review (when ready)

---

**Your app is ready for StoreKit!** 🎉

