# SE7EN Website Setup Guide

## 🚀 Quick Start

Your SE7EN website is ready! Follow these steps to launch it.

## 📋 Pre-Launch Checklist

### 1. Add Required Assets (5 minutes)

Navigate to the `assets/` folder and add:

- [ ] **App Store Badge** (`app-store-badge.svg`)
  - Download official badge from: https://developer.apple.com/app-store/marketing/guidelines/
  - Replace the placeholder SVG

- [ ] **App Screenshot** (`app-screenshot.png`)
  - Take a screenshot of your SE7EN app dashboard
  - Recommended size: 1170x2532px
  - Use an iPhone mockup tool for professional look

### 2. Update Contact Information (2 minutes)

Search and replace these placeholders in all HTML files:

- [ ] `support@se7enapp.com` → Your actual support email
- [ ] `privacy@se7enapp.com` → Your actual privacy contact email
- [ ] `legal@se7enapp.com` → Your actual legal contact email
- [ ] `[Your Address]` → Your actual business address (in `privacy.html` and `terms.html`)
- [ ] `[Your Jurisdiction]` → Your legal jurisdiction (in `terms.html`, e.g., "the State of California")

### 3. Add App Store Link (1 minute when available)

Once your app is live on the App Store:

1. Open `index.html`
2. Find: `<a href="#">`
3. Replace with: `<a href="https://apps.apple.com/app/idYOUR_APP_ID">`

Repeat for all App Store badge links in the HTML files.

## 🧪 Testing Locally

### Option 1: Python (Built-in on Mac)

```bash
cd "/Users/anthonymaxson/Downloads/SE7EN App/website"
python3 -m http.server 8000
```

Then open: http://localhost:8000

### Option 2: PHP (Built-in on Mac)

```bash
cd "/Users/anthonymaxson/Downloads/SE7EN App/website"
php -S localhost:8000
```

Then open: http://localhost:8000

### Option 3: VS Code Live Server

1. Install "Live Server" extension in VS Code
2. Right-click `index.html`
3. Select "Open with Live Server"

### Option 4: Simply Open in Browser

Double-click `index.html` (works but without server features)

## 🌐 Deployment Options

### Option 1: GitHub Pages (Free, Recommended for Static Sites)

**Perfect for**: Portfolio, documentation, static websites

1. Create a GitHub account (if you don't have one)
2. Create a new repository (e.g., "se7en-website")
3. Upload all website files
4. Go to repository Settings > Pages
5. Select "main" branch as source
6. Click Save

**Your site will be live at**: `https://yourusername.github.io/se7en-website/`

**Custom domain**: You can add a custom domain in GitHub Pages settings

### Option 2: Netlify (Free, Best for Easy Updates)

**Perfect for**: Automatic deployments, form handling, serverless functions

1. Sign up at https://netlify.com
2. Click "Add new site" > "Deploy manually"
3. Drag and drop your `website` folder
4. Done! Your site is live instantly

**Features**:
- Automatic HTTPS
- Custom domain support (free)
- Continuous deployment from GitHub
- Form handling (for contact forms)

### Option 3: Vercel (Free, Great Performance)

**Perfect for**: Fast global CDN, great performance

1. Sign up at https://vercel.com
2. Click "New Project"
3. Import from GitHub or upload folder
4. Deploy

**Features**:
- Lightning-fast CDN
- Automatic HTTPS
- Custom domains
- Analytics

### Option 4: Firebase Hosting (Free Tier Available)

**Perfect for**: If you plan to add Firebase features later

1. Install Firebase CLI: `npm install -g firebase-tools`
2. Login: `firebase login`
3. Initialize: `firebase init hosting`
4. Deploy: `firebase deploy`

### Option 5: Traditional Web Hosting

**Perfect for**: If you already have web hosting

Upload files via FTP/SFTP to your web server's public directory:
- Often: `public_html/` or `www/`
- Use FileZilla, Cyberduck, or your host's file manager

## 🎨 Customization Tips

### Change Colors

Edit `styles.css` and modify these CSS variables:

```css
:root {
    --indigo: #4F46E5;      /* Primary color */
    --sky-blue: #0EA5E9;    /* Secondary color */
    --emerald: #10B981;     /* Success */
    --amber: #F59E0B;       /* Warning */
    --rose: #F43F5E;        /* Error */
}
```

### Add Your Logo

1. Save logo as `assets/se7en-logo.png`
2. In `index.html`, replace:
```html
<div class="logo">SE7EN</div>
```
with:
```html
<img src="assets/se7en-logo.png" alt="SE7EN" class="logo">
```

### Add Favicon

1. Create `favicon.ico` (32x32px)
2. Add to `<head>` in all HTML files:
```html
<link rel="icon" href="assets/favicon.ico">
```

## 📈 SEO & Analytics

### Add Meta Tags

Add to `<head>` in `index.html`:

```html
<meta name="description" content="SE7EN - Take back control of your screen time with our credit-based accountability system">
<meta name="keywords" content="screen time, digital wellness, app usage tracker, productivity, se7en">
<meta name="author" content="SE7EN">

<!-- Open Graph (Facebook, LinkedIn) -->
<meta property="og:type" content="website">
<meta property="og:url" content="https://yoursite.com/">
<meta property="og:title" content="SE7EN - Take Back Control">
<meta property="og:description" content="Your screen is stealing your life. Let's take it back.">
<meta property="og:image" content="https://yoursite.com/assets/og-image.png">

<!-- Twitter -->
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:url" content="https://yoursite.com/">
<meta name="twitter:title" content="SE7EN - Take Back Control">
<meta name="twitter:description" content="Your screen is stealing your life. Let's take it back.">
<meta name="twitter:image" content="https://yoursite.com/assets/og-image.png">
```

### Add Google Analytics (Optional)

1. Create account at https://analytics.google.com
2. Get tracking ID (e.g., G-XXXXXXXXXX)
3. Add before `</head>` in all HTML files:

```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-XXXXXXXXXX');
</script>
```

### Submit to Google Search Console

1. Go to https://search.google.com/search-console
2. Add your website
3. Verify ownership
4. Submit sitemap (create `sitemap.xml`)

## 🔒 Security Headers (For Production)

If using Netlify, create `_headers` file:

```
/*
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: geolocation=(), microphone=(), camera=()
```

## ✅ Final Checklist

Before going live:

- [ ] All assets added (badges, screenshots)
- [ ] Contact emails updated
- [ ] Business address added
- [ ] Jurisdiction specified
- [ ] App Store links updated (when app is live)
- [ ] Tested on desktop browser
- [ ] Tested on mobile browser
- [ ] All links work
- [ ] FAQ toggles work
- [ ] Forms tested (if added)
- [ ] SEO meta tags added
- [ ] Analytics added (optional)
- [ ] Custom domain configured (if applicable)
- [ ] HTTPS enabled
- [ ] Privacy policy reviewed by legal
- [ ] Terms & conditions reviewed by legal

## 📱 Mobile Testing

Test on these devices/browsers:
- [ ] iPhone Safari
- [ ] iPhone Chrome
- [ ] Android Chrome
- [ ] iPad Safari
- [ ] Desktop Chrome
- [ ] Desktop Firefox
- [ ] Desktop Safari

## 🆘 Troubleshooting

### Images not loading?
- Check file paths are correct (case-sensitive on some servers)
- Ensure images are in `assets/` folder
- Check file extensions match HTML references

### CSS not applying?
- Clear browser cache (Cmd+Shift+R)
- Check `styles.css` is in same folder as HTML files
- Verify link tag in HTML: `<link rel="stylesheet" href="styles.css">`

### FAQ not expanding?
- Check JavaScript is enabled in browser
- Ensure `<script>` tag is present in `faq.html`
- Check browser console for errors

### Links not working?
- Update all `#` placeholders with actual URLs
- Ensure relative paths are correct
- Test all internal navigation

## 🎉 You're Ready to Launch!

Once you've completed the checklist, your SE7EN website is ready to go live!

## 📞 Need Help?

If you run into issues:
1. Check the `README.md` for additional information
2. Review the `assets/ASSETS_NEEDED.md` for asset specifications
3. Contact your web developer or hosting support

---

**Good luck with your SE7EN app launch! 🚀**

