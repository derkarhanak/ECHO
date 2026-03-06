const express = require('express');
const cors = require('cors');
const Database = require('better-sqlite3');
const { v4: uuidv4 } = require('uuid');
const Filter = require('bad-words');
const path = require('path');
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');

const app = express();
app.use(express.json());
app.use(cors());

// --- Security & Scalability Configuration ---
const JWT_SECRET = process.env.JWT_SECRET || 'ECHO_DEFAULT_DEV_SECRET_DO_NOT_USE_IN_PROD';

const exhaleLimiter = rateLimit({
    windowMs: 60 * 1000, 
    max: 5,
    message: 'The void is overwhelmed. Exhale slower.'
});

const defaultLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 30,
    message: 'The drift is turbulent. Wait a moment.'
});

// Initialize SQLite database
const dbPath = path.join(__dirname, 'echo.db');
const db = new Database(dbPath);
db.pragma('journal_mode = WAL'); // Enable concurrent reading/writing
const filter = new Filter();

const MAX_LENGTH = 500;
const EXPIRATION_TIME = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

// Initialize database schema
function initializeDatabase() {
    db.exec(`
        CREATE TABLE IF NOT EXISTS echoes (
            id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            senderId TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            expiresAt INTEGER NOT NULL,
            metadata TEXT
        );

        CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            threadId TEXT NOT NULL,
            senderId TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            expiresAt INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS inboxes (
            userId TEXT NOT NULL,
            threadId TEXT NOT NULL,
            PRIMARY KEY (userId, threadId)
        );

        CREATE INDEX IF NOT EXISTS idx_echoes_expiresAt ON echoes(expiresAt);
        CREATE INDEX IF NOT EXISTS idx_messages_threadId ON messages(threadId);
        CREATE INDEX IF NOT EXISTS idx_messages_expiresAt ON messages(expiresAt);
    `);
    console.log('Database initialized in WAL mode');
}

// Detached Background Garbage Collection
setInterval(() => {
    const now = Date.now();
    try {
        db.prepare('DELETE FROM echoes WHERE expiresAt < ?').run(now);
        db.prepare('DELETE FROM messages WHERE expiresAt < ?').run(now);
        db.prepare(`
            DELETE FROM inboxes WHERE threadId NOT IN (
                SELECT DISTINCT threadId FROM messages
            )
        `).run();
    } catch (e) {
        console.error('GC error:', e);
    }
}, 60000); // Run every minute

// JWT Middleware
function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    
    if (token == null) return res.sendStatus(401);
    
    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) return res.sendStatus(403);
        req.user = user;
        next();
    });
}

// Authentication Issue Route
app.get('/auth', (req, res) => {
    // We issue a new identity to the client
    const newUserId = uuidv4();
    const token = jwt.sign({ userId: newUserId }, JWT_SECRET);
    res.json({ userId: newUserId, token });
});

// The Exhale: Release a thought into the void
app.post('/exhale', authenticateToken, exhaleLimiter, (req, res) => {
    try {
        let { content, metadata } = req.body;
        const userId = req.user.userId;
        
        if (!content) return res.status(400).send('Missing content');
        
        content = content.trim();
        if (content.length === 0) return res.status(400).send('Empty content');
        if (content.length > MAX_LENGTH) return res.status(400).send(`Content too long (max ${MAX_LENGTH})`);
        
        if (filter.isProfane(content)) {
            return res.status(400).send('The void rejects negativity.');
        }

        const echoId = uuidv4();
        const now = Date.now();
        const expiresAt = now + EXPIRATION_TIME;

        db.prepare(`
            INSERT INTO echoes (id, content, senderId, timestamp, expiresAt, metadata)
            VALUES (?, ?, ?, ?, ?, ?)
        `).run(echoId, content, userId, now, expiresAt, JSON.stringify(metadata || {}));

        res.status(201).json({ status: 'released', id: echoId });
    } catch (error) {
        console.error('Exhale error:', error);
        res.status(500).send('Internal server error');
    }
});

// The Catch: Grab a random thought from the drift
app.get('/catch', authenticateToken, defaultLimiter, (req, res) => {
    try {
        const echo = db.prepare(`
            SELECT * FROM echoes 
            WHERE expiresAt > ? 
            ORDER BY RANDOM() 
            LIMIT 1
        `).get(Date.now());
        
        if (!echo) return res.status(404).send('The void is silent');

        res.json({
            id: echo.id,
            content: echo.content,
            senderId: echo.senderId,
            timestamp: echo.timestamp,
            metadata: JSON.parse(echo.metadata)
        });
    } catch (error) {
        console.error('Catch error:', error);
        res.status(500).send('Internal server error');
    }
});

// The Reply: Start or continue a thread
app.post('/reply', authenticateToken, defaultLimiter, (req, res) => {
    try {
        let { echoId, content } = req.body;
        const senderId = req.user.userId;
        
        if (!echoId || !content) return res.status(400).send('Missing fields');
        
        content = content.trim();
        if (content.length === 0) return res.status(400).send('Empty content');
        if (content.length > MAX_LENGTH) return res.status(400).send(`Content too long`);
        
        if (filter.isProfane(content)) {
            return res.status(400).send('The void rejects negativity.');
        }

        const echo = db.prepare('SELECT senderId FROM echoes WHERE id = ? AND expiresAt > ?').get(echoId, Date.now());
        if (!echo) return res.status(404).send('Echo faded');
        
        const ownerId = echo.senderId;
        const threadId = `thread:${echoId}:${senderId}`;
        const now = Date.now();
        const expiresAt = now + EXPIRATION_TIME;

        // Add message to thread
        db.prepare(`
            INSERT INTO messages (threadId, senderId, content, timestamp, expiresAt)
            VALUES (?, ?, ?, ?, ?)
        `).run(threadId, senderId, content, now, expiresAt);

        // Notify owner and sender
        db.prepare(`INSERT OR IGNORE INTO inboxes (userId, threadId) VALUES (?, ?)`).run(ownerId, threadId);
        db.prepare(`INSERT OR IGNORE INTO inboxes (userId, threadId) VALUES (?, ?)`).run(senderId, threadId);

        res.status(201).json({ status: 'sent', threadId });
    } catch (error) {
        console.error('Reply error:', error);
        res.status(500).send('Internal server error');
    }
});

// The Inbox: Check for active threads
app.get('/inbox', authenticateToken, defaultLimiter, (req, res) => {
    try {
        const userId = req.user.userId;
        const now = Date.now();
        
        // Single JOIN query removing the N+1 database hits
        const rows = db.prepare(`
            SELECT m.threadId, m.senderId, m.content, m.timestamp
            FROM messages m
            INNER JOIN inboxes i ON m.threadId = i.threadId
            WHERE i.userId = ? AND m.expiresAt > ?
            ORDER BY m.threadId, m.timestamp ASC
        `).all(userId, now);

        const threadMap = {};
        for (const row of rows) {
            if (!threadMap[row.threadId]) {
                threadMap[row.threadId] = { id: row.threadId, messages: [] };
            }
            threadMap[row.threadId].messages.push({
                senderId: row.senderId,
                content: row.content,
                timestamp: row.timestamp
            });
        }
        
        res.json(Object.values(threadMap));
    } catch (error) {
        console.error('Inbox error:', error);
        res.status(500).send('Internal server error');
    }
});

const PORT = 8000;

initializeDatabase();

app.listen(PORT, () => {
    console.log(`ECHO Routing Engine alive on port ${PORT}`);
    console.log(`Database: ${dbPath}`);
});

