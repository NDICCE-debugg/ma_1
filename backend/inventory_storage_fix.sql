-- Pulse inventory image support.
-- Run in Supabase SQL Editor before using image-backed spare parts.

alter table public.spare_parts
  add column if not exists image_file_name text default '';

alter table public.machines
  add column if not exists asset_type text default '',
  add column if not exists hospital_unit text default '',
  add column if not exists ward_location text default '',
  add column if not exists date_acquired text default '',
  add column if not exists last_service_date text default '',
  add column if not exists service_interval text default '',
  add column if not exists notes text default '',
  add column if not exists image_file_name text default '';

alter table public.spare_parts enable row level security;
alter table public.machines enable row level security;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'inventory-images',
  'inventory-images',
  false,
  10485760,
  array['image/png', 'image/jpeg', 'image/webp', 'image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "inventory images authenticated upload own folder" on storage.objects;
create policy "inventory images authenticated upload own folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'inventory-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "inventory images authenticated read own folder" on storage.objects;
create policy "inventory images authenticated read own folder"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'inventory-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "inventory images authenticated update own folder" on storage.objects;
create policy "inventory images authenticated update own folder"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'inventory-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'inventory-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "spare parts authenticated read" on public.spare_parts;
create policy "spare parts authenticated read"
  on public.spare_parts for select
  to authenticated
  using (true);

drop policy if exists "spare parts authenticated insert" on public.spare_parts;
create policy "spare parts authenticated insert"
  on public.spare_parts for insert
  to authenticated
  with check (true);

drop policy if exists "spare parts authenticated update" on public.spare_parts;
create policy "spare parts authenticated update"
  on public.spare_parts for update
  to authenticated
  using (true)
  with check (true);

drop policy if exists "machines authenticated read" on public.machines;
create policy "machines authenticated read"
  on public.machines for select
  to authenticated
  using (true);

drop policy if exists "machines authenticated insert" on public.machines;
create policy "machines authenticated insert"
  on public.machines for insert
  to authenticated
  with check (true);

drop policy if exists "machines authenticated update" on public.machines;
create policy "machines authenticated update"
  on public.machines for update
  to authenticated
  using (true)
  with check (true);
