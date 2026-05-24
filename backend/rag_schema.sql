-- Pulse RAG schema
-- Run this in the Supabase SQL Editor after creating the private `manuals` bucket.

create extension if not exists vector with schema extensions;

create table if not exists public.manuals (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  machine_model text not null,
  category text not null default 'Service Manual',
  file_name text not null,
  file_type text not null default 'pdf',
  file_size bigint not null default 0,
  storage_bucket text not null default 'manuals',
  storage_path text not null,
  uploaded_by uuid references auth.users(id) on delete set null,
  indexed_status text not null default 'pending',
  chunk_count integer not null default 0,
  error_message text,
  created_at timestamptz not null default now(),
  indexed_at timestamptz
);

create table if not exists public.manual_chunks (
  id uuid primary key default gen_random_uuid(),
  manual_id uuid not null references public.manuals(id) on delete cascade,
  chunk_index integer not null,
  chunk_text text not null,
  page_number integer,
  section_title text,
  machine_model text not null,
  file_name text not null,
  token_count integer not null default 0,
  embedding_model text not null default 'gemini-embedding-001',
  embedding_dimension integer not null default 768,
  embedding extensions.vector(768) not null,
  created_at timestamptz not null default now()
);

create index if not exists manual_chunks_manual_id_idx
  on public.manual_chunks (manual_id);

create index if not exists manual_chunks_machine_model_idx
  on public.manual_chunks (machine_model);

create index if not exists manual_chunks_embedding_hnsw_idx
  on public.manual_chunks
  using hnsw (embedding vector_cosine_ops);

create or replace function public.match_manual_chunks (
  query_embedding extensions.vector(768),
  match_threshold float default 0.35,
  match_count int default 8,
  filter_model text default null
)
returns table (
  chunk_id uuid,
  manual_id uuid,
  title text,
  machine_model text,
  file_name text,
  page_number integer,
  section_title text,
  chunk_text text,
  similarity float
)
language sql
stable
as $$
  select
    manual_chunks.id as chunk_id,
    manual_chunks.manual_id,
    manuals.title,
    manual_chunks.machine_model,
    manual_chunks.file_name,
    manual_chunks.page_number,
    manual_chunks.section_title,
    manual_chunks.chunk_text,
    1 - (manual_chunks.embedding <=> query_embedding) as similarity
  from public.manual_chunks
  join public.manuals on manuals.id = manual_chunks.manual_id
  where
    (filter_model is null or filter_model = '' or manual_chunks.machine_model ilike '%' || filter_model || '%')
    and 1 - (manual_chunks.embedding <=> query_embedding) >= match_threshold
  order by manual_chunks.embedding <=> query_embedding asc
  limit least(match_count, 20);
$$;

alter table public.manuals enable row level security;
alter table public.manual_chunks enable row level security;

drop policy if exists "manuals authenticated read" on public.manuals;
create policy "manuals authenticated read"
  on public.manuals for select
  to authenticated
  using (true);

drop policy if exists "manual chunks authenticated read" on public.manual_chunks;
create policy "manual chunks authenticated read"
  on public.manual_chunks for select
  to authenticated
  using (true);

-- Backend ingestion should use SUPABASE_SERVICE_ROLE_KEY.
-- Keep insert/update policies closed to the Flutter client unless you explicitly
-- want users to write these tables directly.

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
