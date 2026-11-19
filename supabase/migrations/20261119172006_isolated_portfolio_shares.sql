-- Each authorized share returns only its saved CV/portfolio content.
-- Existing authorization and function permissions are retained.

CREATE OR REPLACE FUNCTION public.resolve_share_by_slug(p_slug text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    'profile',  coalesce(v_document.profile_snapshot, public._profile_payload(v_profile)),
    'shareId',  v_share.id
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.resolve_share_by_token(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_share public.document_shares%rowtype;
  v_document public.documents%rowtype;
  v_profile public.profiles%rowtype;
begin
  -- Restricted shares have no slug. Resolve the token independently and
  -- enforce publication, expiry and revocation before returning its document.
  select * into v_share from public.document_shares
   where access_token = p_token and mode = 'restrictedRecipient';
  if not found then return null; end if;
  if v_share.revoked_at is not null then return null; end if;
  if v_share.expires_at is not null and v_share.expires_at <= now() then
    return null;
  end if;
  select * into v_document from public.documents where id = v_share.document_id;
  if not found or v_document.published is not true then return null; end if;
  select * into v_profile from public.profiles where id = v_document.owner_id;
  if not found then return null; end if;
  -- Payload helpers are installed by 0004 and extended by 0005.
  return jsonb_build_object(
    'document', public._document_payload(v_document),
    'profile', coalesce(v_document.profile_snapshot, public._profile_payload(v_profile)),
    'shareId', v_share.id
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.resolve_share_with_password(p_slug text, p_password text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
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
    'profile',  coalesce(v_document.profile_snapshot, public._profile_payload(v_profile)),
    'shareId',  v_share.id
  );
end;
$function$;
