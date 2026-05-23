-- ==========================================
-- SQL SEED SCRIPT FOR SUPABASE POSTGRESQL
-- Copy and paste this directly into your Supabase SQL Editor and click 'Run'.
-- ==========================================

-- 1. Seed 'suppliers' Table
INSERT INTO public.suppliers (name, physical_address, gps_location, phone, email, average_lead_time_days, notes)
VALUES 
('Dräger Medical Zimbabwe', '124 Samora Machel Ave, Harare, Zimbabwe', '-17.824858, 31.053028', '+263 24 279 1234', 'support.zw@draeger.com', 5, 'Primary local supplier for all Draeger ICU ventilators and anaesthetic monitors.'),
('Aeonmed Co. Ltd', 'No. 9 Zone B, Airport Industrial Zone, Shunyi District, Beijing, China', '40.068494, 116.598284', '+86 10 8498 1122', 'service@aeonmed.com', 14, 'Direct manufacturer contact for Aeonmed VG series parts.'),
('Mindray Clinical Solutions', 'Mindray Building, Keji 12th Road South, High-Tech Industrial Park, Nanshan, Shenzhen, China', '22.538562, 113.947262', '+86 755 8188 8999', 'service@mindray.com', 10, 'Manufacturer contact for Mindray A-series workstations.'),
('Harare Surgical & Diagnostics', '88 Baines Avenue, Harare, Zimbabwe', '-17.821944, 31.051389', '+263 24 270 4545', 'orders@hararesurgical.co.zw', 2, 'Local distributor for consumables, O2 sensors, sodalime canisters, and standard clinical fittings.')
ON CONFLICT (email) DO NOTHING;

-- 2. Seed 'machines' Table
INSERT INTO public.machines (model_name, serial_number, location, status)
VALUES
('Aeonmed VG70', 'SN-VG70-441', 'MAIN • ICU 1', 'Operational'),
('Aeonmed VG70', 'SN-VG70-442', 'MAIN • ICU 2', 'Needs Maintenance'),
('Dräger Evita V500', 'SN-DR-092', 'PAEDIATRIC • ICU 3', 'Operational'),
('Mindray A5', 'SN-MA5-998', 'MATERNITY • Theatre 1', 'Operational'),
('WATO EX-35', 'SN-W35-102', 'MAIN • Theatre 2', 'Needs Maintenance')
ON CONFLICT (serial_number) DO NOTHING;

-- 3. Seed 'spare_parts' Table
INSERT INTO public.spare_parts (name, compatible_model, quantity, reorder_threshold, location, unit, notes)
VALUES
('Turbine (210003677)', 'Aeonmed VG70', 0, 1, 'Shelf B2', 'pcs', 'Critical part. High replacement rate.'),
('Flow Sensor TSI (210002403)', 'Aeonmed VG70', 5, 3, 'Drawer A', 'pcs', 'Handle with care. Calibration required after install.'),
('O2 Sensor (210001975)', 'Aeonmed VG70', 3, 2, 'Fridge', 'pcs', 'Keep refrigerated between 2-8 degrees Celsius.'),
('Lithium-Ion Battery (210003734)', 'Aeonmed VG70', 4, 2, 'Battery Store', 'units', 'Ensure fully charged prior to storage.'),
('Sodalime Canister', 'Mindray A5', 20, 5, 'Store Room', 'cans', 'CO2 absorbent consumable.');

-- 4. Map 'part_suppliers' Many-to-Many Links
-- We query the newly generated IDs dynamically using sub-selects
INSERT INTO public.part_suppliers (part_id, supplier_id)
VALUES
((SELECT id FROM public.spare_parts WHERE name = 'Turbine (210003677)' LIMIT 1), (SELECT id FROM public.suppliers WHERE name = 'Aeonmed Co. Ltd' LIMIT 1)),
((SELECT id FROM public.spare_parts WHERE name = 'Flow Sensor TSI (210002403)' LIMIT 1), (SELECT id FROM public.suppliers WHERE name = 'Aeonmed Co. Ltd' LIMIT 1)),
((SELECT id FROM public.spare_parts WHERE name = 'Flow Sensor TSI (210002403)' LIMIT 1), (SELECT id FROM public.suppliers WHERE name = 'Harare Surgical & Diagnostics' LIMIT 1)),
((SELECT id FROM public.spare_parts WHERE name = 'O2 Sensor (210001975)' LIMIT 1), (SELECT id FROM public.suppliers WHERE name = 'Dräger Medical Zimbabwe' LIMIT 1)),
((SELECT id FROM public.spare_parts WHERE name = 'O2 Sensor (210001975)' LIMIT 1), (SELECT id FROM public.suppliers WHERE name = 'Harare Surgical & Diagnostics' LIMIT 1)),
((SELECT id FROM public.spare_parts WHERE name = 'Sodalime Canister' LIMIT 1), (SELECT id FROM public.suppliers WHERE name = 'Mindray Clinical Solutions' LIMIT 1)),
((SELECT id FROM public.spare_parts WHERE name = 'Sodalime Canister' LIMIT 1), (SELECT id FROM public.suppliers WHERE name = 'Harare Surgical & Diagnostics' LIMIT 1))
ON CONFLICT (part_id, supplier_id) DO NOTHING;

-- 5. Seed 'service_logs' Table
-- We fetch machine IDs dynamically
INSERT INTO public.service_logs (machine_id, error_code, notes)
VALUES
((SELECT id FROM public.machines WHERE serial_number = 'SN-VG70-442' LIMIT 1), 'ERR-TURB-09', 'O2 turbine depletion alert triggered. Ordered replacement turbine from Aeonmed Co. Ltd.'),
((SELECT id FROM public.machines WHERE serial_number = 'SN-W35-102' LIMIT 1), 'ERR-VALVE-02', 'Inspiratory valve leakage detected during routine checkout. Placed offline, local parts requested.');
