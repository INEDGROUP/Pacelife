create or replace function update_user_streak(p_user_id uuid)
returns void as $$
declare
    last_checkin_date date;
    today date := current_date;
    current_streak integer;
begin
    select date(checked_in_at)
    into last_checkin_date
    from public.checkins
    where user_id = p_user_id
    order by checked_in_at desc
    limit 1 offset 1;

    select streak_days into current_streak
    from public.profiles
    where id = p_user_id;

    if last_checkin_date = today - interval '1 day' then
        update public.profiles
        set 
            streak_days = current_streak + 1,
            total_checkins = total_checkins + 1,
            updated_at = now()
        where id = p_user_id;
    elsif last_checkin_date < today - interval '1 day' or last_checkin_date is null then
        update public.profiles
        set 
            streak_days = 1,
            total_checkins = total_checkins + 1,
            updated_at = now()
        where id = p_user_id;
    else
        update public.profiles
        set 
            total_checkins = total_checkins + 1,
            updated_at = now()
        where id = p_user_id;
    end if;
end;
$$ language plpgsql security definer;

create or replace function trigger_update_streak()
returns trigger as $$
begin
    perform update_user_streak(new.user_id);
    return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_checkin_created on public.checkins;
create trigger on_checkin_created
    after insert on public.checkins
    for each row execute function trigger_update_streak();
