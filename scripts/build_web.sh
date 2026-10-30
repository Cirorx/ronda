#!/usr/bin/env bash
# Builds the Flutter web app and stages it in hosting/app/ (git-ignored), which Firebase Hosting
# serves under /app (docs/STACK.md § Pilot builds). From the repo root:
#
#   FCM_VAPID_KEY=<public key> scripts/build_web.sh   # production; `firebase deploy --only hosting`
#                                                     # runs this itself first (predeploy)
#   scripts/build_web.sh development                  # the local emulators, to try Hosting locally
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "$*" >&2
  exit 1
}

flavor="${1:-production}"
case "$flavor" in
  production)
    [[ -n "${FCM_VAPID_KEY:-}" ]] || fail "FCM_VAPID_KEY is missing: set it to the Web Push certificate's public key (Firebase console, Project settings, Cloud Messaging, Web configuration)."
    ;;
  development) ;;
  *) fail "Unknown flavor $flavor: production or development." ;;
esac
options="lib/firebase_options_$flavor.dart"
[[ -f "$options" ]] || fail "$options is missing: run flutterfire configure (docs/STACK.md § Native and project checklist)."

# The FCM service worker carries the web config inline, so it comes from the same options.
dart tool/firebase_messaging_sw.dart "$options"
flutter build web --release --base-href /app/ -t "lib/main_$flavor.dart" \
  --dart-define=FCM_VAPID_KEY="${FCM_VAPID_KEY:-}" \
  --dart-define=RONDA_CONTACT_EMAIL="${RONDA_CONTACT_EMAIL:-}"
grep -q '<base href="/app/">' build/web/index.html || fail "build/web/index.html has no /app/ base href."

rm -rf hosting/app
mkdir -p hosting
cp -R build/web hosting/app
echo "Staged the $flavor web app in hosting/app/."
