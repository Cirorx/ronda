#!/bin/sh
# Adds the flavor's encoded Firebase app id ("app-1-…-ios-…") to the built Info.plist as a URL
# scheme. Phone sign-in on iOS falls back to a reCAPTCHA in a Safari view when no APNs silent push
# arrives, and that view returns to the app through this scheme. The app id lives in the flavor's
# GoogleService-Info.plist (config/<flavor>/, out of git), so it is read at build time and never
# printed. Run from the Runner target's build phases, after the Info.plist is processed.
set -eu

flavor="${CONFIGURATION##*-}"
gsp="${PROJECT_DIR}/config/${flavor}/GoogleService-Info.plist"
plist="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
buddy=/usr/libexec/PlistBuddy

if [ ! -f "$gsp" ]; then
  echo "warning: phone sign-in URL scheme skipped: no ${gsp} (run flutterfire configure)"
  exit 0
fi
app_id=$("$buddy" -c "Print :GOOGLE_APP_ID" "$gsp")
scheme="app-$(printf '%s' "$app_id" | tr ':' '-')"

# An incremental build can leave the processed plist as the last build wrote it.
if "$buddy" -c "Print :CFBundleURLTypes" "$plist" 2>/dev/null | grep -q -- "$scheme"; then
  exit 0
fi
if ! "$buddy" -c "Print :CFBundleURLTypes" "$plist" >/dev/null 2>&1; then
  "$buddy" -c "Add :CFBundleURLTypes array" "$plist"
fi
"$buddy" \
  -c "Add :CFBundleURLTypes:0 dict" \
  -c "Add :CFBundleURLTypes:0:CFBundleTypeRole string Editor" \
  -c "Add :CFBundleURLTypes:0:CFBundleURLName string firebase-auth" \
  -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" \
  -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string ${scheme}" \
  "$plist"
echo "note: phone sign-in URL scheme added for ${flavor}"
