# 🎨 Supabase Frontend Integration (Direct)

This is the **simplest** approach - no backend needed!

## 📦 Step 1: Add Supabase Script

Add this to your `index.html` in the `<head>` section (before closing `</head>`):

```html
<!-- Supabase Client -->
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
```

## 🔧 Step 2: Update JavaScript

Replace the waitlist functions in `index.html` with this:

```javascript
// Supabase Configuration
const SUPABASE_URL = 'https://your-project.supabase.co'; // Your Supabase project URL
const SUPABASE_ANON_KEY = 'your-anon-key-here'; // Your Supabase anon key

// Initialize Supabase client
const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Updated waitlist handler (header form)
async function handleWaitlist(event) {
    event.preventDefault();
    const emailInput = document.getElementById('waitlist-email');
    const submitButton = document.querySelector('.waitlist-button');
    const email = emailInput.value.trim();
    
    // Basic validation
    if (!email || !email.includes('@')) {
        showMessage('Please enter a valid email address.', 'error');
        return;
    }
    
    // Disable button and show loading state
    submitButton.disabled = true;
    submitButton.textContent = 'Joining...';
    
    try {
        // Insert into Supabase
        const { data, error } = await supabase
            .from('waitlist')
            .insert([
                { 
                    email: email.toLowerCase().trim(),
                    ip_address: null, // Can't get IP from frontend easily
                    user_agent: navigator.userAgent
                }
            ])
            .select();
        
        if (error) {
            // Check if it's a duplicate email error
            if (error.code === '23505') { // PostgreSQL unique constraint violation
                showMessage('You\'re already on the waitlist!', 'success');
            } else {
                throw error;
            }
        } else {
            showMessage('Thanks! We\'ll notify you when SE7EN is available.', 'success');
            emailInput.value = '';
        }
    } catch (error) {
        console.error('Waitlist error:', error);
        showMessage('Something went wrong. Please try again later.', 'error');
    } finally {
        // Re-enable button
        submitButton.disabled = false;
        submitButton.textContent = 'Join Waitlist';
    }
}

// Updated popup waitlist handler
async function handlePopupWaitlist(event) {
    event.preventDefault();
    const emailInput = document.getElementById('popup-waitlist-email');
    const submitButton = event.target;
    const buttonText = submitButton.querySelector('.button-text');
    const buttonIcon = submitButton.querySelector('.button-icon');
    const email = emailInput.value.trim();
    
    // Basic validation
    if (!email || !email.includes('@')) {
        showPopupMessage('Please enter a valid email address.', 'error');
        emailInput.focus();
        return;
    }
    
    // Disable button and show loading state
    submitButton.disabled = true;
    buttonText.textContent = 'Joining...';
    buttonIcon.textContent = '⏳';
    
    try {
        // Insert into Supabase
        const { data, error } = await supabase
            .from('waitlist')
            .insert([
                { 
                    email: email.toLowerCase().trim(),
                    ip_address: null,
                    user_agent: navigator.userAgent
                }
            ])
            .select();
        
        if (error) {
            // Check if it's a duplicate email error
            if (error.code === '23505') {
                showPopupMessage('You\'re already on the waitlist!', 'success');
                markWaitlistJoined();
            } else {
                throw error;
            }
        } else {
            showPopupMessage('Thanks! We\'ll notify you when SE7EN is available.', 'success');
            markWaitlistJoined();
            emailInput.value = '';
            buttonText.textContent = 'Joined!';
            buttonIcon.textContent = '✓';
            
            // Close popup after 2.5 seconds
            setTimeout(() => {
                closeWaitlistPopup();
            }, 2500);
        }
    } catch (error) {
        console.error('Waitlist error:', error);
        showPopupMessage('Something went wrong. Please try again later.', 'error');
        buttonText.textContent = 'Join Waitlist';
        buttonIcon.textContent = '→';
        submitButton.disabled = false;
    }
}
```

## 🔒 Step 3: Secure Your Keys (Important!)

**Option A: Use Netlify Environment Variables (Recommended)**

1. In Netlify, go to **Site Settings** → **Environment Variables**
2. Add:
   - `SUPABASE_URL` = `https://your-project.supabase.co`
   - `SUPABASE_ANON_KEY` = `your-anon-key-here`
3. Update your code to read from environment:

```javascript
// At the top of your script section
const SUPABASE_URL = window.SUPABASE_URL || 'https://your-project.supabase.co';
const SUPABASE_ANON_KEY = window.SUPABASE_ANON_KEY || 'your-anon-key-here';
```

**Option B: Hardcode (Less Secure, but OK for public anon key)**

The `anon` key is designed to be public, but using environment variables is still better practice.

## ✅ Benefits of This Approach

- ✅ **No backend needed** - Simpler architecture
- ✅ **Free** - Supabase free tier is generous
- ✅ **Fast** - Direct database connection
- ✅ **Secure** - Row Level Security protects your data
- ✅ **Easy to view** - Supabase dashboard shows all emails

## 🎯 That's It!

Your waitlist is now powered by Supabase. No backend server needed!


