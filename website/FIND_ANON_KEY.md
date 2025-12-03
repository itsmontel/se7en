# 🔑 How to Find Your Supabase Anon Key

## Quick Steps:

1. **Go to your Supabase project**: https://supabase.com/dashboard/project/YOUR_PROJECT_ID

2. **Click the Settings icon** (⚙️ gear icon) in the left sidebar (at the bottom)

3. **Click "API"** in the settings menu

4. **Look for "Project API keys"** section

5. **Find the "anon" or "public" key** - it's a long string that starts with `eyJ...`

6. **Click "Reveal"** if it's hidden, then **copy it**

## What You're Looking For:

```
Project API keys
┌─────────────────────────────────────────────┐
│ anon public                                 │
│ eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...     │
│ [Reveal] [Copy]                             │
└─────────────────────────────────────────────┘
```

**Important:** Use the **anon public** key, NOT the **service_role** key (that one is secret).

## Once You Have It:

### Option 1: Update Code Directly (Quick Test)
Replace line 220 in `index.html`:
```javascript
return 'your-anon-key-here';
```
With:
```javascript
return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'; // Your actual key
```

### Option 2: Use Netlify Environment Variables (Recommended for Production)
1. In Netlify → Site Settings → Environment Variables
2. Add:
   - `SUPABASE_URL` = `https://your-project-id.supabase.co`
   - `SUPABASE_ANON_KEY` = `your-anon-key-here`

## Direct Link:
If you're logged in, try this direct link:
https://supabase.com/dashboard/project/YOUR_PROJECT_ID/settings/api


