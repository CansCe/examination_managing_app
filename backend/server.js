import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { MongoClient, ObjectId } from 'mongodb';

const app = express();
app.use(cors());
app.use(express.json());

const mongoUri = process.env.MONGODB_URI;
if (!mongoUri) {
  console.error('Missing MONGODB_URI in environment');
  process.exit(1);
}

const client = new MongoClient(mongoUri, {
  // Let the driver handle SRV and modern connection management
});

async function getDb() {
  if (!client.topology || !client.topology.isConnected()) {
    await client.connect();
  }
  // Default DB can be provided in the URI; fallback set here
  const defaultDbName = process.env.MONGODB_DB || 'exam_management';
  return client.db(defaultDbName);
}

// Healthcheck
app.get('/health', async (_req, res) => {
  try {
    await getDb();
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e) });
  }
});

// GET /exams/:id
app.get('/exams/:id', async (req, res) => {
  try {
    const db = await getDb();
    const id = req.params.id;
    let oid;
    try {
      oid = new ObjectId(id);
    } catch {
      return res.status(400).json({ error: 'Invalid id' });
    }
    const doc = await db.collection('exams').findOne({ _id: oid });
    if (!doc) return res.status(404).json({ error: 'Not found' });
    res.json(doc);
  } catch (e) {
    res.status(500).json({ error: String(e) });
  }
});

// POST /exams
app.post('/exams', async (req, res) => {
  try {
    const db = await getDb();
    const body = req.body ?? {};
    const result = await db.collection('exams').insertOne(body);
    res.status(201).json({ insertedId: String(result.insertedId) });
  } catch (e) {
    res.status(500).json({ error: String(e) });
  }
});

const port = Number(process.env.PORT || 3000);
app.listen(port, () => {
  console.log(`API running on http://localhost:${port}`);
});

// Graceful shutdown
process.on('SIGINT', async () => {
  try {
    await client.close();
  } finally {
    process.exit(0);
  }
});

