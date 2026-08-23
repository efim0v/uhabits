#!/usr/bin/env bash
# Ticks every fully-cited ledger feature — but only after a green run.
#
# A citation count is not the gate; a passing test is. This script exists
# because ticking features straight off the coverage report once marked nine
# of them done while their test file was still red.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(cd .. && pwd)"

echo "==> core: dart test"
(cd packages/uhabits_core && dart test)

echo "==> app: flutter test"
(cd app && flutter test)

READY="$(dart tool/parity_coverage.dart --fully-cited \
  | sed -n '/Fully cited/,$p' | tail -n +2)"

if [ -z "$READY" ]; then
  echo "==> nothing new to close"
  exit 0
fi

echo "==> closing:"
echo "$READY" | sed 's/^/    /'
# shellcheck disable=SC2086
(cd "$ROOT" && python3 uhabits-flutter/tool/check_feature.py $READY)

dart tool/parity_coverage.dart --verify
