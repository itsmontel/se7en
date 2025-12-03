// Build script to inject Netlify environment variables into index.html
const fs = require('fs');
const path = require('path');

const htmlPath = path.join(__dirname, 'index.html');
let html = fs.readFileSync(htmlPath, 'utf8');

// Get environment variables from Netlify (or use fallbacks)
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://your-project.supabase.co';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || 'your-anon-key-here';

// Inject environment variables as window variables
const injectScript = `    <script>
        // Injected by Netlify build process
        window.SUPABASE_URL = '${SUPABASE_URL}';
        window.SUPABASE_ANON_KEY = '${SUPABASE_ANON_KEY}';
    </script>
`;

// Replace the injection point comment with the actual script
html = html.replace(
    '    <!-- ENV_INJECTION_POINT -->',
    injectScript + '    <!-- ENV_INJECTION_POINT -->'
);

fs.writeFileSync(htmlPath, html, 'utf8');
console.log('✅ Environment variables injected successfully');

