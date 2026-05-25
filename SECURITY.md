# Pulse Security Notes

## Secret Handling

- Never hardcode `GEMINI_API_KEY`, service account private keys, webhooks, or service-role keys in Flutter, Dart, JavaScript, Android resources, or checked-in source files.
- Gemini calls must go through the Flask backend. The backend reads `GEMINI_API_KEY` from `backend/.env`.
- `backend/.env` is intentionally ignored by git. Use `backend/.env.example` as the template.
- Supabase publishable/anon keys can appear in clients, but they must be protected by Row Level Security policies.
- Supabase service-role keys must be backend-only and must never be sent to Flutter.

## Key Rotation After Exposure

If Google reports a key as leaked:

1. Revoke the exposed key in Google AI Studio or Google Cloud.
2. Create a new key with the minimum required APIs enabled.
3. Restrict the key where possible.
4. Put it only in `backend/.env`.
5. Restart the backend process.

## Deployment Rules

- Deploy the backend over HTTPS.
- Keep CORS restricted to the production Pulse origin.
- Keep Supabase RLS enabled for application tables and Storage.
- Store manuals in the private `manuals` Storage bucket.
- Do not commit build outputs, `.env` files, or generated Python caches.
