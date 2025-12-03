// ============================================
// SUPABASE INTEGRATION FOR SE7EN WAITLIST
// ============================================
// Replace the API_URL section in index.html with this code

// Supabase Configuration
// Option 1: Use Netlify environment variables (recommended)
// In Netlify: Site Settings → Environment Variables → Add:
//   - SUPABASE_URL = https://your-project.supabase.co
//   - SUPABASE_ANON_KEY = your-anon-key-here
// Option 2: Update the fallback values below

const SUPABASE_URL = (function() {
    if (typeof window.SUPABASE_URL !== 'undefined') {
        return window.SUPABASE_URL;
    }
    // Fallback: Update with your Supabase project URL
    return 'https://your-project.supabase.co';
})();

const SUPABASE_ANON_KEY = (function() {
    if (typeof window.SUPABASE_ANON_KEY !== 'undefined') {
        return window.SUPABASE_ANON_KEY;
    }
    // Fallback: Update with your Supabase anon key
    return 'your-anon-key-here';
})();

// Initialize Supabase client
let supabaseClient = null;
if (window.supabase) {
    supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
} else {
    console.error('Supabase library not loaded. Add this to <head>: <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>');
}

// Helper function to add email to waitlist
async function addToWaitlist(email) {
    if (!supabaseClient) {
        throw new Error('Supabase client not initialized');
    }
    
    try {
        const { data, error } = await supabaseClient
            .from('waitlist')
            .insert([
                { 
                    email: email.toLowerCase().trim(),
                    ip_address: null, // Can't reliably get IP from frontend
                    user_agent: navigator.userAgent
                }
            ])
            .select();
        
        if (error) {
            // Check if it's a duplicate email error (PostgreSQL unique constraint)
            if (error.code === '23505' || error.message.includes('duplicate') || error.message.includes('unique')) {
                return {
                    success: true,
                    message: 'You\'re already on the waitlist!',
                    alreadyExists: true
                };
            }
            throw error;
        }
        
        return {
            success: true,
            message: 'Thanks! We\'ll notify you when SE7EN is available.',
            data: data[0]
        };
    } catch (error) {
        console.error('Supabase error:', error);
        throw new Error(error.message || 'Something went wrong. Please try again later.');
    }
}

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
        const result = await addToWaitlist(email);
        showMessage(result.message, result.alreadyExists ? 'success' : 'success');
        if (result.success && !result.alreadyExists) {
            emailInput.value = '';
        }
    } catch (error) {
        showMessage(error.message || 'Something went wrong. Please try again later.', 'error');
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
        const result = await addToWaitlist(email);
        
        if (result.success) {
            showPopupMessage(result.message, 'success');
            if (result.alreadyExists) {
                markWaitlistJoined();
            } else {
                markWaitlistJoined();
                emailInput.value = '';
                buttonText.textContent = 'Joined!';
                buttonIcon.textContent = '✓';
                
                // Close popup after 2.5 seconds
                setTimeout(() => {
                    closeWaitlistPopup();
                }, 2500);
            }
        }
    } catch (error) {
        console.error('Waitlist error:', error);
        showPopupMessage(error.message || 'Something went wrong. Please try again later.', 'error');
        buttonText.textContent = 'Join Waitlist';
        buttonIcon.textContent = '→';
        submitButton.disabled = false;
    }
}


