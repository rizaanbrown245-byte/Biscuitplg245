import express from 'express';
import path from 'path';
import { createServer as createViteServer } from 'vite';
import dotenv from 'dotenv';
import { db } from './server/db.js';
import { GoogleGenAI } from '@google/genai';
import {
  getSupabase,
  isSupabaseConfigured,
  checkSupabaseConnection,
  rowToProduct,
  productToRow,
  rowToOrder,
  orderToRow,
  rowToMeme,
  memeToRow,
} from './server/supabase.js';

dotenv.config();

let geminiClient: GoogleGenAI | null = null;
function getGeminiClient(): GoogleGenAI | null {
  if (!geminiClient && process.env.GEMINI_API_KEY) {
    geminiClient = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
  }
  return geminiClient;
}

async function startServer() {
  const app = express();
  const PORT = Number(process.env.PORT) || 3000;

  app.use(express.json({ limit: '20mb' }));
  app.use(express.urlencoded({ limit: '20mb', extended: true }));

  // --- API Routes ---
  app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', business: 'The Biscuit Plug', country: 'ZA' });
  });

  // Supabase connection status
  app.get('/api/supabase/status', async (req, res) => {
    const info = await checkSupabaseConnection();
    res.json({
      configured: isSupabaseConfigured(),
      ...info,
    });
  });

  // Safe Secret / Server variables status inspector (never returns raw secret values)
  app.get('/api/system/secrets-status', (req, res) => {
    const secrets = [
      {
        name: 'GEMINI_API_KEY',
        label: 'Gemini AI API Key',
        isSet: Boolean(process.env.GEMINI_API_KEY),
        category: 'AI & Creative',
        description: 'Powers custom stamped message generation and biscuit suggestions',
      },
      {
        name: 'SUPABASE_URL',
        label: 'Supabase Project URL',
        isSet: Boolean(process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL),
        category: 'Database',
        description: 'Live Cloud database endpoint for live orders, products and memes',
      },
      {
        name: 'SUPABASE_SECRET_KEY',
        label: 'Supabase Secret Key',
        isSet: Boolean(process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY),
        category: 'Database',
        description: 'Server-side key for database reads, order writes, and inventory sync',
      },
      {
        name: 'ADMIN_SECRET_KEY',
        label: 'Baker Admin Secret Key',
        isSet: Boolean(process.env.ADMIN_SECRET_KEY),
        category: 'Security',
        description: 'Custom security passcode for locking the bakery management portal',
      },
      {
        name: 'SESSION_SECRET',
        label: 'Session Secret Key',
        isSet: Boolean(process.env.SESSION_SECRET),
        category: 'Security',
        description: 'Cryptographic secret for signing order tracking tokens and sessions',
      },
      {
        name: 'PAYFAST_MERCHANT_KEY',
        label: 'PayFast Merchant Secret Key',
        isSet: Boolean(process.env.PAYFAST_MERCHANT_KEY),
        category: 'Payments',
        description: 'South African instant EFT and credit card gateway integration',
      },
      {
        name: 'YOCO_SECRET_KEY',
        label: 'Yoco Payments Secret Key',
        isSet: Boolean(process.env.YOCO_SECRET_KEY),
        category: 'Payments',
        description: 'Yoco online payment gateway secret for South Africa',
      },
      {
        name: 'WHATSAPP_API_TOKEN',
        label: 'WhatsApp Cloud API Token',
        isSet: Boolean(process.env.WHATSAPP_API_TOKEN),
        category: 'Notifications',
        description: 'Automated order status notifications sent directly to WhatsApp',
      },
    ];

    const configuredCount = secrets.filter(s => s.isSet).length;

    res.json({
      total: secrets.length,
      configuredCount,
      secrets,
    });
  });

  // Supabase sync / seed endpoint
  app.post('/api/supabase/sync', async (req, res) => {
    try {
      const supabase = getSupabase();
      if (!supabase) {
        return res.status(400).json({
          error: 'Supabase credentials not configured. Please set SUPABASE_URL and SUPABASE_SECRET_KEY.',
        });
      }

      const localProducts = await db.getProducts();
      const productRows = localProducts.map(productToRow);
      const { error: pErr } = await supabase.from('products').upsert(productRows, { onConflict: 'id' });

      const localMemes = await db.getMemes();
      const memeRows = localMemes.map(memeToRow);
      const { error: mErr } = await supabase.from('memes').upsert(memeRows, { onConflict: 'id' });

      if (pErr || mErr) {
        console.error('Supabase sync warning:', pErr, mErr);
        return res.status(500).json({
          error: 'Sync finished with warnings',
          productsError: pErr?.message,
          memesError: mErr?.message,
        });
      }

      res.json({
        success: true,
        message: `Successfully synced ${localProducts.length} biscuits and ${localMemes.length} memes to Supabase!`,
      });
    } catch (err: any) {
      res.status(500).json({ error: err.message || 'Sync failed' });
    }
  });

  // Products
  app.get('/api/products', async (req, res) => {
    try {
      const { category, search } = req.query;
      let products = await db.getProducts(category as string);

      if (search && typeof search === 'string') {
        const q = search.toLowerCase();
        products = products.filter(p =>
          p.name.toLowerCase().includes(q) ||
          p.description.toLowerCase().includes(q) ||
          p.tagline.toLowerCase().includes(q)
        );
      }

      res.json({ products, source: isSupabaseConfigured() ? 'supabase' : 'local' });
    } catch (err: any) {
      res.status(500).json({ error: err.message || 'Failed to fetch products' });
    }
  });

  app.get('/api/products/:id', async (req, res) => {
    try {
      const product = await db.getProductById(req.params.id);
      if (!product) {
        return res.status(404).json({ error: 'Biscuit not found babes!' });
      }
      res.json({ product, source: isSupabaseConfigured() ? 'supabase' : 'local' });
    } catch (err: any) {
      res.status(500).json({ error: err.message || 'Failed to fetch biscuit' });
    }
  });

  app.post('/api/products', async (req, res) => {
    try {
      const product = await db.addProduct(req.body);
      res.status(201).json({ product });
    } catch (err: any) {
      res.status(400).json({ error: err.message || 'Failed to add biscuit' });
    }
  });

  app.put('/api/products/:id', async (req, res) => {
    try {
      const updated = await db.updateProduct(req.params.id, req.body);
      if (!updated) {
        return res.status(404).json({ error: 'Biscuit not found' });
      }
      res.json({ product: updated });
    } catch (err: any) {
      res.status(400).json({ error: err.message || 'Failed to update biscuit' });
    }
  });

  app.delete('/api/products/:id', async (req, res) => {
    try {
      const success = await db.deleteProduct(req.params.id);
      if (!success) {
        return res.status(404).json({ error: 'Biscuit not found' });
      }
      res.json({ success: true });
    } catch (err: any) {
      res.status(400).json({ error: err.message || 'Failed to delete biscuit' });
    }
  });

  // Orders
  app.get('/api/orders', async (req, res) => {
    try {
      const orders = await db.getOrders();
      res.json({ orders, source: isSupabaseConfigured() ? 'supabase' : 'local' });
    } catch (err: any) {
      res.status(500).json({ error: err.message || 'Failed to fetch orders' });
    }
  });

  app.get('/api/orders/:orderId', async (req, res) => {
    try {
      const order = await db.getOrderById(req.params.orderId);
      if (!order) {
        return res.status(404).json({ error: 'Order not found! Double check your tracking code e.g. TBP-4892' });
      }
      res.json({ order, source: isSupabaseConfigured() ? 'supabase' : 'local' });
    } catch (err: any) {
      res.status(500).json({ error: err.message || 'Failed to fetch order' });
    }
  });

  app.post('/api/orders', async (req, res) => {
    try {
      const order = await db.createOrder(req.body);
      res.status(201).json({ order });
    } catch (err: any) {
      res.status(400).json({ error: err.message || 'Could not place your order babes' });
    }
  });

  app.patch('/api/orders/:orderId/status', async (req, res) => {
    try {
      const { status } = req.body;
      const order = await db.updateOrderStatus(req.params.orderId, status);
      if (!order) {
        return res.status(404).json({ error: 'Order not found' });
      }
      res.json({ order });
    } catch (err: any) {
      res.status(400).json({ error: err.message || 'Failed to update order status' });
    }
  });

  // Memes & Vibe Board
  app.get('/api/memes', async (req, res) => {
    try {
      const memes = await db.getMemes();
      res.json({ memes, source: isSupabaseConfigured() ? 'supabase' : 'local' });
    } catch (err: any) {
      res.status(500).json({ error: err.message || 'Failed to fetch memes' });
    }
  });

  app.post('/api/memes', async (req, res) => {
    try {
      const meme = await db.addMeme(req.body);
      res.status(201).json({ meme });
    } catch (err: any) {
      res.status(400).json({ error: err.message || 'Could not post meme' });
    }
  });

  app.post('/api/memes/:id/like', async (req, res) => {
    try {
      const meme = await db.likeMeme(req.params.id);
      if (!meme) {
        return res.status(404).json({ error: 'Meme not found' });
      }
      res.json({ meme });
    } catch (err: any) {
      res.status(400).json({ error: err.message || 'Failed to like meme' });
    }
  });

  // Baker Stats
  app.get('/api/stats', async (req, res) => {
    try {
      const stats = await db.getStats();
      res.json({ stats });
    } catch (err: any) {
      res.status(500).json({ error: err.message || 'Failed to fetch stats' });
    }
  });

  // Bakery Location Settings
  app.get('/api/settings', async (req, res) => {
    try {
      const settings = await db.getSettings();
      res.json({ settings, source: isSupabaseConfigured() ? 'supabase' : 'local' });
    } catch (err: any) {
      res.status(500).json({ error: err.message || 'Failed to fetch settings' });
    }
  });

  app.put('/api/settings', async (req, res) => {
    try {
      const settings = await db.updateSettings(req.body);
      res.json({ settings });
    } catch (err: any) {
      res.status(400).json({ error: err.message || 'Failed to update settings' });
    }
  });

  // Reset database
  app.post('/api/reset-db', (req, res) => {
    db.resetToDefaults();
    res.json({ success: true, message: 'Reset to default bakery goodies!' });
  });

  // AI Biscuit Slogan / Stamped Message / Vibe Generator
  app.post('/api/generate-biscuit-message', async (req, res) => {
    const { occasion, recipient, vibe } = req.body;

    const fallbackIdeas = [
      { message: 'DUMP HIM & EAT COOKIES', reason: 'Because carbs are loyal and won\'t leave you on delivered.' },
      { message: 'SLAY QUEEN HAPPY BIRTHDAY', reason: 'You are aging like fine vanilla extract.' },
      { message: 'CORPORATE BURNOUT CURE', reason: 'Per my last biscuit, I am clocking out early.' },
      { message: 'CERTIFIED LOVER GIRL', reason: '10/10 sweet tooth, zero bad vibes.' },
      { message: 'LOADSHEDDING SURVIVOR', reason: 'Stage 6 cannot melt this freshly baked energy.' },
      { message: 'YOU ARE LIKE REALLY PRETTY', reason: 'Mean Girls approved, butter-infused.' },
      { message: 'PROUD OF YOU BABES', reason: 'Celebrating your quiet wins with high sugar content.' }
    ];

    try {
      const ai = getGeminiClient();
      if (ai) {
        const prompt = `You are the sassy, warm, playful South African baker behind "The Biscuit Plug" - a trendy girly artisan bakery on Stanley Street in Richmond Hill, Port Elizabeth (Gqeberha), South Africa.
The user wants custom stamped cookie ideas for:
- Occasion: ${occasion || 'General treat / Just because'}
- Recipient: ${recipient || 'Bestie / Self'}
- Vibe: ${vibe || 'Sassy & meme-inspired'}

Generate 4 ultra-punchy, funny, girly biscuit stamp text ideas (under 28 characters each in all-caps) with a short 1-sentence hilarious explanation each. Incorporate relatable girl-energy, soft South African slang (like babes, yebo, bestie, lekker, no cap) where natural.
Return ONLY a valid JSON array of objects with keys "message" and "reason".`;

        const response = await ai.models.generateContent({
          model: 'gemini-2.5-flash',
          contents: prompt,
          config: {
            responseMimeType: 'application/json'
          }
        });

        if (response.text) {
          const parsed = JSON.parse(response.text);
          return res.json({ ideas: parsed });
        }
      }
    } catch (err) {
      console.warn('Gemini generation fallback used:', err);
    }

    // Return randomized selection of playful ideas
    res.json({ ideas: fallbackIdeas.slice(0, 4) });
  });

  // --- Vite Middleware for SPA ---
  if (process.env.NODE_ENV !== 'production') {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), 'dist');
    app.use(express.static(distPath));
    app.get('*', (req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`✨ The Biscuit Plug server running on http://0.0.0.0:${PORT}`);
  });
}

startServer();
