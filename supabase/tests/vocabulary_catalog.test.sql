begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(28);

select has_index('public', 'vocab_words', 'vocab_words_created_by_idx', 'Core Word created_by FK has a covering index');
select has_index('public', 'vocab_words', 'vocab_words_updated_by_idx', 'Core Word updated_by FK has a covering index');
select has_index('public', 'vocab_senses', 'vocab_senses_created_by_idx', 'Sense created_by FK has a covering index');
select has_index('public', 'vocab_senses', 'vocab_senses_updated_by_idx', 'Sense updated_by FK has a covering index');

insert into auth.users (id, email)
values
  ('81000000-0000-4000-8000-000000000001', 'vocab-org-a@example.test'),
  ('81000000-0000-4000-8000-000000000002', 'vocab-org-b@example.test'),
  ('81000000-0000-4000-8000-000000000003', 'vocab-student@example.test'),
  ('81000000-0000-4000-8000-000000000004', 'vocab-platform-admin@example.test');
insert into public.users (id, account_status) select id, 'active' from auth.users where id in ('81000000-0000-4000-8000-000000000001','81000000-0000-4000-8000-000000000002','81000000-0000-4000-8000-000000000003','81000000-0000-4000-8000-000000000004');
insert into public.organizations (id,name,slug) values ('82000000-0000-4000-8000-000000000001','Vocabulary Organization A','vocabulary-organization-a'),('82000000-0000-4000-8000-000000000002','Vocabulary Organization B','vocabulary-organization-b');
insert into public.role_assignments (user_id,role_key,organization_id,status) values ('81000000-0000-4000-8000-000000000001','organization_admin','82000000-0000-4000-8000-000000000001','active'),('81000000-0000-4000-8000-000000000002','organization_admin','82000000-0000-4000-8000-000000000002','active'),('81000000-0000-4000-8000-000000000003','student','82000000-0000-4000-8000-000000000001','active'),('81000000-0000-4000-8000-000000000004','platform_admin',null,'active');
set local role service_role;
insert into public.vocab_words (id,canonical_code,ownership_scope,organization_id,lemma,display_word,primary_part_of_speech,student_definition,publication_status) values
('83000000-0000-4000-8000-000000000001','VS-EN-TEST-000001','platform_canonical',null,'testword','Testword','noun','A published platform vocabulary test word.','published'),
('83000000-0000-4000-8000-000000000002','VS-EN-DRAFT-000001','platform_canonical',null,'draftword','Draftword','noun','A draft vocabulary test word.','draft'),
('83000000-0000-4000-8000-000000000003','VS-TENANT-A-000001','tenant_extension','82000000-0000-4000-8000-000000000001','localword','Localword','noun','A tenant A vocabulary extension.','published'),
('83000000-0000-4000-8000-000000000004','VS-TENANT-B-000001','tenant_extension','82000000-0000-4000-8000-000000000002','localword','Localword','noun','A tenant B vocabulary extension.','published');
insert into public.vocab_senses (id,word_id,sense_key,sense_number,student_definition,discipline_scope,publication_status) values
('84000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000001','general',1,'The first published meaning.','general','published'),
('84000000-0000-4000-8000-000000000002','83000000-0000-4000-8000-000000000001','disciplinary',2,'A second published meaning.','science','published'),
('84000000-0000-4000-8000-000000000003','83000000-0000-4000-8000-000000000002','draft',1,'A draft meaning.','general','draft'),
('84000000-0000-4000-8000-000000000004','83000000-0000-4000-8000-000000000003','tenant',1,'A tenant A meaning.','general','published');
select is((select count(*) from public.vocab_senses where word_id='83000000-0000-4000-8000-000000000001'),2::bigint,'a Core Word Record can own multiple Sense Records');
select throws_ok($$insert into public.vocab_words(canonical_code,lemma,display_word,primary_part_of_speech,publication_status) values('VS-EN-TEST-000002',' TESTWORD ','Testword Duplicate','NOUN','draft')$$,'23505',null,'platform canonical duplicate identity is rejected after normalization');
select throws_ok($$insert into public.vocab_words(canonical_code,lemma,display_word,primary_part_of_speech,publication_status) values('VS-EN-TEST-000004','testword','Testword POS Whitespace',' noun ','draft')$$,'23505',null,'part of speech whitespace cannot bypass normalized duplicate identity');
select throws_ok($$insert into public.vocab_words(canonical_code,lemma,display_word,primary_part_of_speech,lexical_identity_key,publication_status) values('VS-EN-TEST-000005','testword','Testword Key Whitespace','noun',' default ','draft')$$,'23505',null,'lexical identity key whitespace cannot bypass normalized duplicate identity');
select lives_ok($$insert into public.vocab_words(canonical_code,lemma,display_word,primary_part_of_speech,lexical_identity_key,publication_status) values('VS-EN-TEST-000003','testword','Testword Homograph','noun','homograph-2','draft')$$,'a distinct lexical identity key permits a legitimate homograph');
select throws_ok($$insert into public.vocab_words(canonical_code,ownership_scope,lemma,display_word,primary_part_of_speech) values('VS-TENANT-BAD-000001','tenant_extension','badtenant','Badtenant','noun')$$,'23514',null,'tenant vocabulary requires organization ownership');
select throws_ok($$update public.vocab_words set canonical_code='VS-EN-CHANGED-000001' where id='83000000-0000-4000-8000-000000000001'$$,'23514','certified vocabulary identity ownership is immutable','published canonical code is immutable');
select throws_ok($$update public.vocab_senses set word_id='83000000-0000-4000-8000-000000000002' where id='84000000-0000-4000-8000-000000000001'$$,'23514','certified vocabulary sense word ownership is immutable','published Sense Record cannot be reassigned to another Core Word Record');
select throws_ok($$update public.vocab_words set publication_status='draft' where id='83000000-0000-4000-8000-000000000001'$$,'23514','certified vocabulary lifecycle cannot be downgraded','published Core Word Record cannot be downgraded to unlock its identity');
select throws_ok($$update public.vocab_senses set publication_status='draft' where id='84000000-0000-4000-8000-000000000001'$$,'23514','certified vocabulary lifecycle cannot be downgraded','published Sense Record cannot be downgraded to unlock its parent identity');
select throws_ok($$delete from public.vocab_words where id='83000000-0000-4000-8000-000000000001'$$,'23514','certified vocabulary records cannot be hard deleted','published Core Word Record cannot be hard deleted');
select throws_ok($$delete from public.vocab_senses where id='84000000-0000-4000-8000-000000000001'$$,'23514','certified vocabulary records cannot be hard deleted','published Sense Record cannot be hard deleted');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"81000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is((select count(*) from public.vocab_words),2::bigint,'organization A sees published platform vocabulary and its own published extension only');
select is((select count(*) from public.vocab_words where ownership_scope='platform_canonical'),1::bigint,'draft platform vocabulary is hidden from authenticated readers');
select is((select count(*) from public.vocab_words where organization_id='82000000-0000-4000-8000-000000000002'),0::bigint,'organization A cannot read organization B vocabulary extensions');
select is((select count(*) from public.vocab_senses where word_id='83000000-0000-4000-8000-000000000001'),2::bigint,'published Sense Records for visible platform vocabulary are readable');
select ok(not has_table_privilege(current_user,'public.vocab_words','INSERT'),'authenticated users have no direct INSERT privilege on Core Word Records');
select ok(not has_table_privilege(current_user,'public.vocab_words','UPDATE'),'authenticated users have no direct UPDATE privilege on Core Word Records');
select ok(not has_table_privilege(current_user,'public.vocab_senses','DELETE'),'authenticated users have no direct DELETE privilege on Sense Records');
select throws_ok($$insert into public.vocab_words(canonical_code,lemma,display_word,primary_part_of_speech) values('VS-UNAUTHORIZED-000001','unauthorized','Unauthorized','adjective')$$,'42501','permission denied for table vocab_words','authenticated direct vocabulary creation is denied');
select set_config('request.jwt.claims','{"sub":"81000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is((select count(*) from public.vocab_words where ownership_scope='tenant_extension'),1::bigint,'organization B sees only its own tenant vocabulary extension');
select set_config('request.jwt.claims','{"sub":"81000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
select is((select count(*) from public.vocab_words where ownership_scope='tenant_extension'),2::bigint,'platform administrator sees published tenant vocabulary across organizations');
select is((select count(*) from public.vocab_senses where id='84000000-0000-4000-8000-000000000004'),1::bigint,'platform administrator sees published tenant vocabulary senses');
set local role anon;
select is(has_table_privilege(current_user,'public.vocab_words','SELECT'),false,'anonymous users cannot read the vocabulary catalog directly');
select * from finish();
rollback;
