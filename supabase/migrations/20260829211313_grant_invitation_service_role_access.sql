-- MAC Learn: allow the server-only invitation action to provision identities.
-- Keep these grants limited to the operations used by provisionInvitation.
revoke select, insert, update, delete
on table public.people, public.users, public.profiles
from service_role;

grant select, insert, delete
on table public.people
to service_role;

grant insert
on table public.users, public.profiles
to service_role;
