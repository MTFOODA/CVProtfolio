-- CV & Portfolio Maker — initial schema
--
-- Design notes:
--   * Profiles hold the reusable source of truth for a user's information.
--   * Documents store configuration only (sections, design, share settings),
--     so many CVs/portfolios can reuse one profile with different presentation.
--   * Row Level Security is enabled everywhere. Every policy is explicit.
--   * Public share resolution goes through SECURITY DEFINER functions, so an
--     anonymous viewer can read only publishable content and never the owner's
--     other records.
--   * The service-role key is never needed by the Flutter client.

create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------- profiles
create table if not exists public.profiles (
  id             uuid primary key references auth.users (id) on delete cascade,
  details        jsonb not null default '{}'::jsonb,
  experiences    jsonb not null default '[]'::jsonb,
  education      jsonb not null default '[]'::jsonb,
  skills         jsonb not null default '[]'::jsonb,
  languages      jsonb not null default '[]'::jsonb,
  certificates   jsonb not null default '[]'::jsonb,
  courses        jsonb not null default '[]'::jsonb,
  awards         jsonb not null default '[]'::jsonb,
  volunteer      jsonb not null default '[]'::jsonb,
  publications   jsonb not null default '[]'::jsonb,
  references     jsonb not null default '[]'::jsonb,
  projects       jsonb not null default '[]'::jsonb,
  custom_sections jsonb not null default '[]'::jsonb,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles are self-service" on public.profiles;
create policy "profiles are self-service"
  on public.profiles
  for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ---------------------------------------------------------------- documents
create table if not exists public.documents (
  id                  uuid primary key default gen_random_uuid(),
  owner_id            uuid not null references auth.users (id) on delete cascade,
  title               text not null check (length(btrim(title)) > 0),
  type                text not null default 'cv'
                        check (type in ('cv', 'portfolio')),
  design              jsonb not null default '{}'::jsonb,
  included_project_ids text[],
  share_mode          text not null default 'privateDraft'
                        check (share_mode in ('privateDraft', 'publicLink',
                                              'restrictedRecipient')),
  published           boolean not null default false,
  public_slug         text unique,
  allow_pdf_download  boolean not null default true,
  is_rtl              boolean not null default false,
  version             integer not null default 1,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create index if not exists documents_owner_updated_idx
  on public.documents (owner_id, updated_at desc);

create unique index if not exists documents_public_slug_idx
  on public.documents (public_slug)
  where public_slug is not null;

alter table public.documents enable row level security;

drop policy if exists "owners manage their documents" on public.documents;
create policy "owners manage their documents"
  on public.documents
  for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- ------------------------------------------------------------ document_shares
create table if not exists public.document_shares (
  id              uuid primary key default gen_random_uuid(),
  document_id     uuid not null references public.documents (id) on delete cascade,
  mode            text not null
                    check (mode in ('publicLink', 'restrictedRecipient')),

  -- High-entropy, unguessable tokens. 32 random bytes, base64url encoded.
  access_token    text unique,
  slug            text unique,
  recipient_label text,
  recipient_email text,
  expires_at      timestamptz,
  revoked_at      timestamptz,
  view_count      integer not null default 0,
  created_at      timestamptz not null default now(),

  -- A public share uses a slug; a restricted share uses a token.
  constraint share_identifier_shape check (
    (mode = 'publicLink'        and slug is not null and access_token is null) or
    (mode = 'restrictedRecipient' and access_token is not null and slug is null)
  )
);

create index if not exists document_shares_document_idx
  on public.document_shares (document_id);
create index if not exists document_shares_token_idx
  on public.document_shares (access_token);

alter table public.document_shares enable row level security;

-- Owners manage shares for documents they own. Note there is deliberately no
-- policy granting anon/public SELECT: anonymous reads happen only through the
-- SECURITY DEFINER functions below, which enforce publication and expiry.
drop policy if exists "owners manage their shares" on public.document_shares;
create policy "owners manage their shares"
  on public.document_shares
  for all
  using (
    exists (
      select 1 from public.documents d
      where d.id = document_shares.document_id
        and d.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.documents d
      where d.id = document_shares.document_id
        and d.owner_id = auth.uid()
    )
  );
