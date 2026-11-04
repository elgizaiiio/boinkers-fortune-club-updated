-- New themed events for the next 7 days. These are different events, not resets of the old ones.
with live_defs(event_key, name, hours, offset_hours, all_free, scale, token_asset) as (
  values
    ('neon-soda', 'Neon Soda Rush', 24, 0, false, 1.1, 'tok-neon-soda.png'),
    ('sun-crystal', 'Solar Crystal Hunt', 48, 6, false, 1.6, 'tok-sun-crystal.png'),
    ('ice-orb', 'Ice Orb Expedition', 24, 12, true, 0.9, 'tok-ice-orb.png'),
    ('volcano', 'Volcano Jackpot', 48, 18, false, 2.2, 'tok-volcano.png'),
    ('robot', 'Robo Arcade', 24, 4, true, 1.2, 'tok-robot.png')
), live_windows as (
  select d.*, to_timestamp(floor((extract(epoch from now()) + d.offset_hours * 3600) / (d.hours * 3600)) * (d.hours * 3600) - d.offset_hours * 3600) + (g.n * make_interval(hours => d.hours)) as starts_at
  from live_defs d cross join generate_series(0, 8) as g(n)
), rows_to_seed as (
  select event_key, floor((extract(epoch from starts_at) + offset_hours * 3600) / (hours * 3600))::bigint as run_number, name, starts_at,
    starts_at + make_interval(hours => hours) as ends_at,
    jsonb_build_object('kind','live','event_key',event_key,'token_asset',token_asset,'duration_hours',hours,'offset_hours',offset_hours,'all_free',all_free,'scale',scale,'tier_count',12,'paid_price',jsonb_build_object('ton',0.25,'stars',25),'tier_pattern',jsonb_build_array('free','paid','free','free','free','paid')) as definition
  from live_windows where starts_at < now() + interval '7 days' and starts_at + make_interval(hours => hours) > now()
)
insert into public.boinkers_events (event_key, run_number, name, starts_at, ends_at, definition)
select event_key, run_number, name, starts_at, ends_at, definition from rows_to_seed
on conflict (event_key, run_number) do update set name=excluded.name, starts_at=excluded.starts_at, ends_at=excluded.ends_at, definition=excluded.definition;
