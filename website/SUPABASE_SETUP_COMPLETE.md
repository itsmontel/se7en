# ✅ Complete Supabase Setup with Source Tracking

## 📋 SQL to Run in Supabase

**Copy and paste this entire SQL into Supabase SQL Editor:**

```sql
-- Create waitlist table with source tracking
CREATE TABLE IF NOT EXISTS waitlist (
  id BIGSERIAL PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  source TEXT NOT NULL DEFAULT 'unknown',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ip_address TEXT,
  user_agent TEXT
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_waitlist_email ON waitlist(email);
CREATE INDEX IF NOT EXISTS idx_waitlist_created_at ON waitlist(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_waitlist_source ON waitlist(source);

-- Enable Row Level Security
ALTER TABLE waitlist ENABLE ROW LEVEL SECURITY;

-- Create policy to allow inserts (for public signups)
DROP POLICY IF EXISTS "Allow public inserts" ON waitlist;
CREATE POLICY "Allow public inserts" ON waitlist
  FOR INSERT
  TO anon
  WITH CHECK (true);

-- Create policy to allow reads (optional - for viewing stats)
DROP POLICY IF EXISTS "Allow public reads" ON waitlist;
CREATE POLICY "Allow public reads" ON waitlist
  FOR SELECT
  TO anon
  USING (true);
```

## 📊 Source Values Tracked

Your code automatically tracks these sources:

- **`header`** - User signed up from the header waitlist form
- **`footer`** - User signed up from the footer waitlist form  
- **`popup`** - User signed up from the scroll/time-based popup modal
- **`app_store_popup`** - User signed up from clicking the App Store button (which triggers popup)

## 🔍 How to View Your Data

### View All Signups with Source

```sql
SELECT 
  email, 
  source, 
  created_at 
FROM waitlist 
ORDER BY created_at DESC;
```

### Count Signups by Source

```sql
SELECT 
  source,
  COUNT(*) as total_signups,
  COUNT(DISTINCT email) as unique_emails
FROM waitlist
GROUP BY source
ORDER BY total_signups DESC;
```

### View in Supabase Dashboard

1. Go to **"Table Editor"** in Supabase
2. Click on **"waitlist"** table
3. You'll see all columns including the **`source`** column
4. Filter/sort by source to see which method is most effective!

## 📈 Example Queries

### Most Popular Signup Method

```sql
SELECT 
  source,
  COUNT(*) as signups,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM waitlist), 2) as percentage
FROM waitlist
GROUP BY source
ORDER BY signups DESC;
```

### Recent Signups by Source (Last 24 Hours)

```sql
SELECT 
  source,
  COUNT(*) as signups
FROM waitlist
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY source
ORDER BY signups DESC;
```

### Daily Signups Breakdown

```sql
SELECT 
  DATE(created_at) as date,
  source,
  COUNT(*) as signups
FROM waitlist
GROUP BY DATE(created_at), source
ORDER BY date DESC, signups DESC;
```

## ✅ What's Already Done

- ✅ SQL table created with `source` column
- ✅ Code updated to track source for all 4 signup methods
- ✅ Header form → `source: 'header'`
- ✅ Footer form → `source: 'footer'`
- ✅ Scroll/time popup → `source: 'popup'`
- ✅ App Store button popup → `source: 'app_store_popup'`

## 🎯 Next Steps

1. **Run the SQL** in Supabase SQL Editor
2. **Deploy your website** to Netlify
3. **Set Supabase credentials** in Netlify environment variables
4. **Test each signup method** to verify sources are tracked
5. **View your data** in Supabase dashboard!

## 💡 Pro Tip

Create a dashboard view in Supabase to see real-time stats:

```sql
CREATE OR REPLACE VIEW waitlist_stats AS
SELECT 
  source,
  COUNT(*) as total_signups,
  COUNT(DISTINCT email) as unique_emails,
  MIN(created_at) as first_signup,
  MAX(created_at) as latest_signup,
  ROUND(AVG(EXTRACT(EPOCH FROM (NOW() - created_at))/3600), 2) as avg_hours_ago
FROM waitlist
GROUP BY source
ORDER BY total_signups DESC;
```

Then query it anytime:
```sql
SELECT * FROM waitlist_stats;
```


