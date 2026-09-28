# Grow a Squishy

A Roblox garden-tycoon game where you grow ASMR toys instead of plants: mochi
squishies, needle balls, butter slime, galaxy slime and more. Buy seeds, plant
them on your plot, wait (even while offline), harvest, sell, upgrade.

This repo is the **core-loop MVP** with placeholder art. See
[docs/DESIGN.md](docs/DESIGN.md) for the full game design, monetization plan,
and roadmap.

## What works right now

- 6-player servers, each player gets a 24-tile plot
- 11 squishies across 7 rarities (Common → Celestial)
- Real-time growth that continues while offline
- Single-harvest and **regrowing** (multi-harvest) squishies
- Random harvest size (0.8x–2.0x, skewed so big ones are rare); value scales with size²
- Seed Shop that restocks every 5 minutes, **identical on every server**, with
  a server-wide shout-out when a Legendary or better is in stock
- Sell stand, backpack capacity, coins leaderboard
- Saving with session locking (prevents duplication by server-hopping)
- Shovel to dig up plants (tap twice to confirm)
- UI: coin counter, backpack meter, shop restock timer, seed hotbar,
  Backpack window (harvested squishies with size and value, and your seeds),
  Seed Shop window, travel buttons (Garden / Seeds / Sell)
- Mouse and touch input (touch still needs testing on a real phone)

## Setup (once per teammate)

1. Install [Roblox Studio](https://create.roblox.com/).
2. Install [Rokit](https://github.com/rojo-rbx/rokit), then in this folder run:
   ```sh
   rokit install
   ```
   This installs the pinned versions of Rojo, selene, StyLua and Lune from `rokit.toml`.
3. Install the Rojo Studio plugin:
   ```sh
   rojo plugin install
   ```
4. Recommended VS Code extensions: **Luau Language Server** (JohnnyMorganz)
   and **Rojo** (evaera).

## Running the game

1. Open a new **Baseplate** place in Studio (the game reuses its Baseplate).
2. In a terminal in this folder: `rojo serve`
3. In Studio: Plugins → Rojo → **Connect**. Code now live-syncs from this repo.
4. Game Settings:
   - **Security → Enable Studio Access to API Services**. Without this, data
     is kept in memory only and you'll see a warning in Output.
   - **Places → Max Players = 6** (must equal `PlotCount` in
     `src/shared/Config/Economy.luau`), once the place is published.
5. Press Play. To test with several players: Test → Clients and Servers → 2+ players.

To produce a place file without Studio sync: `rojo build -o GrowASquishy.rbxlx`.

## Controls

| Action | PC | Mobile |
|---|---|---|
| Select a seed or the shovel | Click a hotbar slot, or keys **1–9** | Tap a hotbar slot |
| Plant / dig up | Click a tile on your plot | Tap a tile |
| Harvest | Walk up to a ready squishy, press **E** | Tap the Harvest prompt |
| Backpack | **B** or the **Bag** button | **Bag** button |
| Travel | **Garden / Seeds / Sell** buttons on the left | Same |

## Project layout

```
src/
  shared/             → ReplicatedStorage.Shared (server + client)
    Config/
      Squishies.luau  the item catalog: prices, grow times, rarity, stock odds
      Rarities.luau   rarity tiers and colors
      Economy.luau    global tuning: starting coins, restock timer, plot size
    Growth.luau       growth progress, harvest size, sell value math
    ShopStock.luau    deterministic shop restock rolls
    Rng.luau          deterministic PRNG so every server rolls the same shop
    Remotes.luau      all client/server network events
    Types.luau        saved data and client state shapes
  server/             → ServerScriptService.Server
    Services/
      DataService     load/save/session-lock player data
      WorldService    builds the placeholder map
      PlotService     assigns plots, teleports players home
      GardenService   plant / harvest / dig up
      ShopService     seed purchases, restock announcements
      SellService     sell stand
      TravelService   Garden / Seeds / Sell travel buttons
    Sync.luau         sends each player their state
    RateLimit.luau    remote spam protection
  client/             → StarterPlayerScripts.Client
    Controllers/      HUD, backpack, shop, toasts, plot clicks, plant animation
    Ui.luau           UI kit: theme colors, buttons, labels, squishy icons
    Windows.luau      pop-up window manager (one window open at a time)
tests/run.luau        unit tests for the shared modules (run with Lune)
```

## Common tasks

**Add a new squishy:** append an entry to the **end** of the list in
`src/shared/Config/Squishies.luau`. Appending (not inserting) keeps every
existing shop roll unchanged. Never rename an existing `id`; it's the save key.

**Rebalance:** edit numbers in `Squishies.luau` / `Economy.luau`, then run the
tests. They check that every squishy is profitable, that the catalog is sorted
by rarity and price, and that a new player can't soft-lock.

**Replace placeholder art:** plants are spawned in
`GardenService` (`spawnPlant`) and the map in `WorldService`. Keep the instance
names and attributes the client relies on (`TileIndex`, `OwnerUserId`,
`StartedAt`, `ReadyAt`, the `SquishyPlant` tag).

## Checks (run before every PR)

```sh
stylua src tests          # format
selene src                # lint
lune run tests/run.luau   # unit tests
```

Type-checking: the Luau Language Server extension flags errors in the editor.
To run it from the command line, generate a sourcemap with
`rojo sourcemap default.project.json -o sourcemap.json` and run
`luau-lsp analyze --sourcemap=sourcemap.json --platform=roblox --defs=<roblox defs> src`.
