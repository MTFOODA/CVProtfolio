-- Password-protected portfolio access.
--
-- Privacy is enforced in Postgres, not in the client:
--   * The password is hashed with bcrypt (pgcrypto `crypt` + `gen_salt('bf')`)
--     inside a SECURITY DEFINER function, so the plaintext is never stored and
--     never leaves the request that sets it.
--   * `resolve_share_by_slug` is replaced so it REFUSES to return a document
--     that carries a password hash. A visitor must go through
--     `resolve_share_with_password`, which compares the supplied password
--     against the stored hash server-side.
--   * A modified client therefore cannot bypass the check by ignoring a UI
--     toggle: the row is simply not returned without a valid password.

alter table public.documents
  add column if not exists access_password_hash text;

-- ------------------------------------------------------------ set / clear password
create or replace function public.set_portfolio_password(
  p_document_id uuid,
  p_password    text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if p_password is null or length(p_password) < 4 then
    raise exception 'Password must be at least 4 characters';
  end if;

  update public.documents
     set access_password_hash = crypt(p_password, gen_salt('bf')),
         updated_at = now()
   where id = p_document_id
     and owner_id = auth.uid();

  if not found then
    raise exception 'Document not found or not owned by caller';
  end if;
end;
$$;

create or replace function public.clear_portfolio_password(p_document_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  update public.documents
     set access_password_hash = null,
         updated_at = now()
   where id = p_document_id
     and owner_id = auth.uid();

  if not found then
    raise exception 'Document not found or not owned by caller';
  end if;
end;
$$;

-- The payload shapes are shared by every resolver, so they live in one place.
create or replace function public._document_payload(v_document public.documents)
returns jsonb
language sql
immutable
as $$
  select jsonb_build_object(
    'id',                 v_document.id,
    'ownerId',            v_document.owner_id,
    'title',              v_document.title,
    'type',               v_document.type,
    'design',             v_document.design,
    'includedProjectIds', v_document.included_project_ids,
    'shareMode',          v_document.share_mode,
    'published',          v_document.published,
    'publicSlug',         v_document.public_slug,
    'allowPdfDownload',   v_document.allow_pdf_download,
    'isRtl',              v_document.is_rtl,
    'version',            v_document.version,
    'updatedAtIso',       v_document.updated_at
  )
$$;

create or replace function public._profile_payload(v_profile public.profiles)
returns jsonb
language sql
immutable
as $$
  select jsonb_build_object(
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
  )
$$;

-- ------------------------------------------------ password-gated resolution
create or replace function public.resolve_share_with_password(
  p_slug     text,
  p_password text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_share    public.document_shares%rowtype;
  v_document public.documents%rowtype;
  v_profile  public.profiles%rowtype;
begin
  -- SQL NULL comparisons do not evaluate to true; reject absent credentials
  -- before comparing hashes so a direct RPC call cannot bypass the password.
  if p_password is null or p_password = '' then return null; end if;
  select * into v_share
    from public.document_shares
   where slug = p_slug
   limit 1;

  if not found then return null; end if;
  if v_share.revoked_at is not null then return null; end if;
  if v_share.expires_at is not null and v_share.expires_at < now() then
    return null;
  end if;

  select * into v_document from public.documents where id = v_share.document_id;
  if not found or v_document.published is not true then return null; end if;
  if v_document.access_password_hash is null then return null; end if;

  -- The comparison happens here, on the server. A wrong password returns
  -- null exactly like a missing share, so nothing leaks.
  if v_document.access_password_hash is distinct from crypt(p_password, v_document.access_password_hash) then
    return null;
  end if;

  select * into v_profile from public.profiles where id = v_document.owner_id;

  return jsonb_build_object(
    'document', public._document_payload(v_document),
    'profile',  public._profile_payload(v_profile),
    'shareId',  v_share.id
  );
end;
$$;

-- ------------------------------------- plain slug resolution (password-aware)
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

  if not found then return null; end if;
  if v_share.revoked_at is not null then return null; end if;
  if v_share.expires_at is not null and v_share.expires_at < now() then
    return null;
  end if;

  select * into v_document from public.documents where id = v_share.document_id;
  if not found or v_document.published is not true then return null; end if;

  -- Password-protected documents require the dedicated resolver.
  if v_document.access_password_hash is not null then return null; end if;

  select * into v_profile from public.profiles where id = v_document.owner_id;

  return jsonb_build_object(
    'document', public._document_payload(v_document),
    'profile',  public._profile_payload(v_profile),
    'shareId',  v_share.id
  );
end;
$$;

-- --------------------------------------------------------------- permissions
revoke all on function public.set_portfolio_password(uuid, text)      from public;
revoke all on function public.clear_portfolio_password(uuid)          from public;
revoke all on function public.resolve_share_with_password(text, text) from public;
revoke all on function public._document_payload(public.documents)     from public;
revoke all on function public._profile_payload(public.profiles)       from public;

grant execute on function public.set_portfolio_password(uuid, text)      to authenticated;
grant execute on function public.clear_portfolio_password(uuid)          to authenticated;
grant execute on function public.resolve_share_with_password(text, text) to anon, authenticated;
