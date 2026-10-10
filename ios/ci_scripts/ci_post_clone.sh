#!/bin/zsh

# ─────────────────────────────────────────────────────────────────────────────
# Xcode Cloud — Post-Clone Script
# ─────────────────────────────────────────────────────────────────────────────

set -e
set -o pipefail

FLUTTER_VERSION="3.38.5"
FLUTTER_INSTALL_DIR="$HOME/flutter"

# Xcode Cloud exposes selected values via env vars; keep fallbacks for local runs.
SCHEME_NAME="${CI_XCODE_SCHEME:-${CI_SCHEME_NAME:-${SCHEME_NAME:-Runner}}}"
CONFIGURATION_NAME="${CI_XCODE_CONFIGURATION:-${CONFIGURATION:-Release-user_dev}}"

SCHEME_LOWER=$(printf "%s" "$SCHEME_NAME" | tr '[:upper:]' '[:lower:]')
CONFIG_LOWER=$(printf "%s" "$CONFIGURATION_NAME" | tr '[:upper:]' '[:lower:]')

APP_FLAVOR="user_dev"
FLUTTER_TARGET="lib/main_user_dev.dart"

case "$SCHEME_LOWER:$CONFIG_LOWER" in
  *provider*:*prod*|*provider_prod*:*|*:*provider*prod*)
    APP_FLAVOR="provider_prod"
    FLUTTER_TARGET="lib/main_provider_prod.dart"
    ;;
  *provider*:*dev*|*provider_dev*:*|*:*provider*dev*)
    APP_FLAVOR="provider_dev"
    FLUTTER_TARGET="lib/main_provider_dev.dart"
    ;;
  *user*:*prod*|*user_prod*:*|*:*user*prod*)
    APP_FLAVOR="user_prod"
    FLUTTER_TARGET="lib/main_user_prod.dart"
    ;;
  *user*:*dev*|*user_dev*:*|*:*user*dev*)
    APP_FLAVOR="user_dev"
    FLUTTER_TARGET="lib/main_user_dev.dart"
    ;;
esac

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Adhisaat Health Care — Xcode Cloud Pre-Build"
echo "  Flutter target: $FLUTTER_VERSION"
echo "  Scheme: $SCHEME_NAME"
echo "  Configuration: $CONFIGURATION_NAME"
echo "  Flavor: $APP_FLAVOR"
echo "  Entry point: $FLUTTER_TARGET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Step 1: Install Flutter ───────────────────────────────────────────────────
echo "\n▶ [1/4] Installing Flutter..."

if [ -d "$FLUTTER_INSTALL_DIR/.git" ]; then
  INSTALLED_TAG=$(git -C "$FLUTTER_INSTALL_DIR" describe --tags --exact-match 2>/dev/null || echo "unknown")
  echo "  Found existing Flutter clone: $INSTALLED_TAG"
  if [ "$INSTALLED_TAG" != "$FLUTTER_VERSION" ]; then
    echo "  Version mismatch. Updating..."
    git -C "$FLUTTER_INSTALL_DIR" fetch --tags --quiet
    git -C "$FLUTTER_INSTALL_DIR" checkout "$FLUTTER_VERSION" --quiet
  else
    echo "  Already on $FLUTTER_VERSION — skipping clone."
  fi
else
  echo "  Cloning Flutter $FLUTTER_VERSION from GitHub..."
  git clone \
    --depth 1 \
    --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git \
    "$FLUTTER_INSTALL_DIR"
fi

export PATH="$FLUTTER_INSTALL_DIR/bin:$PATH"
# Avoid `head` with pipefail here; it can trigger a Broken pipe from flutter output.
FLUTTER_VERSION_LINE=$(flutter --version 2>/dev/null | sed -n '1p')
echo "\n  ${FLUTTER_VERSION_LINE}"

# ── Step 2: Disable analytics & precache ─────────────────────────────────────
echo "\n▶ [2/4] Disabling Flutter analytics & CLI animations..."
flutter config --no-analytics --no-cli-animations 2>/dev/null || true
flutter precache --ios --quiet

# ── Step 2.5: Write .env file — expand Xcode Cloud env vars ──────────────────
echo "\n▶ Creating .env for CI build..."
# Accept both names from CI to avoid empty-key builds.
EFFECTIVE_MAPS_KEY_IOS="${GOOGLE_MAPS_API_KEY_IOS:-${GOOGLE_MAPS_API_KEY:-}}"
{
  echo "GOOGLE_MAPS_API_KEY_ANDROID=${GOOGLE_MAPS_API_KEY_ANDROID:-}"
  echo "GOOGLE_MAPS_API_KEY_IOS=${EFFECTIVE_MAPS_KEY_IOS:-}"
  echo "GOOGLE_MAPS_API_KEY=${EFFECTIVE_MAPS_KEY_IOS:-}"
  echo "WEB_BASE_URL=${WEB_BASE_URL:-}"
  echo "PROD_API_BASE_URL=${PROD_API_BASE_URL:-}"
  echo "DEV_API_BASE_URL=${DEV_API_BASE_URL:-}"
} > "$CI_PRIMARY_REPOSITORY_PATH/.env"

echo "  .env contents:"
cat "$CI_PRIMARY_REPOSITORY_PATH/.env" | sed 's/^/    /'

# Export env vars to shell environment so they're available to Flutter build
export GOOGLE_MAPS_API_KEY_ANDROID
export GOOGLE_MAPS_API_KEY_IOS="$EFFECTIVE_MAPS_KEY_IOS"
export GOOGLE_MAPS_API_KEY="$EFFECTIVE_MAPS_KEY_IOS"
export WEB_BASE_URL
export PROD_API_BASE_URL
export DEV_API_BASE_URL

# Ensure iOS build settings get the right flavor target and iOS maps key.
GENERATED_XCCONFIG="$CI_PRIMARY_REPOSITORY_PATH/ios/Flutter/Generated.xcconfig"
apply_generated_overrides() {
  if [ -f "$GENERATED_XCCONFIG" ]; then
    # flutter pub get may regenerate this file; always re-apply overrides afterwards.
    sed -i '' '/^FLUTTER_TARGET=/d;/^FLAVOR=/d;/^GOOGLE_MAPS_API_KEY_IOS=/d;/^GOOGLE_MAPS_API_KEY=/d' "$GENERATED_XCCONFIG"
    {
      echo "FLUTTER_TARGET=$FLUTTER_TARGET"
      echo "FLAVOR=$APP_FLAVOR"
      echo "GOOGLE_MAPS_API_KEY_IOS=${EFFECTIVE_MAPS_KEY_IOS:-}"
      echo "GOOGLE_MAPS_API_KEY=${EFFECTIVE_MAPS_KEY_IOS:-}"
    } >> "$GENERATED_XCCONFIG"
    echo "  Updated Generated.xcconfig overrides"
  fi
}

apply_generated_overrides

# ── Step 3: Flutter pub get ───────────────────────────────────────────────────
echo "\n▶ [3/4] Running flutter pub get..."
cd "$CI_PRIMARY_REPOSITORY_PATH"
echo "  Starting at $(date '+%H:%M:%S')..."
flutter pub get
echo "  ✓ Completed at $(date '+%H:%M:%S')"

# flutter pub get can rewrite Generated.xcconfig and reset FLUTTER_TARGET to lib/main.dart.
apply_generated_overrides

# ── Step 4: CocoaPods install ─────────────────────────────────────────────────
echo "\n▶ [4/4] Installing CocoaPods dependencies..."
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
POD_VERSION=$(pod --version)
echo "  CocoaPods version: $POD_VERSION"
echo "  Starting at $(date '+%H:%M:%S')..."

# Ensure workspace shared schemes include project shared schemes (dev/prod).
mkdir -p Runner.xcworkspace/xcshareddata/xcschemes
if [ -d Runner.xcodeproj/xcshareddata/xcschemes ]; then
  cp -f Runner.xcodeproj/xcshareddata/xcschemes/*.xcscheme Runner.xcworkspace/xcshareddata/xcschemes/ 2>/dev/null || true
  echo "  ✓ Shared schemes synced"
fi

# Remove any stale pod cache that could cause module map issues with GoogleMaps
echo "  Cleaning stale pod caches..."
pod cache clean 'GoogleMaps' --all 2>/dev/null || true
pod cache clean 'Google-Maps-iOS-Utils' --all 2>/dev/null || true

# Use pod install without --repo-update for CI (pods are fresh, avoid network delays)
echo "  Running pod install (no --repo-update to avoid network timeouts)..."
pod install

echo "\n▶ Verifying workspace contains Pods project..."
if grep -q "Pods/Pods.xcodeproj" Runner.xcworkspace/contents.xcworkspacedata; then
  echo "  ✅ Workspace correctly references Pods project."
else
  echo "  ⚠️  WARNING: Pods project not found in workspace!"
fi

echo "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Pre-build setup complete! Ready for Xcode build."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
