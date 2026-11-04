/**
 * Live events shown under the slot machine. Each lasts 24h or 48h and restarts automatically.
 * Event rewards are only spins or wheel spins (coins are earned from the slots only).
 */
export type EventReward = { spins?: number; tickets?: number; ton?: number };
export interface Tier { need: number; reward: EventReward; price?: { ton: number; stars: number } }
export interface EventDef { key: string; name: string; hours: 24 | 48; offsetH: number; allFree?: boolean; scale: number }

export const LIVE_EVENTS: EventDef[] = [
  { key: "neon-soda", name: "Neon Soda Rush", hours: 24, offsetH: 0, scale: 1.1 },
  { key: "sun-crystal", name: "Solar Crystal Hunt", hours: 48, offsetH: 6, scale: 1.6 },
  { key: "ice-orb", name: "Ice Orb Expedition", hours: 24, offsetH: 12, allFree: true, scale: 0.9 },
  { key: "volcano", name: "Volcano Jackpot", hours: 48, offsetH: 18, scale: 2.2 },
  { key: "robot", name: "Robo Arcade", hours: 24, offsetH: 4, allFree: true, scale: 1.2 },
];

export const PAID_PRICE = { ton: 0.25, stars: 25 };
/** free, paid, free, free, free, paid — repeating. */
const PATTERN = [false, true, false, false, false, true];
export const TIER_COUNT = 12;

export function eventTiers(def: EventDef): Tier[] {
  let need = 0;
  return Array.from({ length: TIER_COUNT }, (_, i) => {
    need += Math.round((4 + i * 3) * def.scale);
    const paid = !def.allFree && PATTERN[i % PATTERN.length]!;
    const wheel = (i + def.key.length) % 2 === 0;
    const reward: EventReward = paid
      ? wheel ? { tickets: Math.round(15 * (1 + i / 3) * def.scale) } : { spins: Math.round(400 * (1 + i / 3) * def.scale) }
      : wheel ? { tickets: 1 + Math.floor(i / 3) } : { spins: Math.round((10 + i * 6) * def.scale) };
    return paid ? { need, reward, price: PAID_PRICE } : { need, reward };
  });
}

/** Run number of an event (changes when the event restarts) and time left. */
export function eventRun(def: EventDef, now: number) {
  const ms = def.hours * 3600_000, t = now + def.offsetH * 3600_000;
  return { run: Math.floor(t / ms), endsIn: ms - (t % ms) };
}

export interface EventProgress { run: number; tokens: number; claimed: number[] }
export function progressFor(p: EventProgress | undefined, run: number): EventProgress {
  return p && p.run === run && Array.isArray(p.claimed) ? p : { run, tokens: 0, claimed: [] };
}
/** Every single landed token counts. */
export function addTokens(p: EventProgress | undefined, run: number, n: number): EventProgress {
  const cur = progressFor(p, run);
  return { ...cur, tokens: cur.tokens + n };
}
/** Free milestones reached but not yet claimed. */
export function claimable(def: EventDef, p: EventProgress) {
  return eventTiers(def).filter((t, i) => !t.price && p.tokens >= t.need && !p.claimed.includes(i)).length;
}
