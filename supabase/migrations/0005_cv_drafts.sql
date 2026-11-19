-- CV content is saved per document; Portfolio still uses the live profile.
alter table public.documents add column if not exists profile_snapshot jsonb;

-- Preserve every existing CV before the first independent CV is created.
update public.documents d
   set profile_snapshot = public._profile_payload(p)
  from public.profiles p
 where d.owner_id = p.id and d.type = 'cv' and d.profile_snapshot is null;

create table if not exists public.cv_builder_drafts (
  owner_id uuid not null references auth.users(id) on delete cascade,
  draft_key text not null check (length(draft_key) between 1 and 128),
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (owner_id, draft_key)
);
alter table public.cv_builder_drafts enable row level security;
drop policy if exists "owners manage their CV drafts" on public.cv_builder_drafts;
create policy "owners manage their CV drafts" on public.cv_builder_drafts
  for all to authenticated using (owner_id = auth.uid())
  with check (owner_id = auth.uid() and payload->'profile'->>'id' = auth.uid()::text);
grant select, insert, update, delete on public.cv_builder_drafts to authenticated;

create or replace function public.capture_legacy_cv_profiles()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.documents set profile_snapshot = public._profile_payload(old)
   where owner_id = old.id and type = 'cv' and profile_snapshot is null;
  return new;
end;
$$;
revoke all on function public.capture_legacy_cv_profiles() from public;
drop trigger if exists capture_legacy_cv_profiles on public.profiles;
create trigger capture_legacy_cv_profiles before update on public.profiles
  for each row execute function public.capture_legacy_cv_profiles();

-- Retain the existing share-authorisation functions. Their document payload
-- now carries the saved content without ever returning a password hash.
create or replace function public._document_payload(v_document public.documents)
returns jsonb language sql immutable as $$
  select jsonb_build_object(
    'id', v_document.id, 'ownerId', v_document.owner_id,
    'title', v_document.title, 'type', v_document.type,
    'design', v_document.design, 'profileSnapshot', v_document.profile_snapshot,
    'includedProjectIds', v_document.included_project_ids,
    'shareMode', v_document.share_mode, 'published', v_document.published,
    'publicSlug', v_document.public_slug,
    'allowPdfDownload', v_document.allow_pdf_download,
    'isRtl', v_document.is_rtl, 'version', v_document.version,
    'updatedAtIso', v_document.updated_at
  )
$$;
revoke all on function public._document_payload(public.documents) from public;
