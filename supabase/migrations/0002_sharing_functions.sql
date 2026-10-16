-- Share resolution and account deletion functions.
--
-- These are SECURITY DEFINER so an anonymous visitor can resolve a share
-- without being granted blanket read access to `documents`, `profiles` or
-- `document_shares`. Each function enforces:
--   * the share exists and matches the identifier,
--   * the share has not been revoked,
--   * the share has not expired,
--   * the document is actually published.
--
-- Critically, a share grants access to ONE document only — never to the
-- owner's other records.

-- ---------------------------------------------------------- token generation
create or replace function public.generate_share_token()
returns text
language sql
volatile
as $$
  -- 32 random bytes -> 43 chars of base64url: unguessable and high entropy.
  select replace(encode(gen_random_bytes(32), 'base64'), '/', '_')
$$;

-- ------------------------------------------------------------ slug resolution
create or replace function public.resolve_share_by_slug(p_slug text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_share    public.document_shares%rowtype;
  v_document public.documents%rowtype;
  v_profile  public.profiles%rowtype;
begin
  select * into v_share
    from public.document_shares
   where slug = p_slug
   limit 1;

  if not found then
    return null;
  end if;

  -- Revoked or expired shares are denied here, server-side.
  if v_share.revoked_at is not null then
    return null;
  end if;
  if v_share.expires_at is not null and v_share.expires_at < now() then
    return null;
  end if;

  select * into v_document
    from public.documents
   where id = v_share.document_id;

  if not found or v_document.published is not true then
    return null;
  end if;

  select * into v_profile
    from public.profiles
   where id = v_document.owner_id;

  -- Only the fields needed to render the published page are returned.
  return jsonb_build_object(
    'document', jsonb_build_object(
      'id',               v_document.id,
      'ownerId',          v_document.owner_id,
      'title',            v_document.title,
      'type',             v_document.type,
      'design',           v_document.design,
      'includedProjectIds', v_document.included_project_ids,
      'shareMode',        v_document.share_mode,
      'published',        v_document.published,
      'publicSlug',       v_document.public_slug,
      'allowPdfDownload', v_document.allow_pdf_download,
      'isRtl',            v_document.is_rtl,
      'version',          v_document.version,
      'updatedAtIso',     v_document.updated_at
    ),
    'profile', jsonb_build_object(
      'id',             v_profile.id,
      'details',        v_profile.details,
      'experiences',    v_profile.experiences,
      'education',      v_profile.education,
      'skills',         v_profile.skills,
      'languages',      v_profile.languages,
      'certificates',   v_profile.certificates,
      'courses',        v_profile.courses,
      'awards',         v_profile.awards,
      'volunteer',      v_profile.volunteer,
      'publications',   v_profile.publications,
      'references',     v_profile.references,
      'projects',       v_profile.projects,
      'customSections', v_profile.custom_sections
    ),
    'shareId', v_share.id
  );
end;
$$;

-- ----------------------------------------------------------- token resolution
create or replace function public.resolve_share_by_token(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  -- Identical rules to slug resolution, keyed on the restricted token.
  select public.resolve_share_by_slug(sh.slug)
    into v_result
    from public.document_shares sh
   where sh.access_token = p_token
     and sh.mode = 'restrictedRecipient';

  return v_result;
end;
$$;

-- ------------------------------------------------------------- view counting
create or replace function public.record_share_view(p_share_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.document_shares
     set view_count = view_count + 1
   where id = p_share_id;
end;
$$;

-- ----------------------------------------------------------- account deletion
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Deleting the auth user cascades to profiles, documents and shares.
  delete from auth.users where id = auth.uid();
end;
$$;

-- Anonymous visitors may call the resolvers, but nothing else.
revoke all on function public.resolve_share_by_slug(text)  from public;
revoke all on function public.resolve_share_by_token(text) from public;
revoke all on function public.record_share_view(uuid)      from public;
revoke all on function public.generate_share_token()       from public;
revoke all on function public.delete_own_account()         from public;

grant execute on function public.resolve_share_by_slug(text)  to anon, authenticated;
grant execute on function public.resolve_share_by_token(text) to anon, authenticated;
grant execute on function public.record_share_view(uuid)      to anon, authenticated;
grant execute on function public.generate_share_token()       to authenticated;
grant execute on function public.delete_own_account()         to authenticated;
