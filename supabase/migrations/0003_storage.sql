-- Private storage for profile photos and project media.
--
-- The bucket is private by default: nothing is publicly reachable. Objects are
-- written under a `<user-id>/...` prefix and policies authorise by comparing
-- that prefix to `auth.uid()`, so one user can never read another's uploads.

insert into storage.buckets (id, name, public)
values ('document-media', 'document-media', false)
on conflict (id) do nothing;

-- ------------------------------------------------------------------- policies
drop policy if exists "owners read their media" on storage.objects;
create policy "owners read their media"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'document-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "owners upload their media" on storage.objects;
create policy "owners upload their media"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'document-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "owners update their media" on storage.objects;
create policy "owners update their media"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'document-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "owners delete their media" on storage.objects;
create policy "owners delete their media"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'document-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- NOTE: published portfolio images are served through short-lived signed URLs
-- generated for the viewing session, never through public bucket access, so
-- media referenced by a share stays private until it is deliberately shared.
