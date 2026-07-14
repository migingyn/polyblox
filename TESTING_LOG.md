# PolyBlox — Testing Log

Per PRD Section 15. Automated tests are written alongside each system; this log
records the manual pass and the state of each automated layer.

## Environment note

This MVP was authored in a headless environment **without** a Roblox Studio
install, `luau`, `stylua`, or `selene` on PATH. Consequences (flagged per the
PRD's instruction to mark, not silently skip, unavailable tooling):

- **Grep-based static gates (15.3): RUN HERE, PASSING.** `check_no_hardcoded_assets.sh`
  and `check_monetization.sh` are pure shell and were executed — both pass.
- **Unit + E2E specs (15.1 / 15.2): WRITTEN, NOT YET EXECUTED HERE.** They require
  a Luau runtime (Studio or `run-in-roblox`). Entry point:
  `scripts/run_tests.server.lua` → `tests/TestRunner.lua`. Run in CI on a
  Studio-equipped runner (`.github/workflows/ci.yml`).
- **StyLua / Selene (15.3): configured, run in CI**, skipped locally when the
  binaries are absent (`check_all.sh` degrades gracefully).

## 15.1 Unit tests (`tests/*.spec.lua`)

| Module | Spec | Key cases |
|---|---|---|
| `OddsCalculator` | `OddsCalculator.spec.lua` | zero stake, equal stake, all-on-one-side (bounded), single position moves odds, many positions, multi-outcome, probabilities sum to 1, decimal-odds reciprocal + guard, pool weights |
| `ResolutionSystem` | `ResolutionSystem.spec.lua` | 1x + 5x payout, win/lose/liquidate settlement, loss capped at margin, no double-pay, liquidation threshold boundary, equity ≥ 0, **seed independent of pools**, deterministic seed resolution |
| `SharesEarningSystem` | `SharesEarningSystem.spec.lua` | starter grant exactly-once, no double daily grant, streak increment/reset, **streak multiplier cap (no runaway compounding)**, trickle scales by earn rate |
| `RoleSystem` | `RoleSystem.spec.lua` | Signal Provider + Syndicate Leader thresholds at −1/=/+1, win-streak path, promote-only (never demote) |
| `TradeSystem` | `TradeSystem.spec.lua` | valid trade, unknown/closed market, bad outcome, min stake, insufficient balance, **leverage 5x cap boundary**, **Portfolio Slot limit enforcement** |

## 15.2 End-to-end tests (`tests/E2E.spec.lua`)

Driven through the full system graph with an in-memory DataStore backend:

- New player → starter grant → **persists after cache eviction + reload** (DataStore round-trip).
- Open Fast position → resolve → correct payout, Net Worth + history update.
- Losing position → stake taken, **loss capped at margin, balance stays positive**.
- Leveraged 5x position → opposing volume crosses threshold → **auto-Liquidated, loss capped**.
- **Robux purchase → cosmetic + slots granted → SharesBalance byte-for-byte unchanged** (the required Section 2 check).
- Two players on one market → odds move for both → each resolves independently.

## 15.3 Static checks

| Check | Command | Status |
|---|---|---|
| No hardcoded `rbxassetid://` outside AssetRegistry | `scripts/check_no_hardcoded_assets.sh` | ✅ PASS |
| Monetization rule (no Robux→Shares/stake/odds) | `scripts/check_monetization.sh` | ✅ PASS |
| Format (StyLua) | `stylua --check src tests` | CI (not run locally — binary absent) |
| Lint (Selene) | `selene src tests` | CI (not run locally — binary absent) |

## 15.4 Manual test pass

Requires an actual play session in Studio. **Not yet performed** (no Studio in
the build environment). Checklist retained here to run before calling MVP done:

- [ ] 1. Full loop feel — 10 consecutive Fast-market cycles; odds responsive; confirm animation short.
- [ ] 2. Fairness perception — deliberately lose several in a row; losses feel fair, not rigged.
- [ ] 3. Leverage/liquidation clarity — Option screen readout states the liquidation trigger before it happens.
- [ ] 4. Cosmetic purchase flow — buy 1 cosmetic + 1 QoL via Robux test flow; item applies; **Shares unchanged**.
- [ ] 5. New player experience — fresh account, first 3 Fast markets, note assumed knowledge.
- [ ] 6. Cross-screen consistency — same market in Terminal vs Hotkey Panel reflects identical live state.
- [ ] 7. DataStore resilience — rejoin mid-session; positions, Shares, streak all survive.
- [ ] 8. Persona spot-check — e.g. Rapid Scalper via Hotkey Panel only; Statistical Modeler exports valid JSON log.
