"""
Supabase Supplier Seeder
Run with: py backend/seed_suppliers.py
Seeds the public.suppliers table with clinical device vendors.
"""
import sys
import requests
sys.stdout.reconfigure(encoding='utf-8')

SUPABASE_URL = "https://awswkatcjffcsobusvic.supabase.co"
SUPABASE_KEY = "sb_publishable_JS_DyaON4AC8FoJMcEkOwg_6aYjl6d2"

headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates",
}

SUPPLIERS = [
    {
        "name": "Dräger Medical Zimbabwe",
        "physical_address": "124 Samora Machel Ave, Harare, Zimbabwe",
        "gps_location": "-17.824858, 31.053028",
        "phone": "+263 24 279 1234",
        "email": "support.zw@draeger.com",
        "average_lead_time_days": 5,
        "notes": "Primary local supplier for all Draeger ICU ventilators and anaesthetic monitors.",
    },
    {
        "name": "Aeonmed Co. Ltd",
        "physical_address": "No. 9 Zone B, Airport Industrial Zone, Shunyi District, Beijing, China",
        "gps_location": "40.068494, 116.598284",
        "phone": "+86 10 8498 1122",
        "email": "service@aeonmed.com",
        "average_lead_time_days": 14,
        "notes": "Direct manufacturer contact for Aeonmed VG series ventilator parts.",
    },
    {
        "name": "Mindray Clinical Solutions",
        "physical_address": "Mindray Building, Keji 12th Road South, High-Tech Industrial Park, Nanshan, Shenzhen, China",
        "gps_location": "22.538562, 113.947262",
        "phone": "+86 755 8188 8999",
        "email": "service@mindray.com",
        "average_lead_time_days": 10,
        "notes": "Manufacturer contact for Mindray A-series anaesthetic workstations.",
    },
    {
        "name": "Harare Surgical & Diagnostics",
        "physical_address": "88 Baines Avenue, Harare, Zimbabwe",
        "gps_location": "-17.821944, 31.051389",
        "phone": "+263 24 270 4545",
        "email": "orders@hararesurgical.co.zw",
        "average_lead_time_days": 2,
        "notes": "Local distributor for consumables, O2 sensors, sodalime canisters, and standard clinical fittings.",
    },
    {
        "name": "Philips Healthcare Africa",
        "physical_address": "3 Kikuyu Rd, Sunninghill, Johannesburg, South Africa",
        "gps_location": "-26.046944, 28.070556",
        "phone": "+27 11 471 4000",
        "email": "support.africa@philips.com",
        "average_lead_time_days": 7,
        "notes": "Regional Philips distributor for patient monitoring systems, defibrillators, and imaging modules.",
    },
    {
        "name": "GE Healthcare East Africa",
        "physical_address": "Upperhill, Nairobi, Kenya",
        "gps_location": "-1.288889, 36.823056",
        "phone": "+254 20 374 5000",
        "email": "eastafrica@gehealthcare.com",
        "average_lead_time_days": 12,
        "notes": "Regional contact for GE patient monitors, ultrasound units, and imaging accessories.",
    },
    {
        "name": "Mediquip Zimbabwe (Pvt) Ltd",
        "physical_address": "16 Fife Avenue, Harare, Zimbabwe",
        "gps_location": "-17.830556, 31.052222",
        "phone": "+263 24 276 6000",
        "email": "info@mediquip.co.zw",
        "average_lead_time_days": 3,
        "notes": "Local distributor for general hospital consumables, suction equipment, and sterilisation supplies.",
    },
]

def seed():
    print("=" * 55)
    print("  Supabase Supplier Seeder — Pulse")
    print("=" * 55)
    url = f"{SUPABASE_URL}/rest/v1/suppliers"

    success = 0
    for s in SUPPLIERS:
        try:
            res = requests.post(url, headers=headers, json=s, timeout=10)
            if res.status_code in (200, 201):
                print(f"  [OK]  {s['name']}")
                success += 1
            elif res.status_code == 409:
                print(f"  [~~]  {s['name']} (already exists)")
                success += 1
            else:
                print(f"  [ERR] {s['name']}: {res.status_code} - {res.text[:120]}")
        except Exception as e:
            print(f"  [ERR] {s['name']}: Network error - {e}")

    print("=" * 55)
    print(f"  Done. {success}/{len(SUPPLIERS)} suppliers seeded.")
    print("=" * 55)

if __name__ == "__main__":
    seed()
