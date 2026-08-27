-- ============================================================
-- MAC Learn: user-specific profile access
-- ============================================================
-- Legacy policies applied to PUBLIC and permitted a profile owner to
-- update every profile column. The role and tenant-link columns are
-- authorization data, so ordinary users must not be able to alter them.

drop policy if exists "Users can view their own profile" on public.profiles;
drop policy if exists "Users can update their own profile" on public.profiles;

create policy "Authenticated users view their own profile"
on public.profiles
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Authenticated users update their own profile contact fields"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

-- Replace the earlier broad table UPDATE grant with the two personal fields
-- that an end user may maintain without changing authorization or tenancy.
revoke update on table public.profiles from authenticated;
grant update (full_name, phone) on table public.profiles to authenticated;

comment on policy "Authenticated users view their own profile" on public.profiles is
  'Authenticated users may read only the profile linked to auth.uid().';

comment on policy "Authenticated users update their own profile contact fields" on public.profiles is
  'Authenticated users may update their own profile row; column grants restrict edits to full_name and phone.';
