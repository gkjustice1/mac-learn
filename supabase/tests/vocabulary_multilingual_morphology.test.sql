begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(73);

-- ============================================================
-- MAC Learn Vocabulary Studio
-- VS-E01-US02: Multilingual Forms + Morphology Foundation
-- pgTAP contract
-- ============================================================


-- ============================================================
-- 1. Schema existence
-- ============================================================

select has_table(
  'public',
  'vocab_language_forms',
  'vocab_language_forms table exists'
);

select has_table(
  'public',
  'vocab_morphemes',
  'vocab_morphemes table exists'
);

select has_table(
  'public',
  'vocab_word_morphemes',
  'vocab_word_morphemes table exists'
);

select has_function(
  'public',
  'mac_protect_vocab_us02_record',
  array[]::text[],
  'US02 lifecycle protection function exists'
);


-- ============================================================
-- 2. Critical columns
-- ============================================================

select has_column(
  'public',
  'vocab_language_forms',
  'word_id',
  'language forms reference canonical words'
);

select has_column(
  'public',
  'vocab_language_forms',
  'sense_id',
  'language forms may be sense-specific'
);

select has_column(
  'public',
  'vocab_language_forms',
  'normalized_form',
  'language forms have normalized identity'
);

select has_column(
  'public',
  'vocab_morphemes',
  'canonical_code',
  'morphemes have canonical codes'
);

select has_column(
  'public',
  'vocab_morphemes',
  'morpheme_type',
  'morphemes have controlled type'
);

select has_column(
  'public',
  'vocab_word_morphemes',
  'sequence_order',
  'word morphology preserves ordered composition'
);


-- ============================================================
-- 3. RLS enabled
-- ============================================================

select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.vocab_language_forms'::regclass
  ),
  true,
  'RLS enabled on vocab_language_forms'
);

select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.vocab_morphemes'::regclass
  ),
  true,
  'RLS enabled on vocab_morphemes'
);

select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.vocab_word_morphemes'::regclass
  ),
  true,
  'RLS enabled on vocab_word_morphemes'
);


-- ============================================================
-- 4. Direct privilege contract
-- ============================================================

select is(
  has_table_privilege(
    'anon',
    'public.vocab_language_forms',
    'SELECT'
  ),
  false,
  'anon cannot directly read language forms'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.vocab_language_forms',
    'SELECT'
  ),
  true,
  'authenticated may SELECT language forms subject to RLS'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.vocab_language_forms',
    'INSERT'
  ),
  false,
  'authenticated cannot directly insert language forms'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.vocab_morphemes',
    'UPDATE'
  ),
  false,
  'authenticated cannot directly update morphemes'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.vocab_word_morphemes',
    'DELETE'
  ),
  false,
  'authenticated cannot directly delete morphology links'
);

select is(
  has_table_privilege(
    'service_role',
    'public.vocab_language_forms',
    'INSERT'
  ),
  true,
  'service_role may insert language forms'
);

select is(
  has_table_privilege(
    'service_role',
    'public.vocab_morphemes',
    'UPDATE'
  ),
  true,
  'service_role may update morphemes'
);

select is(
  has_table_privilege(
    'service_role',
    'public.vocab_word_morphemes',
    'DELETE'
  ),
  true,
  'service_role may delete eligible morphology links'
);


-- ============================================================
-- 5. Fixture data
-- ============================================================

-- Identity fixtures use the test runner, matching US01. The service role
-- intentionally does not have blanket DML privileges on enterprise tables.

insert into auth.users (id, email)
values
  (
    '91000000-0000-4000-8000-000000000001',
    'vs-us02-user-a@example.test'
  ),
  (
    '91000000-0000-4000-8000-000000000002',
    'vs-us02-user-b@example.test'
  ),
  (
    '91000000-0000-4000-8000-000000000003',
    'vs-us02-platform-admin@example.test'
  );

insert into public.users (id, account_status)
values
  (
    '91000000-0000-4000-8000-000000000001',
    'active'
  ),
  (
    '91000000-0000-4000-8000-000000000002',
    'active'
  ),
  (
    '91000000-0000-4000-8000-000000000003',
    'active'
  );

insert into public.organizations (id, name, slug)
values
  (
    '92000000-0000-4000-8000-000000000001',
    'VS US02 Organization A',
    'vs-us02-org-a'
  ),
  (
    '92000000-0000-4000-8000-000000000002',
    'VS US02 Organization B',
    'vs-us02-org-b'
  );

insert into public.role_assignments (
  user_id,
  role_key,
  organization_id,
  status
)
values
  (
    '91000000-0000-4000-8000-000000000001',
    'student',
    '92000000-0000-4000-8000-000000000001',
    'active'
  ),
  (
    '91000000-0000-4000-8000-000000000002',
    'student',
    '92000000-0000-4000-8000-000000000002',
    'active'
  ),
  (
    '91000000-0000-4000-8000-000000000003',
    'platform_admin',
    null,
    'active'
  );

set local role service_role;

insert into public.vocab_words (
  id,
  canonical_code,
  ownership_scope,
  organization_id,
  lemma,
  display_word,
  language_code,
  primary_part_of_speech,
  student_definition,
  publication_status
)
values
  (
    '93000000-0000-4000-8000-000000000001',
    'VS-US02-PLATFORM-000001',
    'platform_canonical',
    null,
    'transform',
    'Transform',
    'en',
    'verb',
    'To change form.',
    'published'
  ),
  (
    '93000000-0000-4000-8000-000000000002',
    'VS-US02-TENANT-A-000001',
    'tenant_extension',
    '92000000-0000-4000-8000-000000000001',
    'localform',
    'Localform',
    'en',
    'noun',
    'A tenant A vocabulary record.',
    'published'
  ),
  (
    '93000000-0000-4000-8000-000000000003',
    'VS-US02-TENANT-B-000001',
    'tenant_extension',
    '92000000-0000-4000-8000-000000000002',
    'otherform',
    'Otherform',
    'en',
    'noun',
    'A tenant B vocabulary record.',
    'published'
  );

insert into public.vocab_senses (
  id,
  word_id,
  sense_key,
  sense_number,
  student_definition,
  discipline_scope,
  publication_status
)
values
  (
    '94000000-0000-4000-8000-000000000001',
    '93000000-0000-4000-8000-000000000001',
    'change-form',
    1,
    'To change the form of something.',
    'general',
    'published'
  ),
  (
    '94000000-0000-4000-8000-000000000002',
    '93000000-0000-4000-8000-000000000002',
    'tenant-a-sense',
    1,
    'Tenant A meaning.',
    'general',
    'published'
  ),
  (
    '94000000-0000-4000-8000-000000000003',
    '93000000-0000-4000-8000-000000000003',
    'tenant-b-sense',
    1,
    'Tenant B meaning.',
    'general',
    'published'
  );

insert into public.vocab_morphemes (
  id,
  canonical_code,
  morpheme,
  language_code,
  morpheme_type,
  core_meaning,
  publication_status
)
values
  (
    '95000000-0000-4000-8000-000000000001',
    'MORPH-TRANS-001',
    'trans',
    'en',
    'prefix',
    'across or change',
    'published'
  ),
  (
    '95000000-0000-4000-8000-000000000002',
    'MORPH-FORM-001',
    'form',
    'en',
    'root',
    'shape or form',
    'published'
  );

insert into public.vocab_language_forms (
  id,
  word_id,
  sense_id,
  language_code,
  form_text,
  form_type,
  publication_status,
  review_status,
  reviewed_by,
  reviewed_at
)
values
  (
    '96000000-0000-4000-8000-000000000001',
    '93000000-0000-4000-8000-000000000001',
    '94000000-0000-4000-8000-000000000001',
    'es',
    'transformar',
    'translation',
    'published',
    'verified',
    '91000000-0000-4000-8000-000000000003',
    now()
  ),
  (
    '96000000-0000-4000-8000-000000000002',
    '93000000-0000-4000-8000-000000000002',
    '94000000-0000-4000-8000-000000000002',
    'es',
    'forma local',
    'translation',
    'published',
    'verified',
    '91000000-0000-4000-8000-000000000003',
    now()
  ),
  (
    '96000000-0000-4000-8000-000000000003',
    '93000000-0000-4000-8000-000000000003',
    '94000000-0000-4000-8000-000000000003',
    'es',
    'otra forma',
    'translation',
    'published',
    'verified',
    '91000000-0000-4000-8000-000000000003',
    now()
  );

insert into public.vocab_word_morphemes (
  id,
  word_id,
  sense_id,
  morpheme_id,
  sequence_order,
  surface_form,
  relationship_type,
  publication_status
)
values
  (
    '97000000-0000-4000-8000-000000000001',
    '93000000-0000-4000-8000-000000000001',
    '94000000-0000-4000-8000-000000000001',
    '95000000-0000-4000-8000-000000000001',
    1,
    'trans',
    'prefix_component',
    'published'
  ),
  (
    '97000000-0000-4000-8000-000000000002',
    '93000000-0000-4000-8000-000000000001',
    '94000000-0000-4000-8000-000000000001',
    '95000000-0000-4000-8000-000000000002',
    2,
    'form',
    'root_component',
    'published'
  );


-- ============================================================
-- 6. Normalization + validation
-- ============================================================

select is(
  (
    select normalized_form
    from public.vocab_language_forms
    where id = '96000000-0000-4000-8000-000000000001'
  ),
  'transformar',
  'language form normalization is deterministic'
);

select is(
  (
    select normalized_morpheme
    from public.vocab_morphemes
    where id = '95000000-0000-4000-8000-000000000001'
  ),
  'trans',
  'morpheme normalization is deterministic'
);

select throws_ok(
  $$
    insert into public.vocab_language_forms (
      word_id,
      language_code,
      form_text,
      form_type
    )
    values (
      '93000000-0000-4000-8000-000000000001',
      'EN_us',
      'bad locale',
      'translation'
    )
  $$,
  '23514',
  null,
  'invalid language codes are rejected'
);

select throws_ok(
  $$
    insert into public.vocab_word_morphemes (
      word_id,
      morpheme_id,
      sequence_order,
      relationship_type
    )
    values (
      '93000000-0000-4000-8000-000000000001',
      '95000000-0000-4000-8000-000000000001',
      0,
      'prefix_component'
    )
  $$,
  '23514',
  null,
  'morphology sequence must be greater than zero'
);


-- ============================================================
-- 7. Sense / word integrity
-- ============================================================

select throws_ok(
  $$
    insert into public.vocab_language_forms (
      word_id,
      sense_id,
      language_code,
      form_text,
      form_type
    )
    values (
      '93000000-0000-4000-8000-000000000002',
      '94000000-0000-4000-8000-000000000001',
      'es',
      'mismatch',
      'translation'
    )
  $$,
  '23503',
  null,
  'language form cannot attach a sense belonging to another word'
);

select throws_ok(
  $$
    insert into public.vocab_word_morphemes (
      word_id,
      sense_id,
      morpheme_id,
      sequence_order,
      relationship_type
    )
    values (
      '93000000-0000-4000-8000-000000000002',
      '94000000-0000-4000-8000-000000000001',
      '95000000-0000-4000-8000-000000000001',
      1,
      'prefix_component'
    )
  $$,
  '23503',
  null,
  'morphology link cannot attach a sense belonging to another word'
);


-- ============================================================
-- 8. Duplicate protection
-- ============================================================

select throws_ok(
  $$
    insert into public.vocab_language_forms (
      word_id,
      sense_id,
      language_code,
      form_text,
      form_type
    )
    values (
      '93000000-0000-4000-8000-000000000001',
      '94000000-0000-4000-8000-000000000001',
      'es',
      ' TRANSFORMAR ',
      'translation'
    )
  $$,
  '23505',
  null,
  'normalized duplicate language forms are rejected'
);

select lives_ok(
  $$
    insert into public.vocab_word_morphemes (
      id,
      word_id,
      morpheme_id,
      sequence_order,
      relationship_type,
      publication_status
    )
    values (
      '97000000-0000-4000-8000-000000000010',
      '93000000-0000-4000-8000-000000000002',
      '95000000-0000-4000-8000-000000000001',
      1,
      'prefix_component',
      'draft'
    )
  $$,
  'first word-level morphology position may be inserted'
);

select throws_ok(
  $$
    insert into public.vocab_word_morphemes (
      word_id,
      morpheme_id,
      sequence_order,
      relationship_type,
      publication_status
    )
    values (
      '93000000-0000-4000-8000-000000000002',
      '95000000-0000-4000-8000-000000000001',
      1,
      'prefix_component',
      'draft'
    )
  $$,
  '23505',
  null,
  'duplicate word-level morphology position is rejected even when sense_id is null'
);


-- ============================================================
-- 9. Translation governance
-- ============================================================

select throws_ok(
  $$
    insert into public.vocab_language_forms (
      word_id,
      language_code,
      form_text,
      form_type,
      publication_status,
      review_status
    )
    values (
      '93000000-0000-4000-8000-000000000001',
      'ht',
      'transfome',
      'translation',
      'published',
      'unreviewed'
    )
  $$,
  '23514',
  null,
  'published translation cannot remain unreviewed'
);


-- ============================================================
-- 10. Certified lifecycle protection
-- ============================================================

insert into public.vocab_morphemes (
  id,
  canonical_code,
  morpheme,
  language_code,
  morpheme_type,
  publication_status
)
values (
  '95000000-0000-4000-8000-000000000010',
  'MORPH-CERTIFIED-001',
  'cert',
  'en',
  'root',
  'certified'
);

select throws_ok(
  $$
    update public.vocab_morphemes
    set canonical_code = 'MORPH-CHANGED-001'
    where id = '95000000-0000-4000-8000-000000000010'
  $$,
  '23514',
  'certified vocabulary morpheme identity is immutable',
  'certified morpheme identity cannot be changed'
);

select throws_ok(
  $$
    update public.vocab_morphemes
    set publication_status = 'draft'
    where id = '95000000-0000-4000-8000-000000000010'
  $$,
  '23514',
  'certified vocabulary lifecycle cannot be downgraded',
  'certified morpheme lifecycle cannot be downgraded'
);

select throws_ok(
  $$
    delete from public.vocab_morphemes
    where id = '95000000-0000-4000-8000-000000000010'
  $$,
  '23514',
  'certified vocabulary records cannot be hard deleted',
  'certified morpheme cannot be hard deleted'
);


-- ============================================================
-- 11. RLS visibility
-- ============================================================

reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"91000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

set local role authenticated;

select is(
  (
    select count(*)
    from public.vocab_language_forms
    where id = '96000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'authenticated tenant user can read published platform language forms'
);

select is(
  (
    select count(*)
    from public.vocab_language_forms
    where id = '96000000-0000-4000-8000-000000000002'
  ),
  1::bigint,
  'tenant A user can read tenant A language forms'
);

select is(
  (
    select count(*)
    from public.vocab_language_forms
    where id = '96000000-0000-4000-8000-000000000003'
  ),
  0::bigint,
  'tenant A user cannot read tenant B language forms'
);

select is(
  (
    select count(*)
    from public.vocab_morphemes
    where id = '95000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'published morpheme is readable through a visible published vocabulary link'
);

select is(
  (
    select count(*)
    from public.vocab_word_morphemes
    where word_id = '93000000-0000-4000-8000-000000000001'
  ),
  2::bigint,
  'published morphology links are readable through visible platform vocabulary'
);


-- ============================================================
-- 12. No Story 30 seed
-- ============================================================

reset role;
set local role service_role;

select is(
  (
    select count(*)
    from public.vocab_words
    where upper(lemma) in (
      'PROTOTYPE',
      'FORCE',
      'FRICTION',
      'MODIFY'
    )
  ),
  0::bigint,
  'VS-E01-US02 contains no Story 30 vocabulary seed'
);


-- Additional boundary and authorization regression coverage.
select throws_ok($$insert into public.vocab_word_morphemes
(word_id,morpheme_id,sequence_order,relationship_type) values
('93000000-0000-4000-8000-000000000002','95000000-0000-4000-8000-000000000002',1,'root_component')$$,
'23505',null,'different morphemes cannot occupy the same word-level position');
select throws_ok($$insert into public.vocab_word_morphemes
(word_id,sense_id,morpheme_id,sequence_order,relationship_type) values
('93000000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000001','95000000-0000-4000-8000-000000000002',1,'root_component')$$,
'23505',null,'different morphemes cannot occupy the same sense-level position');
select throws_ok($$update public.vocab_language_forms set review_status='unreviewed'
where id='96000000-0000-4000-8000-000000000001'$$,
'23514',null,'published forms cannot lose verified review');
select throws_ok($$insert into public.vocab_language_forms
(word_id,language_code,form_text,form_type,publication_status,review_status)
values ('93000000-0000-4000-8000-000000000001','ht','transfome','translation','certified','unreviewed')$$,
'23514',null,'certified translations require verified review');
select throws_ok($$insert into public.vocab_language_forms
(word_id,language_code,form_text,form_type,review_status)
values ('93000000-0000-4000-8000-000000000001','ht','transfome','translation','verified')$$,
'23514',null,'verified translations require reviewer and timestamp');

insert into public.vocab_language_forms
(id,word_id,language_code,form_text,form_type)
values ('96000000-0000-4000-8000-000000000010','93000000-0000-4000-8000-000000000001','ht','transfome','translation');
select throws_ok($$update public.vocab_language_forms set publication_status='published'
where id='96000000-0000-4000-8000-000000000010'$$,
'23514',null,'draft translation cannot be published without review');
select lives_ok($$update public.vocab_language_forms set publication_status='published',
review_status='verified',reviewed_by='91000000-0000-4000-8000-000000000003',reviewed_at=now()
where id='96000000-0000-4000-8000-000000000010'$$,
'publication succeeds with complete verified review');

insert into public.vocab_words
(id,canonical_code,lemma,display_word,primary_part_of_speech,publication_status)
values ('93000000-0000-4000-8000-000000000010','VS-US02-DRAFT','draftparent','Draftparent','noun','draft');
insert into public.vocab_senses
(id,word_id,sense_key,sense_number,student_definition,publication_status)
values ('94000000-0000-4000-8000-000000000010','93000000-0000-4000-8000-000000000001','draft-sense',2,'Draft sense','draft');
insert into public.vocab_morphemes (id,canonical_code,morpheme,morpheme_type,publication_status) values
('95000000-0000-4000-8000-000000000020','MORPH-A','tenant-a','root','published'),
('95000000-0000-4000-8000-000000000021','MORPH-B','tenant-b','root','published'),
('95000000-0000-4000-8000-000000000022','MORPH-DRAFT-PARENT','draft-parent','root','published'),
('95000000-0000-4000-8000-000000000023','MORPH-DRAFT-SENSE','draft-sense','root','published'),
('95000000-0000-4000-8000-000000000024','MORPH-UNLINKED','unlinked','root','published'),
('95000000-0000-4000-8000-000000000025','MORPH-DRAFT-LINK','draft-link','root','published');
insert into public.vocab_word_morphemes
(id,word_id,sense_id,morpheme_id,sequence_order,relationship_type,publication_status) values
('97000000-0000-4000-8000-000000000020','93000000-0000-4000-8000-000000000002',null,'95000000-0000-4000-8000-000000000020',2,'root_component','published'),
('97000000-0000-4000-8000-000000000021','93000000-0000-4000-8000-000000000003',null,'95000000-0000-4000-8000-000000000021',1,'root_component','published'),
('97000000-0000-4000-8000-000000000022','93000000-0000-4000-8000-000000000010',null,'95000000-0000-4000-8000-000000000022',1,'root_component','published'),
('97000000-0000-4000-8000-000000000023','93000000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000010','95000000-0000-4000-8000-000000000023',1,'root_component','published'),
('97000000-0000-4000-8000-000000000025','93000000-0000-4000-8000-000000000001',null,'95000000-0000-4000-8000-000000000025',1,'root_component','draft');
insert into public.vocab_language_forms
(id,word_id,sense_id,language_code,form_text,form_type,publication_status,review_status,reviewed_by,reviewed_at) values
('96000000-0000-4000-8000-000000000020','93000000-0000-4000-8000-000000000010',null,'es','draft parent translation','translation','published','verified','91000000-0000-4000-8000-000000000003',now()),
('96000000-0000-4000-8000-000000000021','93000000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000010','es','draft sense translation','translation','published','verified','91000000-0000-4000-8000-000000000003',now());

reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is((select count(*) from public.vocab_word_morphemes where id='97000000-0000-4000-8000-000000000020'),1::bigint,'tenant A sees its own published morphology link');
select is((select count(*) from public.vocab_word_morphemes where id='97000000-0000-4000-8000-000000000021'),0::bigint,'tenant A cannot see tenant B morphology link');
select is((select count(*) from public.vocab_morphemes where id='95000000-0000-4000-8000-000000000020'),1::bigint,'tenant A sees morpheme used by its visible link');
select is((select count(*) from public.vocab_morphemes where id='95000000-0000-4000-8000-000000000021'),0::bigint,'tenant A cannot see morpheme used only by tenant B');
select is((select count(*) from public.vocab_word_morphemes where id in ('97000000-0000-4000-8000-000000000022','97000000-0000-4000-8000-000000000023','97000000-0000-4000-8000-000000000025')),0::bigint,'draft parent, sense and link hide morphology links');
select is((select count(*) from public.vocab_morphemes where id in ('95000000-0000-4000-8000-000000000022','95000000-0000-4000-8000-000000000023','95000000-0000-4000-8000-000000000024','95000000-0000-4000-8000-000000000025')),0::bigint,'unlinked morphemes and morphemes with only invisible links are hidden');
select is((select count(*) from public.vocab_language_forms where id in ('96000000-0000-4000-8000-000000000020','96000000-0000-4000-8000-000000000021')),0::bigint,'draft parent and sense hide published translations');
select throws_ok($$delete from public.vocab_word_morphemes where id='97000000-0000-4000-8000-000000000020'$$,'42501',null,'authenticated cannot directly delete a visible morphology link');
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is((select count(*) from public.vocab_morphemes where id='95000000-0000-4000-8000-000000000021'),1::bigint,'tenant B sees its own linked morpheme');
select is((select count(*) from public.vocab_word_morphemes where id='97000000-0000-4000-8000-000000000020'),0::bigint,'tenant B cannot see tenant A morphology link');
reset role;

select results_eq(
$$select c.relname::text collate "C", coalesce(r.rolname::text,'PUBLIC') collate "C", a.privilege_type::text collate "C"
from pg_class c join pg_namespace n on n.oid=c.relnamespace
cross join lateral aclexplode(c.relacl) a left join pg_roles r on r.oid=a.grantee
where n.nspname='public' and c.relname in ('vocab_language_forms','vocab_morphemes','vocab_word_morphemes')
and a.grantee <> c.relowner order by 1,2,3$$,
$$select t collate "C", r collate "C", p collate "C" from
(values ('vocab_language_forms'),('vocab_morphemes'),('vocab_word_morphemes')) tables(t)
cross join (values ('authenticated','SELECT'),('service_role','SELECT'),('service_role','INSERT'),('service_role','UPDATE'),('service_role','DELETE'),('service_role','MAINTAIN')) grants(r,p)
order by 1,2,3$$,
'exact non-owner ACLs exclude anonymous access, truncate and unexpected grants');

select throws_ok($$delete from public.users
where id='91000000-0000-4000-8000-000000000003'$$,
'23503',null,'reviewer deletion is explicitly restricted while attribution is referenced');
select throws_ok($$delete from auth.users
where id='91000000-0000-4000-8000-000000000003'$$,
'23503',null,'Auth user deletion cannot cascade away referenced review attribution');

select throws_ok($$update public.vocab_language_forms set form_text='unreviewed replacement'
where id='96000000-0000-4000-8000-000000000001'$$,
'23514','certified vocabulary language-form identity is immutable','published translation text cannot inherit an earlier review');
select throws_ok($$update public.vocab_morphemes set morpheme='replacement'
where id='95000000-0000-4000-8000-000000000010'$$,
'23514','certified vocabulary morpheme identity is immutable','certified morpheme text is immutable');
select throws_ok($$update public.vocab_morphemes set morpheme='replacement'
where id='95000000-0000-4000-8000-000000000001'$$,
'23514','certified vocabulary morpheme identity is immutable','published linked morpheme text is immutable');
insert into public.vocab_morphemes(id,canonical_code,morpheme,morpheme_type)
values ('95000000-0000-4000-8000-000000000030','MORPH-UNPUBLISHED','unpublished','root');
select throws_ok($$insert into public.vocab_word_morphemes
(word_id,morpheme_id,sequence_order,relationship_type,publication_status) values
('93000000-0000-4000-8000-000000000001','95000000-0000-4000-8000-000000000030',3,'root_component','published')$$,
'23514','published morphology links require a published morpheme','unpublished units cannot receive published links');
select lives_ok($$insert into public.vocab_word_morphemes
(id,word_id,morpheme_id,sequence_order,relationship_type) values
('97000000-0000-4000-8000-000000000030','93000000-0000-4000-8000-000000000001','95000000-0000-4000-8000-000000000030',3,'root_component')$$,
'draft composition can reference a draft unit');
select throws_ok($$update public.vocab_word_morphemes set publication_status='published'
where id='97000000-0000-4000-8000-000000000030'$$,
'23514','published morphology links require a published morpheme','publishing a draft link requires a published unit');
select throws_ok($$update public.vocab_morphemes set publication_status='deprecated'
where id='95000000-0000-4000-8000-000000000001'$$,
'23514','published morphology links require a published morpheme','a unit cannot be hidden while published links reference it');
select ok(not has_function_privilege('anon','public.mac_require_published_morpheme()','EXECUTE')
and not has_function_privilege('authenticated','public.mac_require_published_morpheme()','EXECUTE')
and has_function_privilege('service_role','public.mac_require_published_morpheme()','EXECUTE'),
'publication consistency trigger helper has restricted EXECUTE permissions');

insert into public.vocab_language_forms
(id,word_id,language_code,form_text,form_type,review_status,reviewed_by,reviewed_at)
values ('96000000-0000-4000-8000-000000000040',
'93000000-0000-4000-8000-000000000001','es','reviewed draft','translation',
'verified','91000000-0000-4000-8000-000000000003',now());
select throws_ok($$update public.vocab_language_forms set form_text='changed'
where id='96000000-0000-4000-8000-000000000040'$$,
'23514','verified vocabulary language-form content requires a new review','verified draft text is protected');
update public.vocab_language_forms set publication_status='in_review'
where id='96000000-0000-4000-8000-000000000040';
select throws_ok($$update public.vocab_language_forms set locale_code='es'
where id='96000000-0000-4000-8000-000000000040'$$,
'23514','verified vocabulary language-form content requires a new review','reviewed identity is protected while in review');
update public.vocab_language_forms set publication_status='verified'
where id='96000000-0000-4000-8000-000000000040';
select throws_ok($$update public.vocab_language_forms set form_text='changed',publication_status='published'
where id='96000000-0000-4000-8000-000000000040'$$,
'23514','verified vocabulary language-form content requires a new review','editing and publishing together cannot reuse verification');
select throws_ok($$update public.vocab_language_forms set form_text='changed',review_status='unreviewed'
where id='96000000-0000-4000-8000-000000000040'$$,
'23514','verified vocabulary language-form content requires a new review','same-update review reset cannot bypass the content guard');
select lives_ok($$update public.vocab_language_forms set publication_status='published'
where id='96000000-0000-4000-8000-000000000040'$$,
'unchanged reviewed content can be published');

select * from finish();

rollback;
