-- ============================================================
-- MAC Learn Vocabulary Studio: canonical Core Word + Sense model
-- VS-E01-US01
-- ============================================================

create type public.vocab_ownership_scope as enum (
  'platform_canonical',
  'tenant_extension'
);

create type public.vocab_publication_status as enum (
  'draft', 'in_review', 'verified', 'certified', 'published', 'deprecated', 'withdrawn'
);

create table public.vocab_words (
  id uuid primary key default gen_random_uuid(),
  canonical_code text not null unique,
  ownership_scope public.vocab_ownership_scope not null default 'platform_canonical',
  organization_id uuid references public.organizations(id) on delete restrict,
  lemma text not null check (btrim(lemma) <> ''),
  normalized_lemma text generated always as (lower(btrim(lemma))) stored,
  lexical_identity_key text not null default 'default' check (btrim(lexical_identity_key) <> ''),
  display_word text not null check (btrim(display_word) <> ''),
  language_code text not null default 'en' check (language_code ~ '^[a-z]{2,3}(-[A-Z]{2})?$'),
  primary_part_of_speech text not null check (btrim(primary_part_of_speech) <> ''),
  primary_grade_band text,
  first_instruction_grade smallint check (first_instruction_grade between 0 and 12),
  tier smallint check (tier between 1 and 3),
  student_definition text,
  academic_definition text,
  pronunciation_text text,
  syllabification text,
  syllable_count smallint check (syllable_count is null or syllable_count > 0),
  primary_stress text,
  academic_classification text,
  fast_bridge_classification text,
  sat_bridge_classification text,
  publication_status public.vocab_publication_status not null default 'draft',
  version_number integer not null default 1 check (version_number > 0),
  created_at timestamptz not null default now(),
  created_by uuid references public.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users(id) on delete set null,
  constraint vocab_words_ownership_scope_check check (
    (ownership_scope = 'platform_canonical' and organization_id is null)
    or (ownership_scope = 'tenant_extension' and organization_id is not null)
  )
);

create unique index vocab_words_platform_identity_unique
  on public.vocab_words (language_code, normalized_lemma, lower(btrim(primary_part_of_speech)), lower(btrim(lexical_identity_key)))
  where ownership_scope = 'platform_canonical';
create unique index vocab_words_tenant_identity_unique
  on public.vocab_words (organization_id, language_code, normalized_lemma, lower(btrim(primary_part_of_speech)), lower(btrim(lexical_identity_key)))
  where ownership_scope = 'tenant_extension';
create index vocab_words_lookup_idx on public.vocab_words (language_code, normalized_lemma, publication_status);
create index vocab_words_created_by_idx on public.vocab_words (created_by);
create index vocab_words_updated_by_idx on public.vocab_words (updated_by);

create table public.vocab_senses (
  id uuid primary key default gen_random_uuid(),
  word_id uuid not null references public.vocab_words(id) on delete restrict,
  sense_key text not null check (btrim(sense_key) <> ''),
  sense_number smallint not null check (sense_number > 0),
  student_definition text not null check (btrim(student_definition) <> ''),
  academic_definition text,
  discipline_scope text,
  grade_min smallint check (grade_min between 0 and 12),
  grade_max smallint check (grade_max between 0 and 12),
  usage_label text,
  example_text text,
  non_example_text text,
  precision_note text,
  publication_status public.vocab_publication_status not null default 'draft',
  version_number integer not null default 1 check (version_number > 0),
  created_at timestamptz not null default now(),
  created_by uuid references public.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users(id) on delete set null,
  constraint vocab_senses_grade_range_check check (grade_min is null or grade_max is null or grade_min <= grade_max),
  unique (word_id, sense_key), unique (word_id, sense_number)
);
create index vocab_senses_word_status_idx on public.vocab_senses (word_id, publication_status, sense_number);
create index vocab_senses_created_by_idx on public.vocab_senses (created_by);
create index vocab_senses_updated_by_idx on public.vocab_senses (updated_by);

create or replace function public.mac_touch_vocab_record() returns trigger language plpgsql security invoker set search_path = public as $$
begin new.updated_at := now(); return new; end; $$;
revoke all on function public.mac_touch_vocab_record() from public;
grant execute on function public.mac_touch_vocab_record() to service_role;
create trigger vocab_words_touch_updated_at before update on public.vocab_words for each row execute function public.mac_touch_vocab_record();
create trigger vocab_senses_touch_updated_at before update on public.vocab_senses for each row execute function public.mac_touch_vocab_record();

create or replace function public.mac_protect_vocab_word_identity() returns trigger language plpgsql security invoker set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    if old.publication_status in ('certified','published','deprecated','withdrawn') then raise exception 'certified vocabulary records cannot be hard deleted' using errcode='23514'; end if;
    return old;
  end if;
  if new.id is distinct from old.id then raise exception 'vocabulary record id is immutable' using errcode='23514'; end if;
  if old.publication_status in ('certified','published','deprecated','withdrawn') then
    if new.publication_status in ('draft','in_review','verified') then raise exception 'certified vocabulary lifecycle cannot be downgraded' using errcode='23514'; end if;
    if new.canonical_code is distinct from old.canonical_code or new.ownership_scope is distinct from old.ownership_scope or new.organization_id is distinct from old.organization_id then raise exception 'certified vocabulary identity ownership is immutable' using errcode='23514'; end if;
  end if;
  return new;
end; $$;
revoke all on function public.mac_protect_vocab_word_identity() from public;
grant execute on function public.mac_protect_vocab_word_identity() to service_role;

create or replace function public.mac_protect_vocab_sense_identity() returns trigger language plpgsql security invoker set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    if old.publication_status in ('certified','published','deprecated','withdrawn') then raise exception 'certified vocabulary records cannot be hard deleted' using errcode='23514'; end if;
    return old;
  end if;
  if new.id is distinct from old.id then raise exception 'vocabulary record id is immutable' using errcode='23514'; end if;
  if old.publication_status in ('certified','published','deprecated','withdrawn') then
    if new.publication_status in ('draft','in_review','verified') then raise exception 'certified vocabulary lifecycle cannot be downgraded' using errcode='23514'; end if;
    if new.word_id is distinct from old.word_id then raise exception 'certified vocabulary sense word ownership is immutable' using errcode='23514'; end if;
  end if;
  return new;
end; $$;
revoke all on function public.mac_protect_vocab_sense_identity() from public;
grant execute on function public.mac_protect_vocab_sense_identity() to service_role;
create trigger vocab_words_protect_identity before update or delete on public.vocab_words for each row execute function public.mac_protect_vocab_word_identity();
create trigger vocab_senses_protect_identity before update or delete on public.vocab_senses for each row execute function public.mac_protect_vocab_sense_identity();

alter table public.vocab_words enable row level security;
alter table public.vocab_senses enable row level security;
revoke all on table public.vocab_words from anon, authenticated;
revoke all on table public.vocab_senses from anon, authenticated;
grant select on table public.vocab_words to authenticated;
grant select on table public.vocab_senses to authenticated;
grant select, insert, update, delete on table public.vocab_words to service_role;
grant select, insert, update, delete on table public.vocab_senses to service_role;

create policy "published vocabulary readable in authorized scope" on public.vocab_words for select to authenticated using (
 publication_status='published' and (ownership_scope='platform_canonical' or public.mac_is_platform_admin() or (ownership_scope='tenant_extension' and exists (select 1 from public.mac_current_user_roles() role_scope where role_scope.organization_id=vocab_words.organization_id)))
);
create policy "published senses follow visible word scope" on public.vocab_senses for select to authenticated using (
 publication_status='published' and exists (select 1 from public.vocab_words word where word.id=vocab_senses.word_id and word.publication_status='published' and (word.ownership_scope='platform_canonical' or public.mac_is_platform_admin() or (word.ownership_scope='tenant_extension' and exists (select 1 from public.mac_current_user_roles() role_scope where role_scope.organization_id=word.organization_id))))
);
comment on table public.vocab_words is 'Vocabulary Studio canonical Core Word Records. Platform canonical rows are global; tenant extensions are organization-owned.';
comment on table public.vocab_senses is 'Vocabulary Studio Sense Records. Sense-specific evidence must reference the applicable sense when meaning materially differs.';
