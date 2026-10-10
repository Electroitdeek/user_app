#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
# Xcode Cloud — Post-Xcodebuild Script
# Patches App.framework and Flutter.framework Info.plist files inside the
# .xcarchive to ensure MinimumOSVersion is set (fixes errors 90530 & 90360).
# ─────────────────────────────────────────────────────────────────────────────

set -e

DEPLOYMENT_TARGET="15.5"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Post-Xcodebuild: Fixing framework MinimumOSVersion"
echo "  Archive path: ${CI_ARCHIVE_PATH}"
echo "  Deployment target: ${DEPLOYMENT_TARGET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -z "${CI_ARCHIVE_PATH}" ]; then
  echo "CI_ARCHIVE_PATH not set — skipping patch."
  exit 0
fi

FRAMEWORKS_DIR="${CI_ARCHIVE_PATH}/Products/Applications/Runner.app/Frameworks"

if [ ! -d "${FRAMEWORKS_DIR}" ]; then
  echo "Frameworks directory not found: ${FRAMEWORKS_DIR}"
  exit 0
fi

# Patch every framework that has a missing or empty MinimumOSVersion
for FRAMEWORK in "${FRAMEWORKS_DIR}"/*.framework; do
  PLIST="${FRAMEWORK}/Info.plist"
  NAME=$(basename "${FRAMEWORK}")

  if [ ! -f "${PLIST}" ]; then
    echo "  Skipping ${NAME} — no Info.plist"
    continue
  fi

  CURRENT=$(/usr/libexec/PlistBuddy -c "Print :MinimumOSVersion" "${PLIST}" 2>/dev/null || echo "")

  if [ -z "${CURRENT}" ]; then
    # Delete any empty key first, then add with correct value
    /usr/libexec/PlistBuddy -c "Delete :MinimumOSVersion" "${PLIST}" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :MinimumOSVersion string ${DEPLOYMENT_TARGET}" "${PLIST}"
    echo "  ✅ Fixed ${NAME}: MinimumOSVersion = ${DEPLOYMENT_TARGET}"
  else
    echo "  ✔  ${NAME}: MinimumOSVersion already '${CURRENT}'"
  fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Framework patch complete."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

