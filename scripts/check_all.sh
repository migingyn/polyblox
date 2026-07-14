#!/usr/bin/env bash
# Runs every static gate that does not require a Roblox runtime. Intended to run
# locally before a milestone and in CI (PRD Section 15.3). Lint/format run only
# if the tools are installed (they are pinned in rokit.toml).
set -uo pipefail

cd "$(dirname "$0")/.."
status=0

run() {
  echo ""
  echo ">>> $*"
  "$@" || status=1
}

# Format + lint (skip gracefully if not installed locally).
if command -v stylua >/dev/null 2>&1; then
  run stylua --check src tests
else
  echo "(stylua not installed - skipping format check)"
fi

if command -v selene >/dev/null 2>&1; then
  run selene src tests
else
  echo "(selene not installed - skipping lint)"
fi

# Required grep gates (Section 15.3).
run bash scripts/check_no_hardcoded_assets.sh
run bash scripts/check_monetization.sh

if [[ "$status" -eq 0 ]]; then
  echo ""
  echo "ALL STATIC CHECKS PASSED"
else
  echo ""
  echo "STATIC CHECKS FAILED"
fi
exit "$status"
