-- DUO 0.3 - Apply AFTER 001_schema.sql, only in an approved project.
-- Account erasure is invoked by a verified caller via the delete-account Edge Function.
-- A revoked JWT cannot regain membership while its auth deletion is retried.
begin;

alter table public.records add column created_by uuid;
-- For historical PRIVATE records, the owner is known. Historical SHARED authors
-- cannot reliably be recovered and are intentionally left unknown.
update public.records set created_by = owner_id where owner_id is not null;
create index records_creator on public.records(created_by) where created_by is not null;

create table public.account_deletions (
    user_id uuid primary key,
    requested_at timestamptz not null default now()
);
alter table public.account_deletions enable row level security;
revoke all on public.account_deletions from public, anon, authenticated;

-- The original write RPC never accepts the client-supplied created_by field.
-- The DB assigns the authenticated creator on insert; edits never rewrite it.
create function public.assign_record_creator() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
    new.created_by := auth.uid();
    return new;
end $$;
create trigger set_record_creator before insert on public.records
for each row execute function public.assign_record_creator();

-- Prevent a JWT for a deleted account from recreating/joining a household.
create function public.refuse_deleted_member() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
    if exists (select 1 from public.account_deletions where user_id = new.user_id) then
        raise exception 'Account removed' using errcode='42501';
    end if;
    return new;
end $$;
create trigger block_deleted_member before insert on public.members
for each row execute function public.refuse_deleted_member();

create function public.erase_my_data() returns boolean
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); home uuid;
begin
    if uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(uid::text, 0));
    -- Idempotent: an Edge retry can finish deleting Auth after earlier cleanup.
    if exists (select 1 from public.account_deletions where user_id=uid) then return true; end if;
    select household_id into home from public.members where user_id=uid;
    if home is not null then
        perform 1 from public.households where id=home for update;
        -- Private rows were never visible to the partner: erase completely.
        delete from public.records where household_id=home and owner_id=uid;
        -- Shared rows known to be authored by this account remain as redacted
        -- tombstones, so the other phone learns about the deletion on next sync.
        update public.records
           set payload='{"task":{"_0":{"title":"Élément supprimé","assignee":"Ensemble","repeatDays":0}}}'::jsonb,
               deleted=true, revision=revision+1, created_by=null
         where household_id=home and owner_id is null and created_by=uid;
        update public.invitations set used=true where household_id=home and not used;
        delete from public.members where user_id=uid;
        if not exists(select 1 from public.members where household_id=home) then
            delete from public.records where household_id=home;
            delete from public.invitations where household_id=home;
            delete from public.households where id=home;
        end if;
    end if;
    -- This table does not reference auth.users: it survives Auth deletion and
    -- blocks still-valid access JWTs from recreating membership.
    insert into public.account_deletions(user_id) values (uid);
    return true;
end $$;

revoke all on function public.assign_record_creator(), public.refuse_deleted_member(), public.erase_my_data() from public,anon,authenticated;
grant execute on function public.erase_my_data() to authenticated;
commit;
