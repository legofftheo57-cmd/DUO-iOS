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
