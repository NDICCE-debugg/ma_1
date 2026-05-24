-- ==========================================
-- SQL SEED SCRIPT FOR SUPABASE POSTGRESQL
-- Copy and paste this directly into your Supabase SQL Editor and click 'Run'.
-- ==========================================

-- 0. Ensure the suppliers table exists with proper schema
CREATE TABLE IF NOT EXISTS public.suppliers (
  id                    SERIAL PRIMARY KEY,
  name                  TEXT NOT NULL,
  physical_address      TEXT DEFAULT '',
  gps_location          TEXT DEFAULT '',
  phone                 TEXT DEFAULT '',
  email                 TEXT UNIQUE,
  average_lead_time_days INTEGER DEFAULT 0,
  notes                 TEXT DEFAULT '',
  created_at            TIMESTAMPTZ DEFAULT NOW()
);

-- Allow all authenticated users to READ suppliers (needed for the app)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'suppliers' AND policyname = 'Allow read for authenticated users'
  ) THEN
    EXECUTE 'ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY';
    EXECUTE $p$
      CREATE POLICY "Allow read for authenticated users"
        ON public.suppliers
        FOR SELECT
        TO authenticated
        USING (true)
    $p$;
  END IF;
END $$;

-- 1. Seed 'suppliers' Table (7 approved vendors — safe to re-run)
INSERT INTO public.suppliers (name, physical_address, gps_location, phone, email, average_lead_time_days, notes)
VALUES 
  ('Dräger Medical Zimbabwe',     '124 Samora Machel Ave, Harare, Zimbabwe',                          '-17.824858, 31.053028',   '+263 24 279 1234',   'support.zw@draeger.com',          5,  'Primary local supplier for all Draeger ICU ventilators and anaesthetic monitors.'),
  ('Aeonmed Co. Ltd',             'No. 9 Zone B, Airport Industrial Zone, Shunyi District, Beijing',  '40.068494, 116.598284',   '+86 10 8498 1122',   'service@aeonmed.com',            14,  'Direct manufacturer contact for Aeonmed VG series ventilator parts.'),
  ('Mindray Clinical Solutions',  'Mindray Building, Keji 12th Road South, Nanshan, Shenzhen, China', '22.538562, 113.947262',   '+86 755 8188 8999',  'service@mindray.com',            10,  'Manufacturer contact for Mindray A-series anaesthetic workstations.'),
  ('Harare Surgical & Diagnostics','88 Baines Avenue, Harare, Zimbabwe',                             '-17.821944, 31.051389',   '+263 24 270 4545',   'orders@hararesurgical.co.zw',     2,  'Local distributor for consumables, O2 sensors, sodalime canisters, and standard clinical fittings.'),
  ('Philips Healthcare Africa',   '3 Kikuyu Rd, Sunninghill, Johannesburg, South Africa',            '-26.046944, 28.070556',   '+27 11 471 4000',    'support.africa@philips.com',      7,  'Regional Philips distributor for patient monitoring systems, defibrillators, and imaging modules.'),
  ('GE Healthcare East Africa',   'Upperhill, Nairobi, Kenya',                                        '-1.288889, 36.823056',    '+254 20 374 5000',   'eastafrica@gehealthcare.com',     12,  'Regional contact for GE patient monitors, ultrasound units, and imaging accessories.'),
  ('Mediquip Zimbabwe (Pvt) Ltd', '16 Fife Avenue, Harare, Zimbabwe',                                '-17.830556, 31.052222',   '+263 24 276 6000',   'info@mediquip.co.zw',             3,  'Local distributor for general hospital consumables, suction equipment, and sterilisation supplies.')
ON CONFLICT (email) DO NOTHING;

-- 2. Seed 'machines' Table
INSERT INTO public.machines (model_name, serial_number, location, status)
VALUES
  ('Aeonmed VG70',       'SN-VG70-441', 'MAIN • ICU 1',          'Operational'),
  ('Aeonmed VG70',       'SN-VG70-442', 'MAIN • ICU 2',          'Needs Maintenance'),
  ('Dräger Evita V500',  'SN-DR-092',   'PAEDIATRIC • ICU 3',    'Operational'),
  ('Mindray A5',         'SN-MA5-998',  'MATERNITY • Theatre 1', 'Operational'),
  ('WATO EX-35',         'SN-W35-102',  'MAIN • Theatre 2',      'Needs Maintenance')
ON CONFLICT (serial_number) DO NOTHING;

-- 3. Seed 'spare_parts' Table
INSERT INTO public.spare_parts (name, compatible_model, quantity, reorder_threshold, location, unit, notes)
VALUES
  ('Turbine (210003677)',           'Aeonmed VG70', 0,  1, 'Shelf B2',      'pcs',   'Critical part. High replacement rate.'),
  ('Flow Sensor TSI (210002403)',   'Aeonmed VG70', 5,  3, 'Drawer A',      'pcs',   'Handle with care. Calibration required after install.'),
  ('O2 Sensor (210001975)',         'Aeonmed VG70', 3,  2, 'Fridge',        'pcs',   'Keep refrigerated between 2-8 degrees Celsius.'),
  ('Lithium-Ion Battery (210003734)','Aeonmed VG70',4,  2, 'Battery Store', 'units', 'Ensure fully charged prior to storage.'),
  ('Sodalime Canister',             'Mindray A5',  20,  5, 'Store Room',    'cans',  'CO2 absorbent consumable.')
ON CONFLICT DO NOTHING;

-- 4. Map 'part_suppliers' Many-to-Many Links
INSERT INTO public.part_suppliers (part_id, supplier_id)
VALUES
  ((SELECT id FROM public.spare_parts WHERE name = 'Turbine (210003677)' LIMIT 1),         (SELECT id FROM public.suppliers WHERE name = 'Aeonmed Co. Ltd' LIMIT 1)),
  ((SELECT id FROM public.spare_parts WHERE name = 'Flow Sensor TSI (210002403)' LIMIT 1), (SELECT id FROM public.suppliers WHERE name = 'Aeonmed Co. Ltd' LIMIT 1)),
  ((SELECT id FROM public.spare_parts WHERE name = 'Flow Sensor TSI (210002403)' LIMIT 1), (SELECT id FROM public.suppliers WHERE name = 'Harare Surgical & Diagnostics' LIMIT 1)),
  ((SELECT id FROM public.spare_parts WHERE name = 'O2 Sensor (210001975)' LIMIT 1),       (SELECT id FROM public.suppliers WHERE name = 'Dräger Medical Zimbabwe' LIMIT 1)),
  ((SELECT id FROM public.spare_parts WHERE name = 'O2 Sensor (210001975)' LIMIT 1),       (SELECT id FROM public.suppliers WHERE name = 'Harare Surgical & Diagnostics' LIMIT 1)),
  ((SELECT id FROM public.spare_parts WHERE name = 'Sodalime Canister' LIMIT 1),           (SELECT id FROM public.suppliers WHERE name = 'Mindray Clinical Solutions' LIMIT 1)),
  ((SELECT id FROM public.spare_parts WHERE name = 'Sodalime Canister' LIMIT 1),           (SELECT id FROM public.suppliers WHERE name = 'Harare Surgical & Diagnostics' LIMIT 1))
ON CONFLICT (part_id, supplier_id) DO NOTHING;

-- 5. Ensure communication tables support real on-call contacts
CREATE TABLE IF NOT EXISTS public.users (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  email       TEXT UNIQUE,
  reg_number  TEXT UNIQUE,
  role        TEXT DEFAULT 'Technician',
  phone       TEXT DEFAULT '',
  online      BOOLEAN DEFAULT false,
  last_seen   TIMESTAMPTZ DEFAULT NOW(),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'Technician';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS online BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ DEFAULT NOW();

CREATE TABLE IF NOT EXISTS public.conversations (
  id                 TEXT PRIMARY KEY,
  group_name         TEXT,
  last_message       TEXT DEFAULT '',
  last_message_time  TIMESTAMPTZ DEFAULT NOW(),
  is_group           BOOLEAN DEFAULT false,
  created_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.messages (
  id               BIGSERIAL PRIMARY KEY,
  conversation_id  TEXT REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id        TEXT,
  message_text     TEXT NOT NULL,
  message_type     TEXT DEFAULT 'text',
  timestamp        TIMESTAMPTZ DEFAULT NOW()
);

DO $$ BEGIN
  EXECUTE 'ALTER TABLE public.users ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY';
  EXECUTE 'ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY';
EXCEPTION WHEN others THEN
  NULL;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'Allow read users for authenticated users'
  ) THEN
    CREATE POLICY "Allow read users for authenticated users"
      ON public.users FOR SELECT TO authenticated USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'conversations' AND policyname = 'Allow read conversations for authenticated users'
  ) THEN
    CREATE POLICY "Allow read conversations for authenticated users"
      ON public.conversations FOR SELECT TO authenticated USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'messages' AND policyname = 'Allow read messages for authenticated users'
  ) THEN
    CREATE POLICY "Allow read messages for authenticated users"
      ON public.messages FOR SELECT TO authenticated USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'messages' AND policyname = 'Allow insert messages for authenticated users'
  ) THEN
    CREATE POLICY "Allow insert messages for authenticated users"
      ON public.messages FOR INSERT TO authenticated WITH CHECK (true);
  END IF;
END $$;

INSERT INTO public.users (id, name, email, reg_number, role, phone, online, last_seen)
VALUES
  ('dr-chipo-moyo',    'Dr. Chipo Moyo',    'chipo.moyo@parirenyatwa.co.zw',     'CONSULT-ICU', 'ICU Consultant',            '+263772123456', true,  NOW()),
  ('farai-gumbo',     'Farai Gumbo',        'farai.gumbo@parirenyatwa.co.zw',    'TECH-VENT',   'Ventilator Technician',     '+263773456789', true, NOW()),
  ('tendai-chidi',    'Tendai Chidi',       'tendai.chidi@parirenyatwa.co.zw',   'PLANT-OXY',   'Medical Gas Technician',    '+263774567890', true,  NOW()),
  ('dr-sekai-nzenza', 'Dr. Sekai Nzenza',   'sekai.nzenza@parirenyatwa.co.zw',   'CMO-ADMIN',   'Chief Medical Officer',     '+263771987654', true,  NOW()),
  ('rufaro-moyo',     'Rufaro Moyo',        'rufaro.moyo@parirenyatwa.co.zw',    'BIOMED-HEAD', 'Biomedical Department Head', '+263782345678', true,  NOW()),
  ('kudakwashe-hove', 'Kudakwashe Hove',    'kudakwashe.hove@parirenyatwa.co.zw','LAB-SPECIAL', 'Senior Laboratory Specialist','+263715678901', true,  NOW())
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  email = EXCLUDED.email,
  reg_number = EXCLUDED.reg_number,
  role = EXCLUDED.role,
  phone = EXCLUDED.phone,
  online = EXCLUDED.online,
  last_seen = EXCLUDED.last_seen;

INSERT INTO public.conversations (id, group_name, last_message, last_message_time, is_group)
VALUES
  ('dr-chipo-moyo', 'Dr. Chipo Moyo', 'Urgent: ICU Aeonmed VG70 has a constant Low O2 Pressure fault alarm.', NOW() - INTERVAL '11 minutes', false),
  ('farai-gumbo', 'Farai Gumbo', 'Evita V500 PEEP valve calibration test complete. Ready to redeploy.', NOW() - INTERVAL '3 hours', false),
  ('tendai-chidi', 'Tendai Chidi', 'Central oxygen plant manifold pressure is dropping below 4.2 bar.', NOW() - INTERVAL '5 hours', false),
  ('dr-sekai-nzenza', 'Dr. Sekai Nzenza', 'BMET Team, please prepare the technical audit report for the ICU fleet.', NOW() - INTERVAL '8 hours', false),
  ('rufaro-moyo', 'Rufaro Moyo', 'Regarding the spare parts inventory: do we have the turbine replacements?', NOW() - INTERVAL '12 hours', false),
  ('kudakwashe-hove', 'Kudakwashe Hove', 'The blood gas analyzer in ICU lab is drifting on pH calibration.', NOW() - INTERVAL '18 hours', false)
ON CONFLICT (id) DO UPDATE SET
  group_name = EXCLUDED.group_name,
  last_message = EXCLUDED.last_message,
  last_message_time = EXCLUDED.last_message_time,
  is_group = EXCLUDED.is_group;

INSERT INTO public.messages (conversation_id, sender_id, message_text, message_type, timestamp)
SELECT 'dr-chipo-moyo', 'dr-chipo-moyo', 'ICU has an Aeonmed VG70 showing persistent Low O2 Pressure. Please confirm whether we isolate or attempt calibration first.', 'text', NOW() - INTERVAL '18 minutes'
WHERE NOT EXISTS (
  SELECT 1 FROM public.messages WHERE conversation_id = 'dr-chipo-moyo' AND sender_id = 'dr-chipo-moyo'
);

INSERT INTO public.messages (conversation_id, sender_id, message_text, message_type, timestamp)
SELECT 'farai-gumbo', 'farai-gumbo', 'PEEP valve calibration passed on the Evita V500. I can stay available by phone if the alarm returns.', 'text', NOW() - INTERVAL '1 day 2 hours'
WHERE NOT EXISTS (
  SELECT 1 FROM public.messages WHERE conversation_id = 'farai-gumbo' AND sender_id = 'farai-gumbo'
);

INSERT INTO public.messages (conversation_id, sender_id, message_text, message_type, timestamp)
SELECT 'tendai-chidi', 'tendai-chidi', 'Oxygen manifold pressure is unstable. Reserve cylinders are online while I inspect the regulator bank.', 'text', NOW() - INTERVAL '1 day 7 hours'
WHERE NOT EXISTS (
  SELECT 1 FROM public.messages WHERE conversation_id = 'tendai-chidi' AND sender_id = 'tendai-chidi'
);

INSERT INTO public.messages (conversation_id, sender_id, message_text, message_type, timestamp)
SELECT 'dr-sekai-nzenza', 'dr-sekai-nzenza', 'BMET Team, please prepare the technical audit report for the ICU ventilator fleet before the clinical safety review this afternoon.', 'text', NOW() - INTERVAL '8 hours'
WHERE NOT EXISTS (
  SELECT 1 FROM public.messages WHERE conversation_id = 'dr-sekai-nzenza' AND sender_id = 'dr-sekai-nzenza'
);

INSERT INTO public.messages (conversation_id, sender_id, message_text, message_type, timestamp)
SELECT 'rufaro-moyo', 'rufaro-moyo', 'Regarding the spare parts inventory: do we have the turbine replacements restocked on Shelf B2? I am drafting the procurement invoice.', 'text', NOW() - INTERVAL '12 hours'
WHERE NOT EXISTS (
  SELECT 1 FROM public.messages WHERE conversation_id = 'rufaro-moyo' AND sender_id = 'rufaro-moyo'
);

INSERT INTO public.messages (conversation_id, sender_id, message_text, message_type, timestamp)
SELECT 'kudakwashe-hove', 'kudakwashe-hove', 'The blood gas analyzer in ICU lab is drifting on pH calibration. Can you bring the reference buffers for a verification test?', 'text', NOW() - INTERVAL '18 hours'
WHERE NOT EXISTS (
  SELECT 1 FROM public.messages WHERE conversation_id = 'kudakwashe-hove' AND sender_id = 'kudakwashe-hove'
);

-- 6. Seed 'service_logs' Table
INSERT INTO public.service_logs (machine_id, error_code, notes)
VALUES
  ((SELECT id FROM public.machines WHERE serial_number = 'SN-VG70-442' LIMIT 1), 'ERR-TURB-09',  'O2 turbine depletion alert triggered. Ordered replacement turbine from Aeonmed Co. Ltd.'),
  ((SELECT id FROM public.machines WHERE serial_number = 'SN-W35-102'  LIMIT 1), 'ERR-VALVE-02', 'Inspiratory valve leakage detected during routine checkout. Placed offline, local parts requested.');
