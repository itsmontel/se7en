# VirtuPet Waitlist Backend Setup - Quick Start

## ✅ What's Been Created

1. **Backend API** (`backend/` folder)
   - Express.js server ready for Railway
   - PostgreSQL database integration
   - Waitlist API endpoints
   - Error handling and validation

2. **Frontend Integration** (`website/index.html`)
   - Updated waitlist form to call backend API
   - Success/error message display
   - Loading states
   - Proper error handling

3. **Deployment Files**
   - `backend/README.md` - Complete Railway deployment guide
   - `website/DEPLOYMENT.md` - Netlify + Railway setup guide
   - `website/netlify.toml` - Netlify configuration

## 🚀 Quick Deployment Steps

### Step 1: Deploy Backend to Railway (5 minutes)

1. Go to [railway.app](https://railway.app) and sign up/login
2. Click "New Project" → "Deploy from GitHub repo"
3. Select your repository and choose the `backend` folder
4. Railway will auto-detect Node.js and install dependencies
5. Click "New" → "Database" → "Add PostgreSQL"
6. Railway automatically sets `DATABASE_URL` environment variable
7. Copy your Railway API URL (found in Settings → Networking)

### Step 2: Deploy Frontend to Netlify (3 minutes)

1. Go to [netlify.com](https://netlify.com) and sign up/login
2. Click "Add new site" → "Import an existing project"
3. Connect your GitHub repo and select the `website` folder
4. In Site Settings → Environment Variables, add:
   - Key: `API_URL`
   - Value: `https://your-railway-api.up.railway.app` (from Step 1)
5. Deploy!

### Step 3: Update API URL in Code (1 minute)

If environment variables don't work, edit `website/index.html`:
- Find: `return 'https://your-railway-api.up.railway.app';`
- Replace with your actual Railway API URL

## 🧪 Testing

1. **Test Backend**: Visit `https://your-railway-api.up.railway.app/health`
   - Should return: `{"status":"ok","timestamp":"..."}`

2. **Test Waitlist Form**: 
   - Go to your Netlify site
   - Enter an email and submit
   - Should see success message

3. **Check Database**:
   - In Railway, go to PostgreSQL → Query
   - Run: `SELECT * FROM waitlist;`
   - Should see your test email

## 📁 File Structure

```
VirtuPet App/
├── backend/
│   ├── server.js          # Express API server
│   ├── package.json       # Dependencies
│   ├── .gitignore         # Git ignore rules
│   └── README.md          # Detailed backend docs
│
└── website/
    ├── index.html         # Updated with API integration
    ├── styles.css         # Added message styles
    ├── netlify.toml       # Netlify config
    ├── _redirects         # Netlify redirects
    └── DEPLOYMENT.md      # Deployment guide
```

## 🔧 API Endpoints

- `POST /api/waitlist` - Add email to waitlist
- `GET /api/waitlist/stats` - Get waitlist count
- `GET /health` - Health check

## 📝 Next Steps

1. Deploy backend to Railway
2. Deploy frontend to Netlify
3. Set API_URL environment variable
4. Test the waitlist form
5. Monitor Railway logs for any issues

## 🐛 Troubleshooting

**Backend not connecting:**
- Check Railway logs: `railway logs`
- Verify DATABASE_URL is set
- Ensure PostgreSQL is running

**Frontend can't reach backend:**
- Verify API_URL is correct
- Check CORS settings in backend
- Check browser console for errors

**Database errors:**
- Ensure PostgreSQL service is running in Railway
- Check DATABASE_URL format
- Review Railway logs

## 📚 Full Documentation

- Backend details: `backend/README.md`
- Deployment guide: `website/DEPLOYMENT.md`
- Railway docs: https://docs.railway.app
- Netlify docs: https://docs.netlify.com

