-- DUO : installation Supabase tout-en-un (migrations 001 à 004 dans l'ordre).
-- À coller UNE SEULE FOIS dans Supabase > SQL Editor > New query, puis Run.

-- ===== Backend/001_schema.sql =====
-- DUO development migration. Apply only to a new, approved Supabase project.
-- No service-role key ever belongs in the iPhone app.
begin;
create table public.households (id uuid primary key default gen_random_uuid(), created_at timestamptz not null default now());
create table public.members (
 household_id uuid not null references public.households(id), user_id uuid primary key references auth.users(id), joined_at timestamptz not null default now()
);
create index members_household on public.members(household_id);
create table public.invitations (
 token_hash text primary key, household_id uuid not null references public.households(id), expires_at timestamptz not null, used boolean not null default false
);
create table public.records (
 id uuid primary key, household_id uuid not null references public.households(id), owner_id uuid references auth.users(id),
 revision bigint not null check (revision > 0), deleted boolean not null default false, payload jsonb not null,
 constraint payload_object check (jsonb_typeof(payload) = 'object' and octet_length(payload::text) <= 65536)
);
create index records_household on public.records(household_id);
alter table public.households enable row level security;
alter table public.members enable row level security;
alter table public.invitations enable row level security;
alter table public.records enable row level security;
revoke all on public.households, public.members, public.invitations, public.records from anon, authenticated;
grant select on public.members, public.records to authenticated;
create policy own_membership on public.members for select to authenticated using (user_id = (select auth.uid()));
create policy readable_records on public.records for select to authenticated using (
 (owner_id is null or owner_id = (select auth.uid())) and household_id in (select household_id from public.members where user_id = (select auth.uid()))
);

create function public.create_household() returns uuid language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); home uuid;
begin
 if uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
 -- Serialize create/join for this identity, including concurrent first requests.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(uid::text, 0));
 if exists(select 1 from public.members where user_id=uid) then raise exception 'Already a member'; end if;
 insert into public.households default values returning id into home;
 insert into public.members(household_id,user_id) values(home,uid);
 return home;
end $$;
create function public.invite_partner() returns text language plpgsql security definer set search_path = '' as $$
declare home uuid; token text;
begin
 select household_id into home from public.members where user_id=auth.uid();
 if home is null then raise exception 'Not a member' using errcode='42501'; end if;
 perform 1 from public.households where id=home for update;
 if (select count(*) from public.members where household_id=home) >= 2 then raise exception 'Household full'; end if;
 token := gen_random_uuid()::text || gen_random_uuid()::text;
 update public.invitations set used=true where household_id=home and not used;
 insert into public.invitations(token_hash,household_id,expires_at) values(encode(sha256(convert_to(token,'UTF8')),'hex'),home,now()+interval '24 hours');
 return token;
end $$;
create function public.join_household(p_token text) returns uuid language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); home uuid; hashed text;
begin
 if uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(uid::text,0));
 if exists(select 1 from public.members where user_id=uid) then raise exception 'Already a member'; end if;
 hashed := encode(sha256(convert_to(p_token,'UTF8')),'hex');
 select household_id into home from public.invitations where token_hash=hashed and not used and expires_at>now();
 if home is null then raise exception 'Invalid invitation'; end if;
 perform 1 from public.households where id=home for update;
 -- Recheck after lock: two invitees cannot redeem the same token.
 if not exists(select 1 from public.invitations where token_hash=hashed and not used and expires_at>now()) then raise exception 'Invalid invitation'; end if;
 if (select count(*) from public.members where household_id=home)>=2 then raise exception 'Household full'; end if;
 insert into public.members(household_id,user_id) values(home,uid);
 update public.invitations set used=true where token_hash=hashed;
 return home;
end $$;

create function public.valid_payload(p jsonb) returns boolean language plpgsql immutable set search_path = '' as $$
declare kind text; v jsonb; quantity numeric;
begin
 if jsonb_typeof(p)<>'object' or (select count(*) from jsonb_object_keys(p))<>1 then return false; end if;
 select jsonb_object_keys(p) into kind;
 v := p->kind->'_0';
 if v is null or jsonb_typeof(v)<>'object' then return false; end if;
 if kind='food' or kind='shopping' then
   if kind='shopping' then v := v->'ingredient'; end if;
   quantity := (v->>'quantity')::numeric;
   return coalesce(length(trim(v->>'name')) between 1 and 100 and quantity between 0 and 1000000 and v->>'unit' in ('g','kg','ml','l','piece') and (v->>'unit'<>'piece' or quantity=trunc(quantity)),false);
 elsif kind='meal' then
   return coalesce(length(v->>'recipeID')>0 and (v->>'portions')::integer between 1 and 12 and jsonb_typeof(v->'cooked')='boolean',false);
 elsif kind='task' then
   return coalesce(length(trim(v->>'title')) between 1 and 200 and (v->>'repeatDays')::integer between 0 and 365,false);
 elsif kind='event' then
   return coalesce(length(trim(v->>'title')) between 1 and 200 and (v->>'end')::numeric > (v->>'start')::numeric and length(v->>'timeZone')>0,false);
 elsif kind='habit' then
   return coalesce(length(trim(v->>'title')) between 1 and 200 and (v->>'weeklyGoal')::integer between 1 and 7 and jsonb_typeof(v->'completions')='array',false);
 end if;
 return false;
exception when others then return false;
end $$;
alter table public.records add constraint valid_domain_payload check (public.valid_payload(payload));

create function public.read_records() returns jsonb language plpgsql security definer set search_path = '' as $$
declare home uuid; result jsonb;
begin
 select household_id into home from public.members where user_id=auth.uid();
 if home is null then raise exception 'Not a member' using errcode='42501'; end if;
 select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) into result from public.records r where r.household_id=home and (r.owner_id is null or r.owner_id=auth.uid());
 return result;
end $$;

create function public.apply_records(p_rows jsonb) returns jsonb language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); home uuid; entry jsonb; old public.records; saved public.records; rid uuid; owner uuid; rev bigint; result jsonb := '[]'::jsonb;
begin
 select household_id into home from public.members where user_id=uid;
 if home is null then raise exception 'Not a member' using errcode='42501'; end if;
 if jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows)>2000 or octet_length(p_rows::text)>4000000 then raise exception 'Batch invalid'; end if;
 perform 1 from public.households where id=home for update;
 for entry in select value from jsonb_array_elements(p_rows) loop
   rid := (entry->>'id')::uuid; owner := (entry->>'owner_id')::uuid; rev := (entry->>'revision')::bigint;
   if rid is null or rev is null or rev < 0 then raise exception 'Missing identity or revision'; end if;
   if (entry->>'household_id')::uuid is distinct from home or (owner is not null and owner<>uid) then raise exception 'Forbidden' using errcode='42501'; end if;
   if not public.valid_payload(entry->'payload') then raise exception 'Invalid payload' using errcode='23514'; end if;
   select * into old from public.records where id=rid;
   if found then
     if old.household_id<>home or (old.owner_id is not null and old.owner_id<>uid) or old.owner_id is distinct from owner then raise exception 'Forbidden' using errcode='42501'; end if;
     if old.revision<>rev then raise exception 'Revision conflict' using errcode='PT409'; end if;
     if old.deleted and (old.payload is distinct from entry->'payload' or (entry->>'deleted')::boolean is distinct from true) then raise exception 'Cannot edit a tombstone'; end if;
     update public.records set payload=entry->'payload', deleted=(entry->>'deleted')::boolean, revision=revision+1 where id=rid returning * into saved;
   else
     if rev<>0 then raise exception 'Revision conflict' using errcode='PT409'; end if;
     if (select count(*) from public.records where household_id=home)>=20000 then raise exception 'Household capacity reached'; end if;
     insert into public.records(id,household_id,owner_id,revision,deleted,payload) values(rid,home,owner,1,(entry->>'deleted')::boolean,entry->'payload') returning * into saved;
   end if;
   result := result || jsonb_build_array(to_jsonb(saved));
 end loop;
 return result;
end $$;
-- Every callable definer has an explicit identity check and a fixed empty search_path.
revoke all on function public.create_household(), public.invite_partner(), public.join_household(text), public.read_records(), public.apply_records(jsonb), public.valid_payload(jsonb) from public, anon, authenticated;
grant execute on function public.create_household(), public.invite_partner(), public.join_household(text), public.read_records(), public.apply_records(jsonb) to authenticated;
commit;

-- ===== Backend/002_account_privacy.sql =====
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

-- ===== Backend/003_ai_quota.sql =====
-- OPTIONAL: deploy only if the owner approves paid AI features and sets an API budget.
-- 5 requests / account / UTC day. This is a *request quota*, not a financial spend cap.
begin;
create table public.ai_daily_usage (
    user_id uuid not null,
    utc_day date not null,
    count integer not null check (count between 1 and 5),
    primary key (user_id, utc_day)
);
alter table public.ai_daily_usage enable row level security;
revoke all on public.ai_daily_usage from public, anon, authenticated;
create function public.consume_ai_quota() returns boolean
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); used_count integer;
begin
    if uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
    -- A deleted identity must not consume quota, even while its token is valid.
    if exists (select 1 from public.account_deletions where user_id=uid) then return false; end if;
    insert into public.ai_daily_usage(user_id, utc_day, count)
    values(uid, (now() at time zone 'UTC')::date, 1)
    on conflict(user_id, utc_day) do update set count=public.ai_daily_usage.count+1
    where public.ai_daily_usage.count<5
    returning count into used_count;
    return used_count is not null;
end $$;
-- Account deletion must also erase transient AI request counters.
create function public.purge_ai_usage_for_deleted_account() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
    delete from public.ai_daily_usage where user_id = new.user_id;
    return new;
end $$;
create trigger remove_ai_usage_on_account_deletion
    after insert on public.account_deletions for each row
    execute function public.purge_ai_usage_for_deleted_account();
revoke all on function public.purge_ai_usage_for_deleted_account() from public, anon, authenticated;
revoke all on function public.consume_ai_quota() from public, anon, authenticated;
grant execute on function public.consume_ai_quota() to authenticated;
commit;

-- ===== Backend/004_revoke_invitation.sql =====
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
