# Assets Required for SE7EN Website

## 📥 Download These Assets

### 1. App Store Badge (Required)
- **File name**: `app-store-badge.svg`
- **Download from**: https://developer.apple.com/app-store/marketing/guidelines/
- **Select**: "Download on the App Store" badge
- **Format**: SVG (preferred) or PNG
- **Language**: English (or your target market)

### 2. App Screenshot (Required)
- **File name**: `app-screenshot.png`
- **Recommended size**: 1170x2532px (iPhone 14 Pro size)
- **Content**: SE7EN app dashboard showing:
  - Credit ring with number
  - App usage list
  - Clean, attractive UI
- **Format**: PNG with transparent or matching background
- **Tip**: Use an iPhone mockup frame for professional look

### 3. SE7EN Logo (Optional)
- **File name**: `se7en-logo.png`
- **Recommended size**: 512x512px or larger
- **Format**: PNG with transparency
- **Usage**: Can replace text logo in navbar

### 4. Favicon (Recommended)
- **File name**: `favicon.ico`
- **Size**: 32x32px or 16x16px
- **Format**: ICO format
- **Add to HTML**: `<link rel="icon" href="assets/favicon.ico">`

### 5. Open Graph Image (Recommended for Social Sharing)
- **File name**: `og-image.png`
- **Size**: 1200x630px
- **Content**: SE7EN branding + tagline
- **Format**: PNG or JPG
- **Usage**: Social media previews (Facebook, Twitter, LinkedIn)

## 🎨 Design Guidelines

### Colors to Use
- Primary: #4F46E5 (Indigo)
- Secondary: #0EA5E9 (Sky Blue)
- Success: #10B981 (Emerald)
- Warning: #F59E0B (Amber)
- Error: #F43F5E (Rose)

### Typography
- Font: SF Pro (or system font)
- Style: Clean, modern, minimal

## 📱 Where to Get Screenshots

### Option 1: iPhone Simulator
1. Run SE7EN app in Xcode simulator
2. Navigate to best screens (dashboard, credit ring)
3. Cmd + S to save screenshot
4. Use mockup tool to add device frame

### Option 2: Actual Device
1. Install SE7EN on iPhone
2. Take screenshots (Power + Volume Up)
3. AirDrop to Mac
4. Add mockup frame if desired

### Mockup Tools (Free)
- https://mockuphone.com/
- https://smartmockups.com/
- https://shotsnapp.com/
- Facebook Design's Devices: https://facebook.design/devices

## 🔗 Quick Setup Checklist

Once you have the assets:

- [ ] Download App Store badge → save as `app-store-badge.svg`
- [ ] Create app screenshot → save as `app-screenshot.png`
- [ ] (Optional) Create logo → save as `se7en-logo.png`
- [ ] (Optional) Create favicon → save as `favicon.ico`
- [ ] (Optional) Create OG image → save as `og-image.png`
- [ ] Place all files in this `assets/` folder
- [ ] Update App Store links in HTML when app is live
- [ ] Test website to ensure images load correctly

## 📏 Image Optimization Tips

- **Compress images** using TinyPNG or ImageOptim
- **Use SVG** for logos and badges (scalable, smaller file size)
- **WebP format** for better compression (with PNG fallback)
- **Lazy loading** for images below fold (add `loading="lazy"` to `<img>` tags)

## 🚀 Ready to Launch

After adding these assets, your SE7EN website will be complete and ready to deploy!

