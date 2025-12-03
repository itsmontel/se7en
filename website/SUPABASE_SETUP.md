# 🚀 Supabase Waitlist Setup Guide

Supabase is a great alternative to Railway - it's easier to set up and perfect for a waitlist!

## ✅ Why Supabase?

- ✅ **Free tier** - Perfect for waitlists
- ✅ **Easy setup** - No server code needed (can use directly from frontend)
- ✅ **Built-in security** - Row Level Security (RLS) policies
- ✅ **Real-time** - Optional real-time updates
- ✅ **Dashboard** - Easy to view/manage waitlist emails

---

## 📋 Step 1: Create Supabase Project (5 minutes)

1. Go to [supabase.com](https://supabase.com)
2. Sign up or log in (free account)
3. Click **"New Project"**
4. Fill in:
   - **Name:** `se7en-waitlist` (or any name)
   - **Database Password:** Create a strong password (save it!)
   - **Region:** Choose closest to you
5. Click **"Create new project"**
6. Wait 2-3 minutes for setup

---

## 🗄️ Step 2: Create Database Table (2 minutes)

1. In Supabase dashboard, go to **"SQL Editor"**
2. Click **"New query"**
3. Paste this SQL:

```sql
-- Create waitlist table
CREATE TABLE waitlist (
  id BIGSERIAL PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ip_address TEXT,
  user_agent TEXT
);

-- Create index for faster lookups
CREATE INDEX idx_waitlist_email ON waitlist(email);
CREATE INDEX idx_waitlist_created_at ON waitlist(created_at DESC);

-- Enable Row Level Security
ALTER TABLE waitlist ENABLE ROW LEVEL SECURITY;

-- Create policy to allow inserts (for public signups)
CREATE POLICY "Allow public inserts" ON waitlist
  FOR INSERT
  TO anon
  WITH CHECK (true);

-- Create policy to allow reads (optional - for viewing stats)
CREATE POLICY "Allow public reads" ON waitlist
  FOR SELECT
  TO anon
  USING (true);
```

4. Click **"Run"** (or press Cmd/Ctrl + Enter)
5. ✅ Table created!

---

## 🔑 Step 3: Get API Keys (1 minute)

1. In Supabase dashboard, go to **"Settings"** (gear icon)
2. Click **"API"**
3. Copy these values:
   - **Project URL** (e.g., `https://xxxxx.supabase.co`)
   - **anon/public key** (starts with `eyJ...`)

**⚠️ Important:** The `anon` key is safe to use in frontend code - it's designed for public access with RLS policies protecting your data.

---

## 💻 Step 4: Update Frontend Code

You have two options:

### Option A: Direct from Frontend (Simplest) ✅ Recommended

No backend needed! Supabase can be called directly from your website.

### Option B: Keep Backend (More Secure)

Use your existing backend but connect it to Supabase instead of Railway.

---

## 📝 Next Steps

See the implementation files:
- `SUPABASE_FRONTEND.md` - For direct frontend integration
- `SUPABASE_BACKEND.md` - For backend integration

---

## 🎯 Quick Comparison

| Feature | Railway | Supabase |
|---------|---------|----------|
| Setup Time | 10-15 min | 5 min |
| Backend Code | Required | Optional |
| Database | Separate setup | Included |
| Free Tier | Limited | Generous |
| Dashboard | Basic | Excellent |
| Best For | Complex apps | Simple apps/waitlists |

---

## ✅ You're Ready!

After setup, you'll have:
- ✅ Database table ready
- ✅ Security policies configured
- ✅ API keys to use
- ✅ Dashboard to view emails


