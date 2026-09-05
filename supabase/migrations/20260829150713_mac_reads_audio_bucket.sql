insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('mac-reads-audio', 'mac-reads-audio', false, 10485760, array['audio/mpeg']::text[])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;
