# Logo Size Guide for VirtuPet App

This document outlines all the logo sizes you need to create for your VirtuPet app.

## 📱 1. App Icon (Required)

**Location**: `Assets.xcassets/AppIcon.appiconset/`

These are the icons displayed on the home screen. You need them in **PNG format with no transparency** (solid background).

### iPhone App Icon Sizes:
- **20x20 pt @2x** → `icon-20@2x.png` = **40x40 pixels**
- **20x20 pt @3x** → `icon-20@3x.png` = **60x60 pixels**
- **29x29 pt @2x** → `icon-29@2x.png` = **58x58 pixels**
- **29x29 pt @3x** → `icon-29@3x.png` = **87x87 pixels**
- **40x40 pt @2x** → `icon-40@2x.png` = **80x80 pixels**
- **40x40 pt @3x** → `icon-40@3x.png` = **120x120 pixels**
- **60x60 pt @2x** → `icon-60@2x.png` = **120x120 pixels**
- **60x60 pt @3x** → `icon-60@3x.png` = **180x180 pixels**

### App Store Marketing Icon:
- **1024x1024 pt @1x** → `icon-1024.png` = **1024x1024 pixels** ⭐ (MOST IMPORTANT)

**Design Tips:**
- No transparency - must have solid background
- No rounded corners (iOS adds them automatically)
- Keep important content within the safe area (avoid edges)
- Make it simple and recognizable at small sizes

---

## 🚀 2. Launch Screen Logo (Optional but Recommended)

**Location**: `Assets.xcassets/LaunchIcon.imageset/` (create if needed)

The logo shown when the app is launching. Can be the same as your app icon or a variation.

**Recommended Sizes:**
- **@1x**: **200x200 pixels** (base size)
- **@2x**: **400x400 pixels** (Retina displays)
- **@3x**: **600x600 pixels** (Plus/Pro Max displays)

**Design Tips:**
- Can have transparency
- Usually centered on launch screen
- Should look good against your app's background color

---

## 🎨 3. In-App Logo Asset (For UI Use)

**Location**: `Assets.xcassets/virtupetlogo.imageset/` ✅ (Already created)

For using the logo anywhere in your app UI (headers, settings, etc.).

**Recommended Sizes:**
- **@1x**: **256x256 pixels** (base size)
- **@2x**: **512x512 pixels** (Retina)
- **@3x**: **768x768 pixels** (Plus/Pro Max)

**Design Tips:**
- Can have transparency
- SVG or high-res PNG works best
- Should work on both light and dark backgrounds

---

## 📸 4. App Store Connect Assets (For App Store Listing)

These are used for your App Store page and marketing materials.

### App Preview Screenshots:
- **iPhone 6.7" (14 Pro Max, 15 Pro Max)**: 1290 x 2796 pixels
- **iPhone 6.5" (11 Pro Max, XS Max)**: 1242 x 2688 pixels
- **iPhone 5.5" (8 Plus)**: 1242 x 2208 pixels

### App Store Icon:
- **512x512 pixels** (for older iOS versions)
- **1024x1024 pixels** (same as App Icon)

### App Store Feature Image (Optional):
- **2048 x 2048 pixels** (for featured apps)

---

## 📊 Quick Reference Table

| Purpose | Pixel Size | Format | Transparency? |
|---------|-----------|--------|---------------|
| **App Icon (Home Screen)** | 1024x1024 | PNG | ❌ No |
| **App Icon (Small sizes)** | 40x40 to 180x180 | PNG | ❌ No |
| **Launch Screen Logo** | 200-600px | PNG/SVG | ✅ Yes |
| **In-App Logo** | 256-768px | PNG/SVG | ✅ Yes |
| **App Store Screenshots** | Various | PNG/JPG | N/A |

---

## 🎯 Priority Order

1. **1024x1024 App Icon** ⭐ (MOST CRITICAL - Required for App Store)
2. **App Icon Small Sizes** (40x40 to 180x180) - For home screen
3. **In-App Logo** (256-768px) - For UI use
4. **Launch Screen Logo** - Nice to have
5. **App Store Assets** - For marketing

---

## 💡 Tools to Generate Sizes

### Online Tools:
- **App Icon Generator**: https://www.appicon.co/
- **IconKitchen**: https://icon.kitchen/
- **MakeAppIcon**: https://makeappicon.com/

### Manual Method:
1. Create your logo at **1024x1024 pixels** first
2. Scale down to other sizes maintaining aspect ratio
3. Export each size as PNG with appropriate naming

---

## ✅ Current Status

- ✅ **App Icon**: All sizes set up (using same VirtuPetLogo.png for now)
- ✅ **In-App Logo**: `virtupetlogo.imageset` created
- ⚠️ **Launch Icon**: Referenced in Info.plist but not created yet

---

## 🚨 Important Notes

1. **App Icons MUST be PNG** - No transparency, no rounded corners
2. **1024x1024 is REQUIRED** for App Store submission
3. **Test on device** - Icons can look different on actual devices vs simulator
4. **Keep it simple** - Icons are tiny on home screen, details get lost
5. **Safe area** - Keep important elements away from edges (iOS may crop)

---

## 📝 Next Steps

1. Design your logo at **1024x1024 pixels**
2. Create properly sized versions for all app icon sizes
3. Replace the placeholder files in `AppIcon.appiconset/`
4. Test on a physical device
5. Create launch screen logo if desired
6. Prepare App Store screenshots with your logo


