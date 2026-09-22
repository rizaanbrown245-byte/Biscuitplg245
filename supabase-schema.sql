-- ====================================================================
-- The Biscuit Plug - Complete Supabase Database Schema
-- Run this script in your Supabase SQL Editor (SQL Editor -> New Query)
-- ====================================================================

-- 1. PRODUCTS TABLE (Catalog, inventory, stock counts & custom options)
CREATE TABLE IF NOT EXISTS products (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  tagline TEXT,
  description TEXT,
  price NUMERIC NOT NULL,
  original_price NUMERIC,
  image TEXT NOT NULL,
  category TEXT NOT NULL,
  dietary JSONB DEFAULT '[]'::jsonb,
  meme_badge TEXT,
  badge_color TEXT,
  in_stock BOOLEAN DEFAULT true,
  stock_count INTEGER DEFAULT 20,
  weight_grams INTEGER DEFAULT 160,
  is_customizable BOOLEAN DEFAULT false,
  custom_placeholder TEXT,
  rating NUMERIC DEFAULT 4.9,
  review_count INTEGER DEFAULT 10,
  ingredients_snippet TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. ORDERS TABLE (Customer details, delivery info, items JSON & statuses)
CREATE TABLE IF NOT EXISTS orders (
  id TEXT PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  customer JSONB NOT NULL,
  delivery JSONB NOT NULL,
  items JSONB NOT NULL,
  subtotal NUMERIC NOT NULL,
  discount NUMERIC DEFAULT 0,
  delivery_fee NUMERIC DEFAULT 0,
  total NUMERIC NOT NULL,
  promo_code TEXT,
  payment_method TEXT NOT NULL,
  payment_status TEXT DEFAULT 'pending',
  status TEXT DEFAULT 'received',
  status_updated TIMESTAMPTZ DEFAULT NOW()
);

-- 3. MEMES / VIBE BOARD TABLE (Community mood board & recommendations)
CREATE TABLE IF NOT EXISTS memes (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  caption TEXT NOT NULL,
  image TEXT NOT NULL,
  likes INTEGER DEFAULT 0,
  author TEXT DEFAULT 'Anonymous Cookie Fiend',
  tag TEXT DEFAULT 'General Mood',
  vibe_cookie_recommendation TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. BAKERY SETTINGS TABLE (HQ address, pickup hours, delivery zones & contact)
CREATE TABLE IF NOT EXISTS bakery_settings (
  id TEXT PRIMARY KEY DEFAULT 'default',
  kitchen_name TEXT NOT NULL DEFAULT 'The Biscuit Plug - Gqeberha Kitchen',
  address TEXT NOT NULL DEFAULT '9th Avenue, Walmer',
  suburb TEXT NOT NULL DEFAULT 'Walmer',
  city TEXT NOT NULL DEFAULT 'Gqeberha',
  province TEXT NOT NULL DEFAULT 'Eastern Cape',
  postal_code TEXT NOT NULL DEFAULT '6070',
  pickup_hours TEXT NOT NULL DEFAULT 'Mon - Sat: 10:00 - 16:00',
  pickup_instructions TEXT NOT NULL DEFAULT 'Collection from our bakery kitchen in Walmer, Gqeberha. Buzzer at gate, warm cookies handed straight to you!',
  local_delivery_zone_name TEXT NOT NULL DEFAULT 'Gqeberha Door Courier (Nelson Mandela Bay)',
  local_delivery_coverage TEXT NOT NULL DEFAULT 'Walmer, Summerstrand, Mill Park, Newton Park & Gqeberha surrounds (1-2 days)',
  local_delivery_fee NUMERIC NOT NULL DEFAULT 70,
  pudo_locker_location_default TEXT NOT NULL DEFAULT 'Engen 10th Ave Walmer Locker, Gqeberha',
  phone TEXT NOT NULL DEFAULT '+27 82 894 2011',
  whatsapp_number TEXT NOT NULL DEFAULT '27828942011',
  nationwide_coming_soon BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. ENABLE ROW LEVEL SECURITY (RLS)
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE memes ENABLE ROW LEVEL SECURITY;
ALTER TABLE bakery_settings ENABLE ROW LEVEL SECURITY;

-- 6. POLICIES: Clean, idempotent setup for read, insert, and update operations
DO $$
BEGIN
  -- Products policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'products' AND policyname = 'Public products are viewable by everyone') THEN
    CREATE POLICY "Public products are viewable by everyone" ON products FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'products' AND policyname = 'Admins can manage products') THEN
    CREATE POLICY "Admins can manage products" ON products FOR ALL USING (true);
  END IF;

  -- Memes policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'memes' AND policyname = 'Public memes are viewable by everyone') THEN
    CREATE POLICY "Public memes are viewable by everyone" ON memes FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'memes' AND policyname = 'Anyone can post memes or like') THEN
    CREATE POLICY "Anyone can post memes or like" ON memes FOR ALL USING (true);
  END IF;

  -- Orders policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'orders' AND policyname = 'Anyone can place an order') THEN
    CREATE POLICY "Anyone can place an order" ON orders FOR INSERT WITH CHECK (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'orders' AND policyname = 'Orders viewable by id or admin') THEN
    CREATE POLICY "Orders viewable by id or admin" ON orders FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'orders' AND policyname = 'Orders updatable by admin') THEN
    CREATE POLICY "Orders updatable by admin" ON orders FOR UPDATE USING (true);
  END IF;

  -- Bakery settings policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'bakery_settings' AND policyname = 'Bakery settings viewable by everyone') THEN
    CREATE POLICY "Bakery settings viewable by everyone" ON bakery_settings FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'bakery_settings' AND policyname = 'Bakery settings updatable by admin') THEN
    CREATE POLICY "Bakery settings updatable by admin" ON bakery_settings FOR ALL USING (true);
  END IF;
END $$;

-- 7. INITIAL SEED: Bakery default settings
INSERT INTO bakery_settings (
  id, kitchen_name, address, suburb, city, province, postal_code,
  pickup_hours, pickup_instructions, local_delivery_zone_name,
  local_delivery_coverage, local_delivery_fee, pudo_locker_location_default,
  phone, whatsapp_number, nationwide_coming_soon
) VALUES (
  'default',
  'The Biscuit Plug - Gqeberha Kitchen',
  '9th Avenue, Walmer',
  'Walmer',
  'Gqeberha',
  'Eastern Cape',
  '6070',
  'Mon - Sat: 10:00 - 16:00',
  'Collection from our bakery kitchen in Walmer, Gqeberha. Buzzer at gate, warm cookies handed straight to you!',
  'Gqeberha Door Courier (Nelson Mandela Bay)',
  'Walmer, Summerstrand, Mill Park, Newton Park & Gqeberha surrounds (1-2 days)',
  70,
  'Engen 10th Ave Walmer Locker, Gqeberha',
  '+27 82 894 2011',
  '27828942011',
  true
) ON CONFLICT (id) DO NOTHING;

-- 8. INITIAL SEED: Default biscuit catalog from server/db.ts
INSERT INTO products (
  id, name, tagline, description, price, original_price, image,
  category, dietary, meme_badge, badge_color, in_stock, stock_count,
  weight_grams, is_customizable, custom_placeholder, rating, review_count,
  ingredients_snippet
) VALUES
(
  'nyc-choc-chip',
  'Classic NYC Thicc Choc Chip',
  '160g of pure serotonin, gooey center with 70% dark Belgian chocolate',
  'Our viral signature cookie. Golden, crisp exterior with a warm molten center packed with double Belgian chocolate chunks and sprinkled with Maldon sea salt flakes. Heat for 15s in the microwave and prepare to see God.',
  45, NULL,
  'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?auto=format&fit=crop&w=800&q=80',
  'stuffed-cookies', '["Halal Friendly", "Vegetarian"]'::jsonb,
  'Emotional Support Cookie', '#ec4899', true, 28, 160, false, NULL, 4.9, 142,
  'Stone-ground flour, pasture butter, Belgian 70% chocolate, brown sugar, organic eggs, Maldon salt'
),
(
  'biscoff-lava-bomb',
  'Lotus Biscoff Molten Cookie',
  'Stuffed with molten Biscoff spread and topped with caramelized lotus crumb',
  'She is that girl. Rich spiced brown butter cookie dough injected with a generous tablespoon of creamy Biscoff spread, crowned with a crunchy Speculoos biscuit. Zero regrets, 100% main character energy.',
  52, NULL,
  'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?auto=format&fit=crop&w=800&q=80',
  'stuffed-cookies', '["Halal Friendly", "Vegetarian"]'::jsonb,
  'Main Character Energy', '#f59e0b', true, 19, 170, false, NULL, 5.0, 98,
  'Flour, butter, genuine Lotus Biscoff speculoos cream, white chocolate, brown sugar, cinnamon'
),
(
  'melktert-biscuit-pocket',
  'Mzansi Melktert Cream Pocket',
  'Traditional cinnamon-dusted custard folded inside a crisp shortbread crust',
  'An Eastern Cape love letter! Flaky buttery shortcrust holding a silky, thick South African milk tart custard center, finished with a heavy blanket of spiced cinnamon. Nostalgia in every single bite.',
  48, NULL,
  'https://images.unsplash.com/photo-1590080875515-8a3a8dc5735e?auto=format&fit=crop&w=800&q=80',
  'mzansi-heritage', '["Halal Friendly", "Traditional"]'::jsonb,
  'Ouma Approved 🇿🇦', '#065f46', true, 22, 150, false, NULL, 4.8, 76,
  'Real milk, butter, farm cream, cinnamon quills, organic egg yolks, vanilla bean pod, flour'
),
(
  'peppermint-crisp-tart-cookie',
  'Peppermint Crisp Tart Stuffed Monster',
  'Caramel treat, crushed Tennis biscuits & mint cracknel chocolate core',
  'We took South Africa''s favorite dessert and baked it into a giant cookie. Golden dough infused with Bakers Tennis biscuit crumb, stuffed with caramelized condensed milk and genuine Nestlé Peppermint Crisp chocolate shards.',
  55, NULL,
  'https://images.unsplash.com/photo-1587314168485-3236d6710814?auto=format&fit=crop&w=800&q=80',
  'mzansi-heritage', '["Halal Friendly", "South African Classic"]'::jsonb,
  'Heritage King', '#059669', true, 15, 175, false, NULL, 5.0, 114,
  'Caramel Treat, Nestlé Peppermint Crisp, coconut Tennis biscuits, butter, golden syrup, cream'
),
(
  'nutella-sinner-drop',
  'The Nutella Sinner XXL',
  'Warm oozy hazelnut core with roasted crushed hazelnuts on top',
  'A crime not to order this. Thick chocolate dough wrapped around a frozen ball of Nutella that melts into lava when heated. Dangerously addictive.',
  49, NULL,
  'https://images.unsplash.com/photo-1618923834413-2770b904ee10?auto=format&fit=crop&w=800&q=80',
  'stuffed-cookies', '["Halal Friendly", "Contains Nuts"]'::jsonb,
  'Therapy in a Box', '#831843', true, 8, 165, false, NULL, 4.9, 87,
  'Nutella hazelnut spread, roasted Piedmont hazelnuts, Valrhona cocoa, unsalted butter'
),
(
  'custom-sassy-stamped',
  'Personalized Sassy Stamped Biscuits (Box of 4)',
  'Say it with butter! Custom cheeky message embossed in pastel glaze',
  'Need to apologize? Break up? Congratulate your bestie? Propose? Stamp whatever is on your heart (max 24 characters). Comes in our signature retro pink window box with ribbon.',
  140, 160,
  'https://images.unsplash.com/photo-1548848221-0c2e497ed557?auto=format&fit=crop&w=800&q=80',
  'custom-message', '["Custom Stamped", "Halal Friendly"]'::jsonb,
  'Custom Stamped 💌', '#db2777', true, 30, 240, true, 'e.g. DUMP HIM / BESTIE VIBES / SLAY QUEEN', 5.0, 210,
  'Vanilla shortbread, royal icing, French vanilla bean, powdered sugar, edible gold dust'
),
(
  'the-richmond-hill-bundle',
  'The Richmond Hill 6-Pack Box',
  'Curated box of our top 6 bestsellers in our signature gift crate',
  'Cannot choose? Get the full Port Elizabeth experience. Includes: 2x NYC Thicc Choc, 1x Biscoff Bomb, 1x Peppermint Crisp Monster, 1x Melktert Pocket & 1x Nutella Sinner. Comes with a reheating guide card.',
  275, 300,
  'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=800&q=80',
  'bundles', '["Crowd Pleaser", "Bestseller"]'::jsonb,
  'Save R25 Today', '#dc2626', true, 12, 980, false, NULL, 5.0, 320,
  'Assortment of all fresh cookie ingredients - sealed airtight for 7 days fresh guarantee'
),
(
  'fudge-brownie-slab',
  'Gooey Valrhona Espresso Brownie Slab',
  'Fudgy, dense espresso-infused dark brownie with crinkle papery top',
  'Intensely dark, crackly crust with a fudge-like center that sticks to your fork. Baked with double-shot Karoo espresso and 70% dark cocoa.',
  42, NULL,
  'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?auto=format&fit=crop&w=800&q=80',
  'brownies', '["Halal Friendly", "Intense Dark Choc"]'::jsonb,
  'Dark & Moody', '#3b0764', true, 16, 140, false, NULL, 4.7, 54,
  'Valrhona cocoa, espresso shot, dark brown sugar, butter, semi-sweet chocolate drops'
)
ON CONFLICT (id) DO NOTHING;

-- 9. INITIAL SEED: Default memes for the Vibe Board
INSERT INTO memes (
  id, title, caption, image, likes, author, tag, vibe_cookie_recommendation
) VALUES
(
  'meme-1',
  'When the diet starts tomorrow',
  'Me explaining to my bank account why 4 stuffed Biscoff cookies at 11 PM are essential medical supplies.',
  'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?auto=format&fit=crop&w=800&q=80',
  342,
  'Lerato in Summerstrand',
  'Midnight Craving',
  'biscoff-lava-bomb'
),
(
  'meme-2',
  'Adulting is a scam',
  'I came, I saw, I had a mental breakdown, then I microwaved an NYC chocolate chip cookie for 15 seconds.',
  'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=800&q=80',
  519,
  'Anja in Walmer',
  'Corporate Burnout',
  'nyc-choc-chip'
),
(
  'meme-3',
  'Stage 6 Loadshedding survival guide',
  'No lights? No problem. Cold milk and 3 Peppermint Crisp monsters in the dark hit completely different.',
  'https://images.unsplash.com/photo-1574158622682-e40e69881006?auto=format&fit=crop&w=800&q=80',
  627,
  'Sipho from PE',
  'Mzansi Mood',
  'peppermint-crisp-tart-cookie'
)
ON CONFLICT (id) DO NOTHING;
