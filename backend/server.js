const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// CORS Configuration - Restrict to allowed origins
const corsOptions = {
  origin: function (origin, callback) {
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) return callback(null, true);
    
    const allowedOrigins = [
      process.env.FRONTEND_URL, // Set this in Railway: https://your-site.netlify.app
      'http://localhost:8000', // Local development
      'http://localhost:3000', // Local development
    ].filter(Boolean); // Remove undefined values
    
    // In production, only allow specific origins
    if (process.env.NODE_ENV === 'production') {
      if (allowedOrigins.indexOf(origin) !== -1) {
        callback(null, true);
      } else {
        callback(new Error('Not allowed by CORS'));
      }
    } else {
      // In development, allow localhost
      if (!origin || allowedOrigins.indexOf(origin) !== -1 || origin.includes('localhost')) {
        callback(null, true);
      } else {
        callback(new Error('Not allowed by CORS'));
      }
    }
  },
  credentials: true,
  optionsSuccessStatus: 200
};

// Middleware
app.use(cors(corsOptions));
app.use(express.json({ limit: '10kb' })); // Limit request size

// Rate limiting for waitlist endpoint
const waitlistLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 requests per 15 minutes per IP
  message: {
    success: false,
    error: 'Too many requests. Please try again in 15 minutes.'
  },
  standardHeaders: true, // Return rate limit info in headers
  legacyHeaders: false,
});

// Rate limiting for stats endpoint (more restrictive)
const statsLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 10, // 10 requests per hour
  message: {
    success: false,
    error: 'Too many requests. Please try again later.'
  }
});

// Database connection (Railway PostgreSQL)
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

// Initialize database table
async function initDatabase() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS waitlist (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        ip_address VARCHAR(45),
        user_agent TEXT
      )
    `);
    console.log('✅ Database table initialized');
  } catch (error) {
    console.error('❌ Database initialization error:', error);
  }
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Add email to waitlist (with rate limiting)
app.post('/api/waitlist', waitlistLimiter, async (req, res) => {
  try {
    const { email } = req.body;
    
    // Validate email
    if (!email || !email.includes('@')) {
      return res.status(400).json({ 
        success: false, 
        error: 'Please provide a valid email address' 
      });
    }

    // Basic email format validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ 
        success: false, 
        error: 'Please provide a valid email address' 
      });
    }

    // Get client info (optional, for analytics)
    const ipAddress = req.ip || req.headers['x-forwarded-for'] || req.connection.remoteAddress;
    const userAgent = req.headers['user-agent'];

    // Insert into database
    const result = await pool.query(
      `INSERT INTO waitlist (email, ip_address, user_agent) 
       VALUES ($1, $2, $3) 
       ON CONFLICT (email) DO NOTHING 
       RETURNING id, email, created_at`,
      [email.toLowerCase().trim(), ipAddress, userAgent]
    );

    // If no rows returned, email already exists
    if (result.rows.length === 0) {
      return res.status(200).json({ 
        success: true, 
        message: 'You\'re already on the waitlist!',
        alreadyExists: true
      });
    }

    res.status(201).json({ 
      success: true, 
      message: 'Thanks! We\'ll notify you when SE7EN is available.',
      data: {
        id: result.rows[0].id,
        email: result.rows[0].email,
        createdAt: result.rows[0].created_at
      }
    });

  } catch (error) {
    console.error('Error adding to waitlist:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Something went wrong. Please try again later.' 
    });
  }
});

// Get waitlist stats (optional, for admin) - with rate limiting
app.get('/api/waitlist/stats', statsLimiter, async (req, res) => {
  try {
    const result = await pool.query('SELECT COUNT(*) as total FROM waitlist');
    res.json({ 
      success: true, 
      total: parseInt(result.rows[0].total) 
    });
  } catch (error) {
    console.error('Error getting stats:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to retrieve stats' 
    });
  }
});

// Start server
async function startServer() {
  await initDatabase();
  
  app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`📧 Waitlist API: http://localhost:${PORT}/api/waitlist`);
  });
}

startServer().catch(console.error);

