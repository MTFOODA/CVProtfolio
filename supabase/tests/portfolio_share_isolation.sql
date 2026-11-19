-- Run as the database administrator. All fixture rows roll back.
-- Uses an existing owner solely to satisfy the auth FK; never changes a profile.
begin;
do $test$
declare
  owner uuid;
  doc_a uuid := gen_random_uuid();
  doc_b uuid := gen_random_uuid();
  slug_a text := 'qa-' || gen_random_uuid()::text;
  slug_b text := 'qa-' || gen_random_uuid()::text;
  token_a text := gen_random_uuid()::text;
  payload jsonb;
begin
  select id into owner from public.profiles limit 1;
  if owner is null then raise exception 'A fixture owner is required'; end if;
  insert into public.documents(id, owner_id, title, type, published, share_mode, public_slug, profile_snapshot)
  values
    (doc_a, owner, 'QA portfolio A', 'portfolio', true, 'publicLink', slug_a,
     jsonb_build_object('id', owner, 'details', '{}'::jsonb, 'projects', '[{"id":"snapshot-a","title":"Only A"}]'::jsonb)),
    (doc_b, owner, 'QA portfolio B', 'portfolio', true, 'publicLink', slug_b,
     jsonb_build_object('id', owner, 'details', '{}'::jsonb, 'projects', '[{"id":"snapshot-b","title":"Only B"}]'::jsonb));
  update public.documents set access_password_hash = crypt('qa-password', gen_salt('bf')) where id = doc_b;
  insert into public.document_shares(document_id, mode, slug, access_token)
  values (doc_a, 'publicLink', slug_a, null),
         (doc_b, 'publicLink', slug_b, null),
         (doc_a, 'restrictedRecipient', null, token_a);

  payload := public.resolve_share_by_slug(slug_a);
  if payload #>> '{profile,projects,0,id}' is distinct from 'snapshot-a'
     or jsonb_array_length(payload #> '{profile,projects}') <> 1
  then raise exception 'Public slug leaked another CV'; end if;
  payload := public.resolve_share_by_token(token_a);
  if payload #>> '{profile,projects,0,id}' is distinct from 'snapshot-a'
  then raise exception 'Restricted token returned the live profile'; end if;
  if public.resolve_share_by_slug(slug_b) is not null
     or public.resolve_share_with_password(slug_b, 'wrong-password') is not null
  then raise exception 'Password protection was bypassed'; end if;
  payload := public.resolve_share_with_password(slug_b, 'qa-password');
  if payload #>> '{profile,projects,0,id}' is distinct from 'snapshot-b'
     or jsonb_array_length(payload #> '{profile,projects}') <> 1
  then raise exception 'Protected portfolio leaked another CV'; end if;

  update public.document_shares set revoked_at = now() where slug = slug_a;
  if public.resolve_share_by_slug(slug_a) is not null
  then raise exception 'Revoked share was accepted'; end if;
  update public.document_shares set expires_at = now() - interval '1 minute' where access_token = token_a;
  if public.resolve_share_by_token(token_a) is not null
  then raise exception 'Expired token was accepted'; end if;
end;
$test$;
select true as independent_slug_token_password_and_revocation_passed;
rollback;
