#!/usr/bin/env bash
# CI gate (PRD Section 2 / 14 / 15.3): enforce the non-negotiable monetization
# rule. Fails if any Robux-purchase-handling code path mutates a currency/odds
# field, if the shop catalog declares a Shares/stake/odds grant, or if any UI
# screen contains a Robux-to-Shares exchange element.
set -euo pipefail

cd "$(dirname "$0")/.."

fail=0

# ---------------------------------------------------------------------------
# 1) Purchase-handling code must never write SharesBalance / PoolByOutcome /
#    OddsAtEntry / ResolutionSeed. Scoped by FILENAME to the actual purchase
#    handlers (ShopSystem / any *Purchase* / *Receipt* file), not files that
#    merely mention the words in a comment.
# ---------------------------------------------------------------------------
purchase_files=$(find src -type f -name '*.lua' \
  \( -iname '*shop*' -o -iname '*purchase*' -o -iname '*receipt*' \) || true)
forbidden_write='(SharesBalance|PoolByOutcome|OddsAtEntry|ResolutionSeed)[[:space:]]*(=|\+=|-=)'

for f in $purchase_files; do
  hits=$(grep -nE "$forbidden_write" "$f" || true)
  if [[ -n "$hits" ]]; then
    echo "FAIL: purchase-handling file '$f' mutates a forbidden currency/odds field:"
    echo "$hits"
    fail=1
  fi
done

# ---------------------------------------------------------------------------
# 2) Shop catalog must not declare a Shares/stake/odds/payout grant kind.
# ---------------------------------------------------------------------------
if grep -nEi 'Kind[[:space:]]*=[[:space:]]*"(Shares|Stake|Odds|Payout)"' src/ReplicatedStorage/Modules/ShopCatalog.lua >/dev/null 2>&1; then
  echo "FAIL: ShopCatalog.lua declares a forbidden monetization kind (Shares/Stake/Odds/Payout)."
  grep -nEi 'Kind[[:space:]]*=[[:space:]]*"(Shares|Stake|Odds|Payout)"' src/ReplicatedStorage/Modules/ShopCatalog.lua
  fail=1
fi

# A catalog grant that deposits Shares directly is also forbidden.
if grep -nEi 'SharesGrant|GrantShares|SharesDelta|BalanceDelta' src/ReplicatedStorage/Modules/ShopCatalog.lua >/dev/null 2>&1; then
  echo "FAIL: ShopCatalog.lua contains a direct Shares grant field."
  fail=1
fi

# ---------------------------------------------------------------------------
# 3) No UI screen may contain a Robux-to-Shares exchange element.
# ---------------------------------------------------------------------------
exchange_hits=$(grep -rniE 'robux.?to.?shares|shares.?for.?robux|buy[_ ]?shares|coin.?exchange|convert.*robux' src/StarterGui || true)
if [[ -n "$exchange_hits" ]]; then
  echo "FAIL: a UI screen appears to contain a Robux-to-Shares exchange element:"
  echo "$exchange_hits"
  fail=1
fi

if [[ "$fail" -eq 0 ]]; then
  echo "PASS: monetization rule intact (no Robux path to Shares/stake/odds)."
fi
exit "$fail"
