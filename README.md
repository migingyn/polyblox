# PolyBlox — Prediction Market Simulator (Roblox / Luau MVP)

A trading-floor prediction market where the traded currency (**Shares**) is
**earn-only**. Robux buys cosmetics, analytics/QoL, and earning-*rate* boosts —
**never** Shares, stake, or odds. That constraint (PRD Section 2) is enforced by
code structure *and* a CI gate, not just convention.

Built to the spec in [`PolyBlox_PRD.md`](PolyBlox_PRD.md).

## The non-negotiable rule (Section 2)

There is no Robux → Shares path anywhere. Enforcement:

- `ShopSystem.lua` physically cannot deposit Shares — it only writes
  `OwnedCosmetics`, `PortfolioSlotLimit`, `UnlockedFeatures`, and
  `EarnRateMultiplier` (a *rate*, not a balance).
- `scripts/check_monetization.sh` fails CI if any purchase-handling file mutates
  `SharesBalance` / `PoolByOutcome` / `OddsAtEntry` / `ResolutionSeed`, if the
  catalog declares a Shares/stake/odds grant, or if a UI screen contains a
  Robux-to-Shares exchange element.
- The E2E test `purchase does not change Shares balance` asserts a byte-for-byte
  unchanged balance across a purchase.

## Layout

```
src/
  ReplicatedStorage/Modules/   Types, Constants, UITheme, AssetRegistry,
                               OddsCalculator, ShopCatalog, Remotes
  ServerScriptService/
    Systems/                   MarketManager, TradeSystem, ResolutionSystem,
                               SharesEarningSystem, RoleSystem, ShopSystem,
                               LeaderboardSystem
    DataStore/                 PlayerDataManager
    Bootstrap.server.lua       authoritative server entry point
  ServerStorage/MarketConfigs/ ground-truth resolution data (hidden from client)
  StarterGui/MainUI/           5 screens + Portfolio/Leaderboard + shared client
tests/                         TestKit runner + unit/E2E specs
scripts/                       CI gates + headless test entry point
```

Server authority: all Shares, positions, odds, and resolution live server-side
(Section 3). The client only ever receives public market snapshots — never the
`ResolutionSeed` or ground-truth outcome (Section 4.4).

## Core mechanics

- **Pooled-odds model** (`OddsCalculator`, Section 4.3): implied probability =
  outcome pool share, with a virtual-liquidity seed so odds stay in `(0,1)` and
  the first bettor can't get an infinite payout.
- **Payout / leverage / liquidation** (`ResolutionSystem`, Section 11.6):
  win pays `M + M·L·(1−p)/p`; loss/liquidation is capped at the margin `M`
  (never a negative balance). Leverage 1–5x, Shares-funded margin only.
- **Fair resolution** (Section 4.4): RandomSeed markets generate their seed at
  **lock** time from a generator that never sees the pools.
- **Earn-only income** (`SharesEarningSystem`): one-time starter grant, capped
  daily streak bonus, small per-trade activity trickle.

## Build & run

```bash
rokit install                 # installs pinned tooling (rojo, stylua, selene, ...)
rojo build -o build.rbxlx     # or: rojo serve, then connect from Studio
```

Open `build.rbxlx` in Studio and press Play. The server seeds demo markets
(Server Pulse / Insider Hunch / Trend-Meta) and runs the Fast-market loop.

## Tests & checks

```bash
bash scripts/check_all.sh     # format + lint (if installed) + monetization/asset gates
# Full unit + E2E suite (needs Studio/run-in-roblox):
run-in-roblox --place build.rbxlx --script scripts/run_tests.server.lua
```

See [`TESTING_LOG.md`](TESTING_LOG.md) for coverage and the manual test pass.

## MVP scope

Implemented: full trade loop (Fast + Medium), pooled odds, earn-only Shares,
Portfolio Slots, Signal Provider role, cosmetic shop, global + seasonal
leaderboard, 5 UI screens, leveraged positions with liquidation. Stubbed
(flagged `-- TODO: post-MVP`): order book, live data feeds, Syndicate dividend
math, Community moderation queue, leverage above 5x, auto-mirror Copy Trade.
Permanently excluded: any Robux-to-Shares path.
