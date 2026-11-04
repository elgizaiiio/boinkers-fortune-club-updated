-- Boinkers Fortune Club: isolated game schema
-- Intentionally uses boinkers_* names because this Supabase project hosts other products.

create extension if not exists pgcrypto;

create table if not exists public.boinkers_players (
  telegram_id bigint primary key,
  username text,
  first_name text,
  last_name text,
  photo_url text,
  language_code text default 'en',
  wallet_address text,
  wallet_network text default 'ton',
  wallet_verified boolean not null default false,
  referred_by bigint references public.boinkers_players(telegram_id),
  coins bigint not null default 5000 check (coins >= 0),
  solo numeric(30,6) not null default 0 check (solo >= 0),
  spins integer not null default 50 check (spins >= 0),
  tickets integer not null default 1 check (tickets >= 0),
  tokens bigint not null default 0 check (tokens >= 0),
  ton numeric(30,9) not null default 0 check (ton >= 0),
  level integer not null default 1 check (level >= 1),
  part_head smallint not null default 0 check (part_head >= 0 and part_head <= 3),
  part_body smallint not null default 0 check (part_body >= 0 and part_body <= 3),
  part_gear smallint not null default 0 check (part_gear >= 0 and part_gear <= 3),
  pass_xp integer not null default 0 check (pass_xp >= 0),
  pass_level integer not null default 1 check (pass_level >= 1),
  premium boolean not null default false,
  solo_bank numeric(30,9) not null default 0 check (solo_bank >= 0),
  last_spin_regen_at timestamptz not null default now(),
  last_solo_claim_at timestamptz not null default now(),
  sound boolean not null default true,
  locale text not null default 'en',
  merge_board jsonb not null default '[]'::jsonb,
  merge_best integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index if not exists boinkers_players_leaderboard_idx
  on public.boinkers_players (solo desc, telegram_id);
create index if not exists boinkers_players_referrer_idx
  on public.boinkers_players (referred_by);

create table if not exists public.boinkers_balance_ledger (
  id uuid primary key default gen_random_uuid(),
  telegram_id bigint not null references public.boinkers_players(telegram_id) on delete cascade,
  currency text not null check (currency in ('coins','solo','spins','tickets','tokens','ton')),
  amount numeric(30,9) not null check (amount <> 0),
  balance_after numeric(30,9),
  source text not null,
  source_id text,
  idempotency_key text not null unique,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists boinkers_ledger_player_time_idx
  on public.boinkers_balance_ledger (telegram_id, created_at desc);

create table if not exists public.boinkers_slot_rounds (
  id uuid primary key default gen_random_uuid(),
  telegram_id bigint not null references public.boinkers_players(telegram_id) on delete cascade,
  bet smallint not null check (bet in (1,3,5,10)),
  reels jsonb not null,
  payout jsonb not null default '{}'::jsonb,
  event_id bigint,
  live_hits jsonb not null default '{}'::jsonb,
  idempotency_key text not null unique,
  created_at timestamptz not null default now()
);
create index if not exists boinkers_slot_rounds_player_time_idx
  on public.boinkers_slot_rounds (telegram_id, created_at desc);

create table if not exists public.boinkers_wheel_rounds (
  id uuid primary key default gen_random_uuid(),
  telegram_id bigint not null references public.boinkers_players(telegram_id) on delete cascade,
  bet smallint not null check (bet in (1,2,5,10)),
  prize_index smallint not null check (prize_index >= 0 and prize_index < 12),
  payout jsonb not null default '{}'::jsonb,
  idempotency_key text not null unique,
  created_at timestamptz not null default now()
);
create index if not exists boinkers_wheel_rounds_player_time_idx
  on public.boinkers_wheel_rounds (telegram_id, created_at desc);

create table if not exists public.boinkers_tasks (
  id text primary key,
  title text not null,
  url text,
  reward jsonb not null default '{}'::jsonb,
  verification_kind text not null default 'manual',
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.boinkers_task_completions (
  telegram_id bigint not null references public.boinkers_players(telegram_id) on delete cascade,
  task_id text not null references public.boinkers_tasks(id) on delete cascade,
  status text not null default 'completed' check (status in ('opened','pending','completed','rejected')),
  proof jsonb not null default '{}'::jsonb,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (telegram_id, task_id)
);

create table if not exists public.boinkers_referrals (
  referred_id bigint primary key references public.boinkers_players(telegram_id) on delete cascade,
  referrer_id bigint not null references public.boinkers_players(telegram_id) on delete cascade,
  source text not null default 'telegram_start',
  signup_rewarded_at timestamptz,
  activity_rewarded_at timestamptz,
  created_at timestamptz not null default now(),
  check (referred_id <> referrer_id)
);

create table if not exists public.boinkers_events (
  id uuid primary key default gen_random_uuid(),
  event_key text not null,
  run_number bigint not null,
  name text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  definition jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (event_key, run_number)
);
create table if not exists public.boinkers_event_progress (
  telegram_id bigint not null references public.boinkers_players(telegram_id) on delete cascade,
  event_id uuid not null references public.boinkers_events(id) on delete cascade,
  tokens integer not null default 0 check (tokens >= 0),
  claimed_tiers integer[] not null default '{}',
  updated_at timestamptz not null default now(),
  primary key (telegram_id, event_id)
);

create table if not exists public.boinkers_pass_claims (
  telegram_id bigint not null references public.boinkers_players(telegram_id) on delete cascade,
  pass_level integer not null check (pass_level >= 1),
  premium boolean not null default false,
  reward jsonb not null default '{}'::jsonb,
  claimed_at timestamptz not null default now(),
  primary key (telegram_id, pass_level, premium)
);
create table if not exists public.boinkers_milestone_claims (
  telegram_id bigint not null references public.boinkers_players(telegram_id) on delete cascade,
  milestone_index integer not null check (milestone_index >= 0),
  reward jsonb not null default '{}'::jsonb,
  claimed_at timestamptz not null default now(),
  primary key (telegram_id, milestone_index)
);

create table if not exists public.boinkers_shop_products (
  id text primary key,
  name text not null,
  description text,
  price_currency text not null check (price_currency in ('coins','solo','ton','stars')),
  price numeric(30,9) not null check (price >= 0),
  reward jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.boinkers_shop_orders (
  id uuid primary key default gen_random_uuid(),
  telegram_id bigint not null references public.boinkers_players(telegram_id) on delete cascade,
  product_id text not null references public.boinkers_shop_products(id),
  price_currency text not null,
  price numeric(30,9) not null,
  status text not null default 'completed' check (status in ('pending','completed','failed','refunded')),
  idempotency_key text not null unique,
  payment_ref text,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.boinkers_wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  telegram_id bigint not null references public.boinkers_players(telegram_id) on delete cascade,
  direction text not null check (direction in ('deposit','withdrawal','reward','purchase')),
  currency text not null check (currency in ('ton','stars')),
  amount numeric(30,9) not null check (amount > 0),
  status text not null default 'pending' check (status in ('pending','confirmed','failed','cancelled')),
  tx_hash text,
  provider_ref text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  confirmed_at timestamptz
);
create unique index if not exists boinkers_wallet_tx_hash_idx
  on public.boinkers_wallet_transactions (tx_hash) where tx_hash is not null;

create table if not exists public.boinkers_nft_items (
  item_index integer primary key,
  name text not null,
  image_url text,
  price_ton numeric(30,9) not null default 0,
  rarity text,
  active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb
);
create table if not exists public.boinkers_nft_orders (
  id uuid primary key default gen_random_uuid(),
  telegram_id bigint not null references public.boinkers_players(telegram_id) on delete cascade,
  item_index integer not null references public.boinkers_nft_items(item_index),
  price_ton numeric(30,9) not null,
  status text not null default 'pending' check (status in ('pending','paid','minted','cancelled','failed')),
  tx_hash text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.boinkers_touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
alter function public.boinkers_touch_updated_at() set search_path = public;

drop trigger if exists boinkers_players_updated_at on public.boinkers_players;
create trigger boinkers_players_updated_at before update on public.boinkers_players
for each row execute function public.boinkers_touch_updated_at();
drop trigger if exists boinkers_tasks_updated_at on public.boinkers_tasks;
create trigger boinkers_tasks_updated_at before update on public.boinkers_tasks
for each row execute function public.boinkers_touch_updated_at();
drop trigger if exists boinkers_task_completions_updated_at on public.boinkers_task_completions;
create trigger boinkers_task_completions_updated_at before update on public.boinkers_task_completions
for each row execute function public.boinkers_touch_updated_at();
drop trigger if exists boinkers_shop_products_updated_at on public.boinkers_shop_products;
create trigger boinkers_shop_products_updated_at before update on public.boinkers_shop_products
for each row execute function public.boinkers_touch_updated_at();
drop trigger if exists boinkers_nft_orders_updated_at on public.boinkers_nft_orders;
create trigger boinkers_nft_orders_updated_at before update on public.boinkers_nft_orders
for each row execute function public.boinkers_touch_updated_at();

-- Direct browser access is denied until authenticated RPCs are added.
-- This prevents a public client from writing balances or mint/payment records.
do $$ declare t text; begin
  foreach t in array array['boinkers_players','boinkers_balance_ledger','boinkers_slot_rounds','boinkers_wheel_rounds','boinkers_tasks','boinkers_task_completions','boinkers_referrals','boinkers_events','boinkers_event_progress','boinkers_pass_claims','boinkers_milestone_claims','boinkers_shop_products','boinkers_shop_orders','boinkers_wallet_transactions','boinkers_nft_items','boinkers_nft_orders'] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

insert into public.boinkers_tasks (id, title, url, reward, verification_kind, sort_order)
values
  ('tg', 'Join our Telegram channel', 'https://t.me/telegram', '{"spins":10}', 'telegram_membership', 10),
  ('x', 'Follow us on X', 'https://x.com', '{"coins":5000}', 'manual', 20),
  ('yt', 'Watch the trailer', 'https://youtube.com', '{"spins":15}', 'manual', 30),
  ('story', 'Share a story', 'https://t.me', '{"tickets":1}', 'manual', 40)
on conflict (id) do nothing;

insert into public.boinkers_shop_products (id, name, description, price_currency, price, reward, sort_order)
values
  ('spin-snack', 'Spin Snack', '30 Spins', 'coins', 8000, '{"spins":30}', 10),
  ('coin-chest', 'Coin Chest', '60K Coins', 'solo', 1000, '{"coins":60000}', 20),
  ('lucky-ticket', 'Lucky Ticket', '1 Wheel Spin', 'coins', 15000, '{"tickets":1}', 30),
  ('mega-bundle', 'Mega Bundle', '150 Spins + 3 Wheel Spins', 'coins', 60000, '{"spins":150,"tickets":3}', 40)
on conflict (id) do nothing;
