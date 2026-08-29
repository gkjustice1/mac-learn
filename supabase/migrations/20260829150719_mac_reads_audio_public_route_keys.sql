alter table public.mac_reads_audio_assets
  add column if not exists grade_slug text,
  add column if not exists lesson_slug text;

update public.mac_reads_audio_assets
set grade_slug = 'g4', lesson_slug = 'rb001'
where lesson_id = 'MACR-G4-RB001';

alter table public.mac_reads_audio_assets
  alter column grade_slug set not null,
  alter column lesson_slug set not null;

create unique index if not exists mac_reads_audio_assets_public_route_key
  on public.mac_reads_audio_assets (grade_slug, lesson_slug, public_slug, locale);
