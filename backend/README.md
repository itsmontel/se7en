# SE7EN Waitlist Backend API

Backend API for managing the SE7EN app waitlist, designed to run on Railway.

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ 
- PostgreSQL database (Railway provides this)

### Local Development

1. **Install dependencies**
   ```bash
   npm install
   ```

2. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your database URL
   ```

3. **Run the server**
   ```bash
   npm start
   # Or for development with auto-reload:
   npm run dev
   ```

The API will be available at `http://localhost:3000`

## 📡 API Endpoints

### POST `/api/waitlist`
Add an email to the waitlist.

**Request:**
```json
{
  "email": "user@example.com"
}
```

**Success Response (201):**
```json
{
  "success": true,
  "message": "Thanks! We'll notify you when SE7EN is available.",
  "data": {
    "id": 1,
    "email": "user@example.com",
    "createdAt": "2025-01-15T10:30:00Z"
  }
}
```

**Already Exists Response (200):**
```json
{
  "success": true,
  "message": "You're already on the waitlist!",
  "alreadyExists": true
}
```

**Error Response (400):**
```json
{
  "success": false,
  "error": "Please provide a valid email address"
}
```

### GET `/api/waitlist/stats`
Get waitlist statistics (total count).

**Response:**
```json
{
  "success": true,
  "total": 1234
}
```

### GET `/health`
Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2025-01-15T10:30:00Z"
}
```

## 🚂 Railway Deployment

### Step 1: Create Railway Project

1. Go to [railway.app](https://railway.app)
2. Click "New Project"
3. Select "Deploy from GitHub repo" (or upload the backend folder)

### Step 2: Add PostgreSQL Database

1. In your Railway project, click "New"
2. Select "Database" → "Add PostgreSQL"
3. Railway will automatically create a `DATABASE_URL` environment variable

### Step 3: Configure Environment Variables

Railway will automatically set:
- `PORT` - Server port (set automatically)
- `DATABASE_URL` - PostgreSQL connection string (set automatically when you add PostgreSQL)

You can also set:
- `NODE_ENV=production` (optional, defaults to production on Railway)

### Step 4: Deploy

Railway will automatically:
1. Detect `package.json` and install dependencies
2. Run `npm start` to start the server
3. Expose your API via a public URL

### Step 5: Get Your API URL

1. In Railway, click on your service
2. Go to "Settings" → "Networking"
3. Generate a public domain (e.g., `se7en-api.up.railway.app`)
4. Copy this URL - you'll need it for your frontend

## 🔗 Connecting Frontend

Update your frontend (Netlify) to use the Railway API URL:

1. In Netlify, go to your site settings
2. Add an environment variable:
   - Key: `VITE_API_URL` (or `REACT_APP_API_URL` depending on your setup)
   - Value: `https://your-railway-url.up.railway.app`

Or update the frontend code directly with your Railway API URL.

## 📊 Database Schema

The waitlist table structure:

```sql
CREATE TABLE waitlist (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  ip_address VARCHAR(45),
  user_agent TEXT
);
```

## 🔒 Security Notes

- Email addresses are stored in lowercase and trimmed
- Duplicate emails are prevented (unique constraint)
- IP addresses and user agents are stored for analytics (optional)
- CORS is enabled for frontend access
- Input validation is performed on all endpoints

## 🛠️ Troubleshooting

**Database connection errors:**
- Ensure `DATABASE_URL` is set correctly in Railway
- Check that PostgreSQL service is running
- Verify SSL settings match your environment

**Port errors:**
- Railway sets `PORT` automatically - don't hardcode it
- Ensure your code uses `process.env.PORT`

**CORS errors:**
- Update CORS settings in `server.js` if needed
- Ensure your frontend domain is allowed

## 📝 Next Steps

- [ ] Add email verification (optional)
- [ ] Add rate limiting
- [ ] Add email notifications when app launches
- [ ] Add admin dashboard for viewing waitlist
- [ ] Export waitlist to CSV functionality

