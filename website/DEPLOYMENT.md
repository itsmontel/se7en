# SE7EN Website Deployment Guide

## 🚀 Deployment Setup

### Frontend (Netlify)

1. **Connect Repository**
   - Push your website folder to GitHub
   - Connect GitHub repo to Netlify
   - Netlify will auto-detect and deploy

2. **Set Environment Variable**
   - Go to Site Settings → Environment Variables
   - Add: `API_URL` = `https://your-railway-api.up.railway.app`
   - This will be available as `window.API_URL` in the frontend

3. **Build Settings** (if needed)
   - Build command: (leave empty for static site)
   - Publish directory: `/` (root)

### Backend (Railway)

See `../backend/README.md` for complete Railway deployment instructions.

**Quick Steps:**
1. Create Railway project
2. Add PostgreSQL database
3. Deploy backend folder
4. Copy Railway API URL
5. Add to Netlify environment variables

## 🔗 Connecting Frontend to Backend

### Option 1: Environment Variable (Recommended)

In Netlify:
1. Go to Site Settings → Environment Variables
2. Add: `API_URL` = `https://your-railway-api.up.railway.app`
3. Redeploy

The frontend will automatically use this URL.

### Option 2: Direct Update

Edit `index.html` and update this line:
```javascript
const API_URL = window.API_URL || 'https://your-railway-api.up.railway.app';
```

Replace `'https://your-railway-api.up.railway.app'` with your actual Railway API URL.

## 🧪 Testing

### Test Backend Locally

1. Set up PostgreSQL locally or use Railway's database URL
2. Run `npm install` in backend folder
3. Create `.env` file with `DATABASE_URL`
4. Run `npm start`
5. Test: `curl -X POST http://localhost:3000/api/waitlist -H "Content-Type: application/json" -d '{"email":"test@example.com"}'`

### Test Frontend Locally

1. Update API_URL in `index.html` to `http://localhost:3000`
2. Serve website: `python3 -m http.server 8000`
3. Open `http://localhost:8000`
4. Test waitlist form

## 📝 Checklist

- [ ] Backend deployed on Railway
- [ ] PostgreSQL database connected
- [ ] API URL copied from Railway
- [ ] API URL added to Netlify environment variables
- [ ] Frontend deployed on Netlify
- [ ] Test waitlist form submission
- [ ] Verify emails are saved in database
- [ ] Test error handling (invalid email, duplicate email)

## 🔒 Security Notes

- API URL should use HTTPS in production
- CORS is configured to allow frontend domain
- Email validation happens on both frontend and backend
- Duplicate emails are handled gracefully

## 🐛 Troubleshooting

**Frontend can't connect to backend:**
- Check API_URL is set correctly
- Verify Railway service is running
- Check CORS settings in backend
- Check browser console for errors

**Database connection errors:**
- Verify DATABASE_URL in Railway
- Check PostgreSQL service is running
- Review Railway logs for errors

**CORS errors:**
- Ensure frontend domain is allowed in backend CORS settings
- Check Railway networking settings

