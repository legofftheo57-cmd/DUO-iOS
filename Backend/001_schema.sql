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
