#!/usr/bin/env bash
# Single entry point for the Flutter port's test suite.
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$(pwd)"

echo "==> core: dart test"
cd "$ROOT/packages/uhabits_core"
dart pub get >/dev/null
dart test "$@"

echo "==> app: flutter test"
cd "$ROOT/app"
flutter pub get >/dev/null
flutter test "$@"

echo "==> all green"
