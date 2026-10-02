#!/usr/bin/env bash
# Source-level identity rename for the APatch manager (custom branch).
#
# Runs in CI *after* scripts/patch/apatch-custom.patch has been applied, so the
# tracked tree keeps following upstream: rebasing only has to deal with the
# small feature patch, while the built artifact ships a non-official identity.
#
# Override anything from the environment:
#   NEW_APP_ID=com.example.mgr NEW_APP_LABEL=ap NEW_ARCHIVE_PREFIX=ap bash scripts/patch/rename-identity.sh
set -euo pipefail

OLD_ID="me.bmax.apatch"
NEW_ID="${NEW_APP_ID:-com.ap.tool}"
NEW_LABEL="${NEW_APP_LABEL:-ap}"
NEW_ARCHIVE_PREFIX="${NEW_ARCHIVE_PREFIX:-ap}"

OLD_PATH="${OLD_ID//.//}"
NEW_PATH="${NEW_ID//.//}"

cd "$(dirname "$0")/../.."

if ! grep -rIl --exclude-dir=.git --exclude-dir=scripts "$OLD_ID" . >/dev/null 2>&1; then
  echo "identity already renamed, nothing to do"
  exit 0
fi

# 1) move the java / aidl package trees to the new namespace
for base in app/src/main/java app/src/main/aidl; do
  if [ -d "$base/$OLD_PATH" ]; then
    mkdir -p "$base/$(dirname "$NEW_PATH")"
    mv "$base/$OLD_PATH" "$base/$NEW_PATH"
    echo "moved  $base/$OLD_PATH -> $base/$NEW_PATH"
  fi
done

# 2) rewrite every reference: dotted (Kotlin/Java/manifest/gradle) and slashed
#    (JNI FindClass names in cpp). The patch directory is skipped on purpose.
files=$(grep -rIl --exclude-dir=.git --exclude-dir=build --exclude-dir=target \
        --exclude-dir=scripts -e "$OLD_ID" -e "$OLD_PATH" . || true)
if [ -n "$files" ]; then
  # shellcheck disable=SC2086
  echo "$files" | xargs sed -i "s|$OLD_PATH|$NEW_PATH|g; s|$OLD_ID|$NEW_ID|g"
fi

# 3) artifact name and user-visible label
sed -i "s|archivesName = \"APatch_|archivesName = \"${NEW_ARCHIVE_PREFIX}_|" app/build.gradle.kts
sed -i "s|android:label=\"APatch\"|android:label=\"${NEW_LABEL}\"|" app/src/main/AndroidManifest.xml
sed -i "s|<string name=\"app_name\" translatable=\"false\">APatch</string>|<string name=\"app_name\" translatable=\"false\">${NEW_LABEL}</string>|" app/src/main/res/values/strings.xml

echo "identity: $OLD_ID -> $NEW_ID | label: $NEW_LABEL | artifact: ${NEW_ARCHIVE_PREFIX}_*"
