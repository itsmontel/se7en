-- ============================================
-- SE7EN WAITLIST TABLE WITH SOURCE TRACKING
-- ============================================
-- Copy and paste this entire SQL into Supabase SQL Editor

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

-- ============================================
-- SOURCE VALUES:
-- ============================================
-- 'header' - Signed up from header waitlist form
-- 'footer' - Signed up from footer waitlist form
-- 'popup' - Signed up from popup modal (scroll/time-based)
-- 'app_store_popup' - Signed up from App Store button popup
-- ============================================

-- View to see signups by source
CREATE OR REPLACE VIEW waitlist_by_source AS
SELECT 
  source,
  COUNT(*) as total_signups,
  COUNT(DISTINCT email) as unique_emails,
  MIN(created_at) as first_signup,
  MAX(created_at) as latest_signup
FROM waitlist
GROUP BY source
ORDER BY total_signups DESC;

-- Query to see all signups with source
-- SELECT email, source, created_at FROM waitlist ORDER BY created_at DESC;


