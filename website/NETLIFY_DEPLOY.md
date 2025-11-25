# 🚀 How to Deploy SE7EN Website to Netlify

## Method 1: Drag & Drop (Easiest - 2 minutes)

### Step 1: Prepare Your Files
1. Make sure you're in the `website` folder
2. All your files should be ready:
   - `index.html`
   - `styles.css`
   - `privacy.html`, `terms.html`, `faq.html`
   - `assets/` folder with all images
   - `netlify.toml` (optional but helpful)

### Step 2: Deploy to Netlify
1. Go to [netlify.com](https://netlify.com)
2. Sign up or log in (free account works perfectly)
3. On the dashboard, look for **"Sites"** tab
4. Find the area that says **"Want to deploy a new site without connecting to Git? Drag and drop your site output folder here"**
5. **Drag your entire `website` folder** onto that area
6. Netlify will automatically:
   - Upload your files
   - Deploy your site
   - Give you a random URL like `random-name-123.netlify.app`

### Step 3: Get Your Site URL
- Your site is now live! 
- Click on your site name to see the URL
- You can share this URL immediately

### Step 4: Set Custom Domain (Optional)
1. Go to **Site Settings** → **Domain Management**
2. Click **"Add custom domain"**
3. Enter your domain (e.g., `se7enapp.com`)
4. Follow Netlify's DNS instructions

---

## Method 2: GitHub Integration (Best for Updates)

### Step 1: Push to GitHub
1. Create a new repository on GitHub (e.g., `se7en-website`)
2. In your terminal, navigate to your website folder:
   ```bash
   cd "/Users/anthonymaxson/Downloads/SE7EN App/website"
   ```
3. Initialize git (if not already):
   ```bash
   git init
   git add .
   git commit -m "Initial commit - SE7EN website"
   ```
4. Connect to GitHub:
   ```bash
   git remote add origin https://github.com/YOUR_USERNAME/se7en-website.git
   git push -u origin main
   ```

### Step 2: Connect to Netlify
1. Go to [netlify.com](https://netlify.com) and log in
2. Click **"Add new site"** → **"Import an existing project"**
3. Choose **"GitHub"** and authorize Netlify
4. Select your `se7en-website` repository
5. Configure build settings:
   - **Base directory:** `website` (if repo is at root) or leave blank if website folder is the repo
   - **Build command:** (leave empty - it's a static site)
   - **Publish directory:** `.` or `/` (root of website folder)
6. Click **"Deploy site"**

### Step 3: Automatic Deployments
- Every time you push to GitHub, Netlify will automatically redeploy
- You'll get a notification when deployment is complete

---

## ⚙️ Configure Environment Variables (For Backend API)

If you have a Railway backend API:

1. Go to your Netlify site dashboard
2. Click **"Site Settings"** → **"Environment Variables"**
3. Click **"Add variable"**
4. Add:
   - **Key:** `API_URL`
   - **Value:** `https://your-railway-api.up.railway.app` (your actual Railway URL)
5. Click **"Save"**
6. **Redeploy** your site (go to Deploys tab → Trigger deploy → Clear cache and deploy site)

---

## 📝 Quick Checklist

- [ ] Website folder is ready with all files
- [ ] Chose deployment method (drag & drop or GitHub)
- [ ] Site is deployed and live
- [ ] Tested the website on the Netlify URL
- [ ] (Optional) Set custom domain
- [ ] (If using backend) Added API_URL environment variable
- [ ] Tested waitlist form (if backend is connected)

---

## 🎯 What Happens After Deployment

1. **Your site gets a URL** like: `https://amazing-site-123.netlify.app`
2. **HTTPS is automatic** - Netlify provides free SSL certificates
3. **Global CDN** - Your site is fast worldwide
4. **Automatic deployments** - If using GitHub, every push = new deployment

---

## 🔧 Common Issues & Solutions

### Issue: Site not loading
- **Solution:** Check that `index.html` is in the root of your website folder
- Check Netlify deploy logs for errors

### Issue: Images not showing
- **Solution:** Make sure `assets/` folder is included in deployment
- Check image paths in HTML (should be `assets/image.png`)

### Issue: API not connecting
- **Solution:** 
  1. Verify `API_URL` environment variable is set
  2. Redeploy after adding environment variable
  3. Check browser console for errors
  4. Verify Railway backend is running

### Issue: Styles not loading
- **Solution:** Check that `styles.css` is in the same folder as `index.html`
- Verify the `<link>` tag in HTML is correct: `<link rel="stylesheet" href="styles.css">`

---

## 🚀 Next Steps After Deployment

1. **Test everything:**
   - Visit all pages (index, privacy, terms, FAQ)
   - Test waitlist form
   - Check mobile responsiveness
   - Test all links

2. **Set up custom domain** (optional but recommended)

3. **Monitor analytics:**
   - Netlify provides basic analytics
   - Or connect Google Analytics

4. **Set up form notifications:**
   - If using Netlify Forms, configure email notifications
   - Or connect to your Railway backend

---

## 💡 Pro Tips

- **Use GitHub integration** for automatic deployments
- **Enable Netlify Forms** if you want built-in form handling (alternative to Railway)
- **Use Netlify's split testing** to A/B test different versions
- **Set up branch previews** to test changes before going live
- **Use Netlify's redirects** for clean URLs (already configured in `netlify.toml`)

---

## 📞 Need Help?

- Netlify Docs: https://docs.netlify.com
- Netlify Community: https://answers.netlify.com
- Check deployment logs in Netlify dashboard for specific errors

