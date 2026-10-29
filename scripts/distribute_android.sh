#!/usr/bin/env bash
# Builds the production release APK and sends it to the `pilot` tester group on Firebase App
# Distribution (docs/STACK.md § Pilot builds). From the repo root:
#
#   scripts/distribute_android.sh "Qué cambió"   # build and upload; notes default to the last commit
#   scripts/distribute_android.sh --build-only   # build only: nothing leaves this Mac
#
# The APK is obfuscated. Its symbols go to symbols/android/<version>-<commit>/ (git-ignored): keep
# them to read a crash, with `flutter symbolize -i <trace> -d <dir>/app.android-arm64.symbols`.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "$*" >&2
  exit 1
}

build_only=false
if [[ "${1:-}" == "--build-only" ]]; then
  build_only=true
  shift
fi
notes="${1:-}"

options=lib/firebase_options_production.dart
for file in "$options" android/app/src/production/google-services.json; do
  [[ -f "$file" ]] || fail "$file is missing: run flutterfire configure for the production flavor (docs/STACK.md § Native and project checklist)."
done
app_id=$(awk '/FirebaseOptions android/ { found = 1 } found && /appId:/ { print; exit }' "$options" |
  sed -E "s/.*appId: *'([^']+)'.*/\1/")
[[ -n "$app_id" ]] || fail "No Android appId in $options."

if ! $build_only; then
  command -v firebase >/dev/null || fail "firebase-tools is missing: npm install -g firebase-tools."
  firebase login:list 2>&1 | grep "Logged in as" >/dev/null || fail "firebase-tools is not logged in: run firebase login."
fi

version=$(sed -nE 's/^version: *([^ ]+).*/\1/p' pubspec.yaml)
symbols="symbols/android/$version-$(git rev-parse --short HEAD)"
flutter build apk --release --flavor production -t lib/main_production.dart \
  --obfuscate --split-debug-info="$symbols"
apk=build/app/outputs/flutter-apk/app-production-release.apk

# The key that signed the APK: its SHA-1 and SHA-256 must be on the Android app in Firebase and
# on the Android API key's restriction.
sdk="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
apksigner=$(find "$sdk/build-tools" -name apksigner 2>/dev/null | sort -V | tail -1 || true)
if [[ -n "$apksigner" ]]; then
  echo "Signed with:"
  "$apksigner" verify --print-certs "$apk" | awk '/SHA-(1|256) digest/ {
    hex = toupper($NF); gsub(/../, "&:", hex); sub(/:$/, "", hex); print "  " $4 " " hex }'
fi
echo "Symbols: $symbols (keep them to read crashes from this build)."

if $build_only; then
  echo "Built $apk (--build-only: not uploaded)."
  exit 0
fi
[[ -n "$notes" ]] || notes=$(git log -1 --pretty=%s)
firebase appdistribution:distribute "$apk" --app "$app_id" --groups pilot --release-notes "$notes"
