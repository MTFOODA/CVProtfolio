-- Run only in the isolated database created by test_supabase_migrations.ps1.
begin;
insert into auth.users values
 ('11111111-1111-1111-1111-111111111111'),
 ('22222222-2222-2222-2222-222222222222');
insert into public.profiles (id, details) values
 ('11111111-1111-1111-1111-111111111111', '{"fullName":"Owner"}'),
 ('22222222-2222-2222-2222-222222222222', '{"fullName":"Other user"}');
insert into public.documents (id, owner_id, title, type, published) values
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Portfolio', 'portfolio', true);
insert into public.document_shares (id, document_id, mode, slug, access_token) values
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'publicLink', 'audit-public', null),
 ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'restrictedRecipient', null, 'audit-private-token');

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
do $$ begin
  if (select count(*) from public.profiles) <> 1 then
    raise exception 'Owner isolation failed';
  end if;
  if public.generate_share_token() !~ '^[A-Za-z0-9_-]{43}$' then
    raise exception 'Token is not 32 bytes of base64url';
  end if;
  update public.profiles set details = '{"fullName":"Updated"}' where id = auth.uid();
  if not found then raise exception 'Owner cannot save profile'; end if;
  begin
    insert into public.cv_builder_drafts values (auth.uid(), 'bad', '{"profile":{"id":"other"}}', now());
    raise exception 'Foreign profile draft was accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.documents set owner_id = '22222222-2222-2222-2222-222222222222';
    raise exception 'Owner reassignment was accepted';
  exception when insufficient_privilege then null;
  end;
end $$;
insert into public.cv_builder_drafts values
 (auth.uid(), 'valid', '{"profile":{"id":"11111111-1111-1111-1111-111111111111"}}', now());
select public.set_portfolio_password('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'correct-password');

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
do $$ declare payload jsonb; begin
  if public.resolve_share_by_slug('audit-public') is not null then
    raise exception 'Plain slug bypassed password';
  end if;
  if public.resolve_share_with_password('audit-public', null) is not null or
     public.resolve_share_with_password('audit-public', '') is not null or
     public.resolve_share_with_password('audit-public', 'wrong') is not null then
    raise exception 'Invalid password bypassed access control';
  end if;
  payload := public.resolve_share_with_password('audit-public', 'correct-password');
  if payload->'document'->>'id' is distinct from 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' then
    raise exception 'Correct password cannot resolve share';
  end if;
  if payload->'document' ? 'access_password_hash' or payload->'document' ? 'accessPasswordHash' then
    raise exception 'Password hash leaked';
  end if;
  if public.resolve_share_by_token('audit-private-token') is null then
    raise exception 'Recipient token cannot resolve its document';
  end if;
  if public.resolve_share_by_token('wrong-token') is not null then
    raise exception 'Invalid token returned data';
  end if;
end $$;

reset role;
update public.document_shares set revoked_at = now() where mode = 'restrictedRecipient';
set local role anon;
do $$ begin
  if public.resolve_share_by_token('audit-private-token') is not null then
    raise exception 'Revoked token returned data';
  end if;
end $$;
reset role;
update public.document_shares set revoked_at = null, expires_at = now() - interval '1 minute';
set local role anon;
do $$ begin
  if public.resolve_share_with_password('audit-public', 'correct-password') is not null or
     public.resolve_share_by_token('audit-private-token') is not null then
    raise exception 'Expired share returned data';
  end if;
end $$;
reset role;
update public.document_shares set expires_at = null;
update public.documents set published = false;
set local role anon;
do $$ begin
  if public.resolve_share_with_password('audit-public', 'correct-password') is not null or
     public.resolve_share_by_token('audit-private-token') is not null then
    raise exception 'Unpublished document was exposed';
  end if;
end $$;
reset role;
rollback;
select 'PASS: ownership, writes, drafts, passwords, tokens, revocation, expiry, publication' as result;
