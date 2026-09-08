create policy "mac_reads_audio_registry_deny_client_access"
on public.mac_reads_audio_assets
as restrictive
for all
to anon, authenticated
using (false)
with check (false);
