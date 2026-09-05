create table if not exists public.mac_reads_audio_assets (
  id uuid primary key default gen_random_uuid(),
  lesson_id text not null,
  asset_code text not null,
  asset_type text not null check (asset_type in ('story', 'power_word', 'fluency', 'sound_support', 'word_work')),
  display_title text not null,
  public_slug text not null,
  locale text not null default 'en-US',
  storage_bucket text not null default 'mac-reads-audio',
  storage_path text not null,
  version integer not null default 1 check (version > 0),
  status text not null default 'audio_pending' check (status in ('audio_pending', 'uploaded', 'published', 'retired')),
  duration_ms integer check (duration_ms is null or duration_ms > 0),
  checksum text,
  created_at timestamptz not null default now(),
  published_at timestamptz,
  constraint mac_reads_audio_assets_lesson_slug_locale_key unique (lesson_id, public_slug, locale),
  constraint mac_reads_audio_assets_lesson_asset_locale_version_key unique (lesson_id, asset_code, locale, version)
);

comment on table public.mac_reads_audio_assets is 'Server-managed registry for MAC READS audio assets. QR resolver routes use published rows only.';

alter table public.mac_reads_audio_assets enable row level security;
revoke all on table public.mac_reads_audio_assets from anon, authenticated;

insert into public.mac_reads_audio_assets (
  lesson_id, asset_code, asset_type, display_title, public_slug, locale, storage_path, status
)
values
  ('MACR-G4-RB001', 'STORY', 'story', 'The Message in the Rain Barrel', 'story', 'en-US', 'grade-4/MACR-G4-RB001/en-us/story.mp3', 'audio_pending'),
  ('MACR-G4-RB001', 'PW01', 'power_word', 'RETRIEVED', 'retrieved', 'en-US', 'grade-4/MACR-G4-RB001/en-us/pw01-retrieved.mp3', 'audio_pending'),
  ('MACR-G4-RB001', 'PW02', 'power_word', 'WATERPROOF', 'waterproof', 'en-US', 'grade-4/MACR-G4-RB001/en-us/pw02-waterproof.mp3', 'audio_pending'),
  ('MACR-G4-RB001', 'PW03', 'power_word', 'CHALLENGED', 'challenged', 'en-US', 'grade-4/MACR-G4-RB001/en-us/pw03-challenged.mp3', 'audio_pending'),
  ('MACR-G4-RB001', 'PW04', 'power_word', 'RECORDING', 'recording', 'en-US', 'grade-4/MACR-G4-RB001/en-us/pw04-recording.mp3', 'audio_pending'),
  ('MACR-G4-RB001', 'PW05', 'power_word', 'RESULTS', 'results', 'en-US', 'grade-4/MACR-G4-RB001/en-us/pw05-results.mp3', 'audio_pending')
on conflict (lesson_id, public_slug, locale) do update
set asset_code = excluded.asset_code,
    asset_type = excluded.asset_type,
    display_title = excluded.display_title,
    storage_bucket = excluded.storage_bucket,
    storage_path = excluded.storage_path;
