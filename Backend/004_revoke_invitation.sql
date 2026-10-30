-- Apply after 001_schema.sql to an approved Supabase test project.
-- Revokes outstanding codes without generating or exposing a replacement token.
begin;
create or replace function public.revoke_invitation() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  home uuid;
  affected integer;
begin
  if uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  select household_id into home from public.members where user_id = uid;
  if home is null then raise exception 'Not a member' using errcode = '42501'; end if;
  perform 1 from public.households where id = home for update;
  update public.invitations set used = true
    where household_id = home and not used and expires_at > now();
  get diagnostics affected = row_count;
  return affected;
end $$;
revoke all on function public.revoke_invitation() from public, anon, authenticated;
grant execute on function public.revoke_invitation() to authenticated;
commit;
