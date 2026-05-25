-- Pulse RAG RLS fix
-- Run this in the Supabase SQL Editor if manual indexing fails with:
-- "new row violates row-level security policy for table \"manuals\"".

alter table public.manuals enable row level security;
alter table public.manual_chunks enable row level security;

drop policy if exists "manuals authenticated insert own records" on public.manuals;
create policy "manuals authenticated insert own records"
  on public.manuals for insert
  to authenticated
  with check (uploaded_by = auth.uid());

drop policy if exists "manuals authenticated update own records" on public.manuals;
create policy "manuals authenticated update own records"
  on public.manuals for update
  to authenticated
  using (uploaded_by = auth.uid())
  with check (uploaded_by = auth.uid());

drop policy if exists "manual chunks authenticated insert own manual chunks" on public.manual_chunks;
create policy "manual chunks authenticated insert own manual chunks"
  on public.manual_chunks for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.manuals
      where manuals.id = manual_chunks.manual_id
        and manuals.uploaded_by = auth.uid()
    )
  );
