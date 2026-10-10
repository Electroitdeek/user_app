#!/bin/bash
# Run Patrol tests on Firebase Test Lab
# Usage: ./scripts/run_ftl_tests.sh [user_dev|provider_dev]

set -e

FLAVOR=${1:-user_dev}
TARGET="lib/main_${FLAVOR}.dart"
PROJECT_ID="YOUR_FIREBASE_PROJECT_ID"
BUCKET="YOUR_GCS_BUCKET"
RUN_ID="patrol-$(date +%Y%m%d-%H%M%S)-${FLAVOR}"

echo "Building $FLAVOR instrumented APK..."
patrol build android \
  --target "$TARGET" \
  --flavor "$FLAVOR" \
  --verbose

APP_APK="build/app/outputs/apk/${FLAVOR}/debug/app-${FLAVOR}-debug.apk"
TEST_APK="build/app/outputs/apk/androidTest/${FLAVOR}/debug/app-${FLAVOR}-debug-androidTest.apk"

echo "Uploading to Firebase Test Lab: $RUN_ID"
gcloud firebase test android run \
  --type instrumentation \
  --app "$APP_APK" \
  --test "$TEST_APK" \
  --device model=Pixel6,version=33,locale=en,orientation=portrait \
  --device model=Pixel4a,version=30,locale=en,orientation=portrait \
  --timeout 10m \
  --results-bucket "gs://$BUCKET" \
  --results-dir "$RUN_ID" \
  --use-orchestrator \
  --environment-variables clearPackageData=true \
  --project "$PROJECT_ID"

echo "Done. Results: https://console.firebase.google.com/project/$PROJECT_ID/testlab"
