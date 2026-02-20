const express = require('express');
const cors = require('cors');
const Database = require('better-sqlite3');
const { v4: uuidv4 } = require('uuid');
const Filter = require('bad-words');
const path = require('path');

const app = express();
app.use(express.json());
app.use(cors());

// Initialize SQLite database
const dbPath = path.join(__dirname, 'echo.db');
const db = new Database(dbPath);
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
    console.log('Database initialized');
}

// Clean up expired data
function cleanupExpired() {
    const now = Date.now();
    db.prepare('DELETE FROM echoes WHERE expiresAt < ?').run(now);
    db.prepare('DELETE FROM messages WHERE expiresAt < ?').run(now);
    // Clean up orphaned inbox entries
    db.prepare(`
        DELETE FROM inboxes WHERE threadId NOT IN (
            SELECT DISTINCT threadId FROM messages
        )
    `).run();
}

// The Exhale: Release a thought into the void
app.post('/exhale', (req, res) => {
    try {
        let { content, userId, metadata } = req.body;
        if (!content || !userId) return res.status(400).send('Missing content or userId');
        
        content = content.trim();
        if (content.length === 0) return res.status(400).send('Empty content');
        if (content.length > MAX_LENGTH) return res.status(400).send(`Content too long (max ${MAX_LENGTH})`);
        
        // Safety Net: Keep the void clean
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
app.get('/catch', (req, res) => {
    try {
        cleanupExpired();
        
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
app.post('/reply', (req, res) => {
    try {
        let { echoId, content, senderId } = req.body;
        if (!echoId || !content || !senderId) return res.status(400).send('Missing fields');
        
        content = content.trim();
        if (content.length === 0) return res.status(400).send('Empty content');
        if (content.length > MAX_LENGTH) return res.status(400).send(`Content too long (max ${MAX_LENGTH})`);
        
        // Safety Net
        if (filter.isProfane(content)) {
            return res.status(400).send('The void rejects negativity.');
        }

        // Fetch original echo to find owner
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

        // Notify owner (Inbox)
        db.prepare(`
            INSERT OR IGNORE INTO inboxes (userId, threadId)
            VALUES (?, ?)
        `).run(ownerId, threadId);
        
        // Notify sender (so they can see their own thread)
        db.prepare(`
            INSERT OR IGNORE INTO inboxes (userId, threadId)
            VALUES (?, ?)
        `).run(senderId, threadId);

        res.status(201).json({ status: 'sent', threadId });
    } catch (error) {
        console.error('Reply error:', error);
        res.status(500).send('Internal server error');
    }
});

// The Inbox: Check for active threads
app.get('/inbox/:userId', (req, res) => {
    try {
        cleanupExpired();
        
        const { userId } = req.params;
        
        const threadRows = db.prepare(`
            SELECT DISTINCT i.threadId 
            FROM inboxes i
            WHERE i.userId = ?
            AND EXISTS (
                SELECT 1 FROM messages m 
                WHERE m.threadId = i.threadId 
                AND m.expiresAt > ?
            )
        `).all(userId, Date.now());

        const threads = [];

        for (const row of threadRows) {
            const messages = db.prepare(`
                SELECT senderId, content, timestamp
                FROM messages
                WHERE threadId = ?
                AND expiresAt > ?
                ORDER BY timestamp ASC
            `).all(row.threadId, Date.now());

            if (messages.length > 0) {
                threads.push({
                    id: row.threadId,
                    messages: messages
                });
            }
        }

        res.json(threads);
    } catch (error) {
        console.error('Inbox error:', error);
        res.status(500).send('Internal server error');
    }
});

const PORT = process.env.PORT || 8000;

initializeDatabase();

app.listen(PORT, () => {
    console.log(`ECHO Routing Engine alive on port ${PORT}`);
    console.log(`Database: ${dbPath}`);
});
