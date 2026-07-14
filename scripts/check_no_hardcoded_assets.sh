#!/usr/bin/env bash
# CI gate (PRD Section 9 / 15.3): fail if any gameplay script OUTSIDE
# AssetRegistry.lua contains a hardcoded `rbxassetid://`. Every asset id must
# route through ReplicatedStorage/Modules/AssetRegistry.lua so art is swappable.
set -euo pipefail

cd "$(dirname "$0")/.."

# Search source Luau, excluding the one file allowed to hold ids.
matches=$(grep -rn --include='*.lua' 'rbxassetid://' src \
  | grep -v 'AssetRegistry.lua' \
  || true)

if [[ -n "$matches" ]]; then
  echo "FAIL: hardcoded rbxassetid:// found outside AssetRegistry.lua:"
  echo "$matches"
  exit 1
fi

echo "PASS: no hardcoded rbxassetid:// outside AssetRegistry.lua"
