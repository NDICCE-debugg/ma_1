-- Pulse RAG Storage fix
-- Run this in Supabase SQL Editor if manual indexing says the `manuals`
-- bucket or storage policy is missing.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'manuals',
  'manuals',
  false,
  52428800,
  array['application/pdf']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "manual pdfs authenticated upload own folder" on storage.objects;
create policy "manual pdfs authenticated upload own folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'manuals'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "manual pdfs authenticated read own folder" on storage.objects;
create policy "manual pdfs authenticated read own folder"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'manuals'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "manual pdfs authenticated update own folder" on storage.objects;
create policy "manual pdfs authenticated update own folder"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'manuals'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'manuals'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
