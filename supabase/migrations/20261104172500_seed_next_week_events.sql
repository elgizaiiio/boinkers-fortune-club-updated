-- Seed the active event windows and the next 7 days.
-- Re-running this migration is safe: existing windows are updated, not duplicated.

with main_windows as (
  select
    n as seq,
    to_timestamp(floor(extract(epoch from now()) / 172800) * 172800) + (n * interval '48 hours') as starts_at
  from generate_series(0, 5) as g(n)
), main_rows as (
  select
    'main'::text as event_key,
    floor(extract(epoch from starts_at) / 172800)::bigint as run_number,
    case (floor(extract(epoch from starts_at) / 172800)::bigint % 3)
      when 0 then 'Pumpkin Party'
      when 1 then 'Frog Frenzy'
      else 'Star Rush'
    end as name,
    starts_at,
    starts_at + interval '48 hours' as ends_at,
    jsonb_build_object(
      'kind', 'main',
      'rotation', jsonb_build_array('pumpkin', 'frog', 'star'),
      'event_key', case (floor(extract(epoch from starts_at) / 172800)::bigint % 3)
        when 0 then 'pumpkin' when 1 then 'frog' else 'star' end,
      'token_coins', 250,
      'tier_formula', jsonb_build_object('need_base', 5, 'need_growth', 1.4, 'reward_base', 2000, 'reward_growth', 1.5)
    ) as definition
  from main_windows
  where starts_at < now() + interval '7 days'
), live_defs(event_key, name, hours, offset_hours, all_free, scale) as (
  values
    ('house', 'Tabletop Frenzy', 24, 0, false, 1.0),
    ('dice', 'Game Night', 48, 6, false, 1.5),
    ('ghost', 'Spooky Stitch', 24, 12, true, 0.8),
    ('crown', 'Royal Heist', 48, 18, false, 2.0),
    ('mushroom', 'Mushroom Trail', 24, 4, true, 1.0),
    ('candy', 'Candy Rush', 48, 30, false, 1.2)
), live_windows as (
  select
    d.*,
    to_timestamp(
      floor((extract(epoch from now()) + d.offset_hours * 3600) / (d.hours * 3600)) * (d.hours * 3600)
      - d.offset_hours * 3600
    ) + (g.n * make_interval(hours => d.hours)) as starts_at
  from live_defs d
  cross join generate_series(0, 8) as g(n)
), live_rows as (
  select
    event_key,
    floor((extract(epoch from starts_at) + offset_hours * 3600) / (hours * 3600))::bigint as run_number,
    name,
    starts_at,
    starts_at + make_interval(hours => hours) as ends_at,
    jsonb_build_object(
      'kind', 'live',
      'event_key', event_key,
      'duration_hours', hours,
      'offset_hours', offset_hours,
      'all_free', all_free,
      'scale', scale,
      'tier_count', 12,
      'paid_price', jsonb_build_object('ton', 0.25, 'stars', 25),
      'tier_pattern', jsonb_build_array('free', 'paid', 'free', 'free', 'free', 'paid')
    ) as definition
  from live_windows
  where starts_at < now() + interval '7 days'
    and starts_at + make_interval(hours => hours) > now()
)
insert into public.boinkers_events (event_key, run_number, name, starts_at, ends_at, definition)
select event_key, run_number, name, starts_at, ends_at, definition from main_rows
union all
select event_key, run_number, name, starts_at, ends_at, definition from live_rows
on conflict (event_key, run_number) do update set
  name = excluded.name,
  starts_at = excluded.starts_at,
  ends_at = excluded.ends_at,
  definition = excluded.definition;
