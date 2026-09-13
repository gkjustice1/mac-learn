-- ============================================================
-- MAC Learn Vocabulary Studio
-- VS-E01-US02: Multilingual Forms + Morphology Foundation
-- ============================================================

-- ------------------------------------------------------------
-- Supporting key for sense-aware child records.
-- This permits a composite FK to prove that sense_id belongs
-- to the same word_id supplied by a child record.
-- ------------------------------------------------------------

create unique index vocab_senses_id_word_unique
  on public.vocab_senses (id, word_id);


-- ============================================================
-- 1. Multilingual / alternate language forms
-- ============================================================

create table public.vocab_language_forms (
  id uuid primary key default gen_random_uuid(),

  word_id uuid not null
    references public.vocab_words(id)
    on delete restrict,

  sense_id uuid,

  language_code text not null
    check (
      language_code ~ '^[a-z]{2,3}(-[A-Z]{2})?$'
    ),

  locale_code text
    check (
      locale_code is null
      or locale_code ~ '^[a-z]{2,3}(-[A-Z]{2})?$'
    ),

  form_text text not null
    check (btrim(form_text) <> ''),

  normalized_form text
    generated always as (lower(btrim(form_text))) stored,

  form_type text not null
    check (btrim(form_type) <> ''),

  publication_status public.vocab_publication_status
    not null default 'draft',

  version_number integer
    not null default 1
    check (version_number > 0),

  source_reference text,

  review_status text
    not null default 'unreviewed'
    check (
      review_status in (
        'unreviewed',
        'in_review',
        'verified',
        'rejected'
      )
    ),

  -- Preserve attribution: retire reviewer accounts instead of hard-deleting
  -- users referenced by governed language forms.
  reviewed_by uuid
    references public.users(id)
    on delete restrict,

  reviewed_at timestamptz,

  created_at timestamptz not null default now(),

  created_by uuid
    references public.users(id)
    on delete set null,

  updated_at timestamptz not null default now(),

  updated_by uuid
    references public.users(id)
    on delete set null,

  constraint vocab_language_forms_sense_word_fk
    foreign key (sense_id, word_id)
    references public.vocab_senses(id, word_id)
    on delete restrict,

  constraint vocab_language_forms_locale_language_check
    check (locale_code is null or
      split_part(locale_code, '-', 1) = split_part(language_code, '-', 1)),

  constraint vocab_language_forms_publication_review_check
    check (
      publication_status not in ('certified', 'published')
      or review_status = 'verified'
    ),

  constraint vocab_language_forms_review_consistency_check
    check (
      (review_status in ('unreviewed', 'in_review', 'rejected')
        and reviewed_by is null and reviewed_at is null)
      or
      (
        review_status = 'verified'
        and reviewed_by is not null
        and reviewed_at is not null
      )
    )
);


create unique index vocab_language_forms_identity_unique
  on public.vocab_language_forms (
    word_id,
    coalesce(sense_id, '00000000-0000-0000-0000-000000000000'::uuid),
    language_code,
    coalesce(locale_code, ''),
    lower(btrim(form_type)),
    normalized_form
  );

create index vocab_language_forms_word_idx
  on public.vocab_language_forms (word_id);

create index vocab_language_forms_sense_idx
  on public.vocab_language_forms (sense_id)
  where sense_id is not null;

create index vocab_language_forms_reviewed_by_idx
  on public.vocab_language_forms (reviewed_by)
  where reviewed_by is not null;

create index vocab_language_forms_created_by_idx
  on public.vocab_language_forms (created_by);

create index vocab_language_forms_updated_by_idx
  on public.vocab_language_forms (updated_by);

create index vocab_language_forms_lookup_idx
  on public.vocab_language_forms (
    word_id,
    language_code,
    publication_status
  );


-- ============================================================
-- 2. Reusable morphology units
-- ============================================================

create table public.vocab_morphemes (
  id uuid primary key default gen_random_uuid(),

  canonical_code text not null unique
    check (btrim(canonical_code) <> ''),

  morpheme text not null
    check (btrim(morpheme) <> ''),

  normalized_morpheme text
    generated always as (lower(btrim(morpheme))) stored,

  language_code text not null default 'en'
    check (
      language_code ~ '^[a-z]{2,3}(-[A-Z]{2})?$'
    ),

  morpheme_type text not null
    check (
      morpheme_type in (
        'root',
        'base',
        'prefix',
        'suffix',
        'combining_form',
        'inflection',
        'other'
      )
    ),

  origin_language text,

  core_meaning text,

  instructional_explanation text,

  publication_status public.vocab_publication_status
    not null default 'draft',

  version_number integer
    not null default 1
    check (version_number > 0),

  created_at timestamptz not null default now(),

  created_by uuid
    references public.users(id)
    on delete set null,

  updated_at timestamptz not null default now(),

  updated_by uuid
    references public.users(id)
    on delete set null
);


create unique index vocab_morphemes_identity_unique
  on public.vocab_morphemes (
    language_code,
    normalized_morpheme,
    morpheme_type
  );

create index vocab_morphemes_lookup_idx
  on public.vocab_morphemes (
    language_code,
    normalized_morpheme,
    publication_status
  );

create index vocab_morphemes_created_by_idx
  on public.vocab_morphemes (created_by);

create index vocab_morphemes_updated_by_idx
  on public.vocab_morphemes (updated_by);


-- ============================================================
-- 3. Ordered word-to-morpheme composition
-- ============================================================

create table public.vocab_word_morphemes (
  id uuid primary key default gen_random_uuid(),

  word_id uuid not null
    references public.vocab_words(id)
    on delete restrict,

  sense_id uuid,

  morpheme_id uuid not null
    references public.vocab_morphemes(id)
    on delete restrict,

  sequence_order smallint not null
    check (sequence_order > 0),

  surface_form text
    check (
      surface_form is null
      or btrim(surface_form) <> ''
    ),

  relationship_type text not null
    check (btrim(relationship_type) <> ''),

  semantic_contribution text,

  instructional_note text,

  publication_status public.vocab_publication_status
    not null default 'draft',

  version_number integer
    not null default 1
    check (version_number > 0),

  created_at timestamptz not null default now(),

  created_by uuid
    references public.users(id)
    on delete set null,

  updated_at timestamptz not null default now(),

  updated_by uuid
    references public.users(id)
    on delete set null,

  constraint vocab_word_morphemes_sense_word_fk
    foreign key (sense_id, word_id)
    references public.vocab_senses(id, word_id)
    on delete restrict,

  constraint vocab_word_morphemes_position_unique
    unique nulls not distinct (
      word_id,
      sense_id,
      sequence_order
    )
);


create index vocab_word_morphemes_word_idx
  on public.vocab_word_morphemes (word_id);

create index vocab_word_morphemes_sense_idx
  on public.vocab_word_morphemes (sense_id)
  where sense_id is not null;

create index vocab_word_morphemes_morpheme_idx
  on public.vocab_word_morphemes (morpheme_id);

create index vocab_word_morphemes_created_by_idx
  on public.vocab_word_morphemes (created_by);

create index vocab_word_morphemes_updated_by_idx
  on public.vocab_word_morphemes (updated_by);

create index vocab_word_morphemes_word_sequence_idx
  on public.vocab_word_morphemes (
    word_id,
    sequence_order
  );


-- ============================================================
-- 4. Updated-at lifecycle
-- Reuse the certified US01 SECURITY INVOKER helper.
-- ============================================================

create trigger vocab_language_forms_touch_updated_at
  before update on public.vocab_language_forms
  for each row
  execute function public.mac_touch_vocab_record();

create trigger vocab_morphemes_touch_updated_at
  before update on public.vocab_morphemes
  for each row
  execute function public.mac_touch_vocab_record();

create trigger vocab_word_morphemes_touch_updated_at
  before update on public.vocab_word_morphemes
  for each row
  execute function public.mac_touch_vocab_record();


-- ============================================================
-- 5. Protect certified US02 records
-- ============================================================

create or replace function public.mac_protect_vocab_us02_record()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    if old.publication_status in (
      'certified',
      'published',
      'deprecated',
      'withdrawn'
    ) then
      raise exception
        'certified vocabulary records cannot be hard deleted'
        using errcode = '23514';
    end if;

    return old;
  end if;

  -- A reusable unit cannot become hidden while published links still use it.
  -- The row lock taken by UPDATE conflicts with the link trigger's FOR SHARE.
  if tg_table_name = 'vocab_morphemes'
     and new.publication_status <> 'published'
     and exists (
       select 1 from public.vocab_word_morphemes
       where morpheme_id = old.id and publication_status = 'published'
     ) then
    raise exception 'published morphology links require a published morpheme'
      using errcode = '23514';
  end if;

  if new.id is distinct from old.id then
    raise exception
      'vocabulary record id is immutable'
      using errcode = '23514';
  end if;

  if tg_table_name = 'vocab_language_forms'
     and to_jsonb(old)->>'review_status' = 'verified'
     and old.publication_status in ('draft', 'in_review', 'verified')
     and (to_jsonb(new) - array['updated_at', 'created_at', 'updated_by', 'created_by',
           'publication_status', 'review_status', 'reviewed_by', 'reviewed_at',
           'source_reference', 'version_number', 'normalized_form'])
       is distinct from
         (to_jsonb(old) - array['updated_at', 'created_at', 'updated_by', 'created_by',
           'publication_status', 'review_status', 'reviewed_by', 'reviewed_at',
           'source_reference', 'version_number', 'normalized_form']) then
    raise exception 'verified vocabulary language-form content requires a new review'
      using errcode = '23514';
  end if;

  if old.publication_status in (
    'certified',
    'published',
    'deprecated',
    'withdrawn'
  ) then

    if new.publication_status in (
      'draft',
      'in_review',
      'verified'
    ) then
      raise exception
        'certified vocabulary lifecycle cannot be downgraded'
        using errcode = '23514';
    end if;

    if tg_table_name = 'vocab_language_forms' then
      if
        to_jsonb(new)->'form_text'
          is distinct from to_jsonb(old)->'form_text'
        or
        to_jsonb(new)->'word_id'
          is distinct from to_jsonb(old)->'word_id'
        or
        to_jsonb(new)->'sense_id'
          is distinct from to_jsonb(old)->'sense_id'
        or
        to_jsonb(new)->'language_code'
          is distinct from to_jsonb(old)->'language_code'
        or
        to_jsonb(new)->'locale_code'
          is distinct from to_jsonb(old)->'locale_code'
        or
        to_jsonb(new)->'form_type'
          is distinct from to_jsonb(old)->'form_type'
      then
        raise exception
          'certified vocabulary language-form identity is immutable'
          using errcode = '23514';
      end if;
    end if;

    if tg_table_name = 'vocab_morphemes' then
      if
        to_jsonb(new)->'morpheme'
          is distinct from to_jsonb(old)->'morpheme'
        or
        to_jsonb(new)->'canonical_code'
          is distinct from to_jsonb(old)->'canonical_code'
        or
        to_jsonb(new)->'language_code'
          is distinct from to_jsonb(old)->'language_code'
        or
        to_jsonb(new)->'morpheme_type'
          is distinct from to_jsonb(old)->'morpheme_type'
      then
        raise exception
          'certified vocabulary morpheme identity is immutable'
          using errcode = '23514';
      end if;
    end if;

    if tg_table_name = 'vocab_word_morphemes' then
      if
        to_jsonb(new)->'word_id'
          is distinct from to_jsonb(old)->'word_id'
        or
        to_jsonb(new)->'sense_id'
          is distinct from to_jsonb(old)->'sense_id'
        or
        to_jsonb(new)->'morpheme_id'
          is distinct from to_jsonb(old)->'morpheme_id'
        or
        to_jsonb(new)->'sequence_order'
          is distinct from to_jsonb(old)->'sequence_order'
      then
        raise exception
          'certified vocabulary morphology-link identity is immutable'
          using errcode = '23514';
      end if;
    end if;

  end if;

  return new;
end;
$$;


revoke all
  on function public.mac_protect_vocab_us02_record()
  from public, anon, authenticated, service_role;

grant execute
  on function public.mac_protect_vocab_us02_record()
  to service_role;


create trigger vocab_language_forms_protect_identity
  before update or delete on public.vocab_language_forms
  for each row
  execute function public.mac_protect_vocab_us02_record();

create trigger vocab_morphemes_protect_identity
  before update or delete on public.vocab_morphemes
  for each row
  execute function public.mac_protect_vocab_us02_record();

create trigger vocab_word_morphemes_protect_identity
  before update or delete on public.vocab_word_morphemes
  for each row
  execute function public.mac_protect_vocab_us02_record();


-- ============================================================
-- 6. Publication consistency and Row Level Security
-- ============================================================

-- Validate publication before links become readable, avoiding cyclic RLS
-- between links and morphemes. FOR SHARE serializes with unit status updates.
create function public.mac_require_published_morpheme()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  unit_status public.vocab_publication_status;
begin
  if new.publication_status = 'published' then
    select publication_status into unit_status
    from public.vocab_morphemes where id = new.morpheme_id
    for share;
    if unit_status is distinct from 'published'::public.vocab_publication_status then
      raise exception 'published morphology links require a published morpheme'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.mac_require_published_morpheme()
  from public, anon, authenticated, service_role;
grant execute on function public.mac_require_published_morpheme() to service_role;
create trigger vocab_word_morphemes_require_published_unit
  before insert or update on public.vocab_word_morphemes
  for each row execute function public.mac_require_published_morpheme();

alter table public.vocab_language_forms
  enable row level security;

alter table public.vocab_morphemes
  enable row level security;

alter table public.vocab_word_morphemes
  enable row level security;


-- ------------------------------------------------------------
-- Language forms inherit the visibility of their canonical word.
-- Sense-specific forms additionally require a published sense.
-- ------------------------------------------------------------

create policy
  "published vocabulary language forms follow visible word scope"
on public.vocab_language_forms
for select
to authenticated
using (
  publication_status = 'published'
  and exists (
    select 1
    from public.vocab_words word
    where word.id = vocab_language_forms.word_id
      and word.publication_status = 'published'
      and (
        word.ownership_scope = 'platform_canonical'
        or public.mac_is_platform_admin()
        or (
          word.ownership_scope = 'tenant_extension'
          and exists (
            select 1
            from public.mac_current_user_roles() role_scope
            where role_scope.organization_id = word.organization_id
          )
        )
      )
  )
  and (
    sense_id is null
    or exists (
      select 1
      from public.vocab_senses sense
      where sense.id = vocab_language_forms.sense_id
        and sense.word_id = vocab_language_forms.word_id
        and sense.publication_status = 'published'
    )
  )
);


-- ------------------------------------------------------------
-- Word/morpheme links inherit visible-word scope.
-- ------------------------------------------------------------

create policy
  "published vocabulary morphology links follow visible word scope"
on public.vocab_word_morphemes
for select
to authenticated
using (
  publication_status = 'published'
  and exists (
    select 1
    from public.vocab_words word
    where word.id = vocab_word_morphemes.word_id
      and word.publication_status = 'published'
      and (
        word.ownership_scope = 'platform_canonical'
        or public.mac_is_platform_admin()
        or (
          word.ownership_scope = 'tenant_extension'
          and exists (
            select 1
            from public.mac_current_user_roles() role_scope
            where role_scope.organization_id = word.organization_id
          )
        )
      )
  )
  and (
    sense_id is null
    or exists (
      select 1
      from public.vocab_senses sense
      where sense.id = vocab_word_morphemes.sense_id
        and sense.word_id = vocab_word_morphemes.word_id
        and sense.publication_status = 'published'
    )
  )
);


-- ------------------------------------------------------------
-- Morphemes are platform-canonical in US02 and become readable
-- only when published and used by at least one published link
-- whose parent word is visible to the authenticated user.
-- ------------------------------------------------------------

create policy
  "published morphemes readable through visible vocabulary"
on public.vocab_morphemes
for select
to authenticated
using (
  publication_status = 'published'
  and exists (
    select 1
    from public.vocab_word_morphemes link
    join public.vocab_words word
      on word.id = link.word_id
    where link.morpheme_id = vocab_morphemes.id
      and link.publication_status = 'published'
      and word.publication_status = 'published'
      and (
        word.ownership_scope = 'platform_canonical'
        or public.mac_is_platform_admin()
        or (
          word.ownership_scope = 'tenant_extension'
          and exists (
            select 1
            from public.mac_current_user_roles() role_scope
            where role_scope.organization_id = word.organization_id
          )
        )
      )
      and (
        link.sense_id is null
        or exists (
          select 1
          from public.vocab_senses sense
          where sense.id = link.sense_id
            and sense.word_id = link.word_id
            and sense.publication_status = 'published'
        )
      )
  )
);


-- ============================================================
-- 7. Explicit least-privilege ACLs
-- ============================================================

revoke all
  on table public.vocab_language_forms
  from public, anon, authenticated, service_role;

revoke all
  on table public.vocab_morphemes
  from public, anon, authenticated, service_role;

revoke all
  on table public.vocab_word_morphemes
  from public, anon, authenticated, service_role;


grant select
  on table public.vocab_language_forms
  to authenticated;

grant select
  on table public.vocab_morphemes
  to authenticated;

grant select
  on table public.vocab_word_morphemes
  to authenticated;


grant select, insert, update, delete
  on table public.vocab_language_forms
  to service_role;

grant select, insert, update, delete
  on table public.vocab_morphemes
  to service_role;

grant select, insert, update, delete
  on table public.vocab_word_morphemes
  to service_role;


-- PostgreSQL 17 production-equivalent maintenance privilege.
-- US01 vocabulary tables received this through the later
-- production ACL reconciliation; these new US02 tables are
-- created after that migration, so grant it explicitly here.

grant maintain
  on table public.vocab_language_forms
  to service_role;

grant maintain
  on table public.vocab_morphemes
  to service_role;

grant maintain
  on table public.vocab_word_morphemes
  to service_role;


-- ============================================================
-- 8. Documentation
-- ============================================================

comment on table public.vocab_language_forms is
  'Vocabulary Studio governed multilingual and alternate lexical forms. Visibility inherits from the canonical parent word and, when applicable, its sense.';

comment on table public.vocab_morphemes is
  'Vocabulary Studio reusable platform-canonical morphology units such as roots, bases, prefixes, suffixes, combining forms, and inflections.';

comment on table public.vocab_word_morphemes is
  'Vocabulary Studio ordered composition linking canonical vocabulary words and optional senses to reusable morphemes.';

comment on function public.mac_protect_vocab_us02_record() is
  'Protects certified Vocabulary Studio US02 record identity and lifecycle from hard deletion, downgrade, or identity reassignment.';


-- ============================================================
-- VS-E01-US02 intentionally contains NO vocabulary seed data.
-- PROTOTYPE / FORCE / FRICTION / MODIFY remain unseeded.
-- ============================================================
