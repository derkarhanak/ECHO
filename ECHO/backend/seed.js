const { createClient } = require('redis');
const { v4: uuidv4 } = require('uuid');

const messages = [
    "Is anyone actually listening?",
    "I saw a cat today that looked like it knew the secrets of the universe.",
    "Sometimes silence is the loudest noise.",
    "Do you think we're alone?",
    "I forgot to water my plants again.",
    "The sky looks fake today.",
    "Echo... echo... echo...",
    "I wish I could restart yesterday.",
    "What if the internet is just a dream?",
    "Sending this to nowhere, hoping for somewhere.",
    "Does gravity get tired?",
    "I miss the version of me from 5 years ago.",
    "Hello from the other side.",
    "Why do we close our eyes when we pray, cry, kiss, dream?",
    "I'm scared of the dark, but I love the stars.",
    "Just existing is exhausting sometimes.",
    "Coffee is my only personality trait.",
    "I think my neighbor is a spy.",
    "If you read this, take a deep breath.",
    "The void is cozy."
];

async function seed() {
    const client = createClient();
    await client.connect();

    console.log('Seeding the void...');

    for (const content of messages) {
        const id = uuidv4();
        const echo = {
            id,
            content,
            metadata: { seeded: true },
            timestamp: Date.now()
        };

        await client.set(`echo:${id}`, JSON.stringify(echo));
        await client.sAdd('global_drift', id);
        console.log(`+ ${content}`);
    }

    console.log('Void populated.');
    await client.disconnect();
}

seed();
