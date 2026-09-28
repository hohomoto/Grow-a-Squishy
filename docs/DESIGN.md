# Grow a Squishy — Game Design

## Pitch

Grow a Garden's loop, with ASMR toys instead of plants. Players raise mochi
squishies, needle balls and butter slime on a personal plot, sell them, and
chase ultra-rare Celestial squishies and mutations. The theme gives us
something plant games don't have: **sound and touch**. Every harvest should
*squish*. That's what makes clips people stop scrolling for.

## Why the genre works (and what we copy)

| Hook | Why it works | Status |
|---|---|---|
| Real-time growth, offline progress | Gives players a reason to come back: "my Galaxy Slime is ready" | ✅ MVP |
| Cheap start, exponential catalog | Fast early wins, a long tail of goals (10 coins → 300K coins) | ✅ MVP |
| Multi-harvest plants | Planting a rare feels like an investment that keeps paying | ✅ MVP |
| Timed global shop restocks | Rare stock is a shared, time-limited event; people check back every 5 min | ✅ MVP |
| Server shout-outs for rare stock | Social proof and urgency, based on real events only | ✅ MVP |
| Random harvest size | Every harvest is a small lottery with no Robux involved | ✅ MVP |
| Mutations + weather events | Jackpot moments, and server-wide events that are fun to clip | ✅ Built |
| Pets | Collection, passive boosts, a second progression track | Milestone 4 |
| Trading + gifting | Status, community, content creators | Milestone 5 |
| Rebirth + leaderboards | Endgame loop and flexing | Milestone 6 |
| Frequent content updates | New squishies and events bring players back | Ongoing |

## Core loop (MVP)

```
Buy seeds (Seed Shop) → Plant on your plot → Wait (online or offline)
     ↑                                                  ↓
 Coins ← Sell at Squishy Buyer ← Harvest (random size 0.8x–2.0x)
```

- **Plots:** 6 per server, 64 tiles each, in two garden beds with a walkway
  between them. Plants persist across sessions.
- **Growth:** stored as `startedAt` / `readyAt` timestamps. The server decides
  when a plant is ready; the client only animates it.
- **Regrowing squishies** stay on the tile after harvest and regrow faster
  than their first growth. Single-harvest squishies are removed.
- **Value** = `baseValue × size²`. With the current skew, about 1 in 6
  harvests is 1.5x or bigger.
- **Backpack:** 150 items, then you must sell.

### Catalog (current balance)

Four plant families, each with its own 3D look:

- **Bao squishies** — round steamed buns with kawaii faces
- **Squish cubes** — see-through jelly cubes with faces (generic name on
  purpose: "NeeDoh"/"Nice Cube" are Schylling trademarks)
- **Butter** — squishy butter sticks with a printed label
- **Keycaps** — ASMR keyboard keys with letters; they all regrow ("plant a
  keyboard, keys keep popping up")

| Plant | Family | Rarity | Seed | Grow | Regrow | Base value | Shop chance |
|---|---|---|---|---|---|---|---|
| Mochi Bao | bao | Common | 10 | 0:30 | – | 18 | 100% |
| Butter Stick | butter | Common | 25 | 0:45 | – | 40 | 100% |
| Wood Keycap | keycap | Common | 50 | 1:00 | 0:30 | 12 | 100% |
| Squish Cube | cube | Uncommon | 120 | 1:30 | – | 210 | 85% |
| Peach Bao | bao | Uncommon | 200 | 2:30 | 1:00 | 45 | 80% |
| Salted Butter Block | butter | Uncommon | 350 | 3:00 | – | 600 | 70% |
| Clicky Keycap | keycap | Rare | 700 | 4:00 | 1:00 | 110 | 50% |
| Glitter Cube | cube | Rare | 1.5K | 6:00 | – | 2.6K | 40% |
| Galaxy Bao | bao | Epic | 4K | 8:00 | 1:30 | 380 | 25% |
| RGB Keycap | keycap | Epic | 9K | 10:00 | 2:00 | 700 | 18% |
| Honey Butter | butter | Legendary | 25K | 15:00 | 3:00 | 1.8K | 10% |
| Crystal Cube | cube | Legendary | 60K | 20:00 | 3:20 | 3.8K | 7% |
| Artisan Keycap | keycap | Mythic | 150K | 30:00 | 4:00 | 8K | 5% |
| Dragon Bao | bao | Mythic | 400K | 40:00 | 5:00 | 18K | 3% |
| Starlight Bao | bao | Celestial | 1.2M | 1:00:00 | 6:00 | 50K | 1.5% |

At a 1.5% chance per 5-minute restock, a Starlight Bao appears about once
every 5.5 hours on average. Tune these before launch using real playtest data.

### Mutations

A plant's value is `base × size² × (1 + Σ(mutation − 1))`, so mutations
stack additively.

| Mutation | Multiplier | Source |
|---|---|---|
| Glitter | x2 | 2% chance at planting; Glitter Storm |
| Slimy | x3 | Slime Rain |
| Frozen | x5 | Freeze Snap |
| Gold | x15 | 0.5% chance at planting |
| Rainbow | x40 | 0.1% chance at planting (replaces Gold) |
| Starstruck | x60 | Hit by a shooting star during Starfall |

Mutated plants are tinted (gold, cycling rainbow, icy, slimy, starry), give
off particles and show colored tags. Harvests of x15 or more are announced to
the whole server.

### Weather

One 10-minute window at a time, with a 60% chance of an event per window. The
schedule is global, so every server gets the same weather at the same moment.
In Studio an event runs every 2 minutes, cycling through all types.

| Event | Weight | Effect |
|---|---|---|
| Slime Rain | 35 | 4% per plant every 5s to turn Slimy; green rain |
| Freeze Snap | 30 | 3% per plant every 5s to turn Frozen; snow |
| Glitter Storm | 25 | 6% per plant every 5s to turn Glitter; sparkles |
| Starfall | 10 | Night sky; 35% chance every 5s that a shooting star strikes a random plant (Starstruck) |

## Monetization plan (Milestone 3)

Revenue comes from three places: **Game Passes** (one-time), **Developer
Products** (repeatable), and **Premium Payouts** (Roblox pays for time Premium
members spend in the game, so retention is revenue too).

### Products

| Product | Type | Notes |
|---|---|---|
| Skip Grow (one plant) | Dev Product | Price tiers by remaining time. The best-value purchase in the genre. |
| Server Restock | Dev Product | Restocks the shop **for everyone** in the server, and announces the buyer. Pro-social and clip-worthy. |
| Buy Seed Directly | Dev Product | Buy a specific in-stock seed with Robux. Robux prices stay above what the coin grind is worth. |
| Bigger Backpack | Game Pass | 150 → 300 |
| 2x Sell Value | Game Pass | The classic tycoon pass |
| Extra Plot Row | Game Pass | +6 tiles |
| VIP | Game Pass | Chat tag, VIP area, cosmetic squishy skins |
| Gifting | All of the above | Buy any product for another player in the server |

### Guardrails (non-negotiable)

Most of our audience is kids. These rules protect them, and they also keep
the game compliant with Roblox's rules and within what parents are fine with.
Long-term revenue depends on players trusting the game.

1. **Show odds before any paid random purchase**: an egg, crate or spin paid
   for with Robux, directly or through a currency bought with Robux. Roblox
   requires this for paid random items.
2. **Check `PolicyService:GetPolicyInfoForPlayerAsync`**. If
   `ArePaidRandomItemsRestricted` is true for a player, hide paid random items
   from them. Some countries ban them.
3. **No fake scarcity.** Timers, "sold out", and shout-outs must reflect real
   game state. The shop is deterministic, so this is easy to keep true.
4. **No pressure on purchase screens**: no countdown pop-ups, no "your plants
   will die" guilt, and nothing that punishes players who don't pay.
5. **Everything is earnable in-game**, just slower. Paying skips time; it
   doesn't unlock exclusive power.
6. **`ProcessReceipt` must be idempotent**: record each `PurchaseId` in player
   data before granting, so Robux purchases are never lost or granted twice.

## Roadmap

### Milestone 2 — Mutations + Weather ✅
Built: see the Mutations and Weather sections above.

### Milestone 3 — Monetization
- The products and guardrails above.
- A purchase log in DataService so receipts are processed exactly once.

### Milestone 4 — Pets
- Squishy Pals hatch from eggs bought in a Pet Shop, with odds shown on the egg.
- 3 equip slots (more via a Game Pass). Passive boosts: grow speed, sell
  value, mutation luck.

### Milestone 5 — Trading + Gifting
- Server-side trade sessions: both players must accept, then a 5-second
  countdown before the final confirm, and any change resets both accepts.
- Session locking (already built) prevents duplication through trades.
- Trade log saved per player, for support and investigating scams.

### Milestone 6 — Rebirth + Leaderboards
- Rebirth resets coins and plants for a permanent sell multiplier and new
  cosmetics.
- Global leaderboards (OrderedDataStore): lifetime coins, rarest harvest,
  biggest harvest.

## Viral checklist

- [ ] ASMR sound for every harvest, different per squishy (the #1 priority for this theme)
- [ ] A satisfying squish animation plus particles on harvest
- [ ] Thumbnail and icon: a giant glittery squishy in someone's hand
- [ ] Weather events designed to be clipped: big sky changes, loud audio cues
- [ ] Weekly updates: new squishies, new weather, limited-time events
- [ ] Group, social links in game, and codes to reward followers
