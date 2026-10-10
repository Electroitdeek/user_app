# Adhisaat Healthcare — Development Handover

## Purpose
This package is a development/testing copy of the current application source. It is intentionally separated from the live production environment.

## Mandatory rules
- Do not connect this copy to the live production database.
- Do not use production server credentials.
- Do not use production payment credentials/secret keys.
- Development/testing must use a separate test backend/API and test database.
- Do not build or publish production releases from this package without explicit approval.

## Environment
1. Copy `.env.example` to `.env`.
2. Fill only development/test values.
3. Use the development API endpoint for all testing.

## Firebase
Production Firebase configuration files are intentionally not included. Create/use a dedicated development Firebase project and configure Android/iOS using FlutterFire CLI.

Required files after setup (local only):
- `android/app/google-services.json`
- `ios/Runner/Firebase/<flavor>/GoogleService-Info.plist` as required by the chosen dev flavor
- generated `lib/firebase_options.dart`

## Build targets
The source contains these flavors/entry points:
- `user_dev` → `lib/main_user_dev.dart`
- `provider_dev` → `lib/main_provider_dev.dart`
- `user_prod` → `lib/main_user_prod.dart`
- `provider_prod` → `lib/main_provider_prod.dart`

For development work, use only `user_dev` and `provider_dev`.

## Important
The production source files are retained for code reference, but production services/credentials must not be used during development.
