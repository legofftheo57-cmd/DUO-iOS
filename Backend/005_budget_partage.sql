-- DUO 1.0 : le budget devient partagé entre les deux téléphones.
-- À coller UNE SEULE FOIS dans Supabase > SQL Editor > New query, puis Run (après l'installation tout-en-un).
-- Ajoute le type « budget » aux données acceptées par le serveur. Rien d'autre ne change.
create or replace function public.valid_payload(p jsonb) returns boolean language plpgsql immutable set search_path = '' as $$
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
 elsif kind='budget' then
   return coalesce(length(trim(v->>'title')) between 1 and 200 and (v->>'cents')::bigint between 1 and 100000000 and v->>'kind' in ('Revenu','Dépense','Épargne') and v->>'person' in ('Théo','Lilou') and jsonb_typeof(v->'shared')='boolean',false);
 end if;
 return false;
exception when others then return false;
end $$;
revoke all on function public.valid_payload(jsonb) from public, anon, authenticated;
