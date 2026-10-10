# Adhisaat Health Care Application

A comprehensive healthcare service mobile application suite connecting users with health service providers.

---

## 📱 Application Flavors & Entry Points

The repository contains multi-flavor entry points for both **User** and **Service Provider** applications across **Development** and **Production** environments:

| App Role | Environment | Target Entry Point | Execution Command |
| :--- | :--- | :--- | :--- |
| **User App** | Development | `lib/main_user_dev.dart` | `flutter run -t lib/main_user_dev.dart` |
| **User App** | Production | `lib/main_user_prod.dart` | `flutter run -t lib/main_user_prod.dart` |
| **Provider App** | Development | `lib/main_provider_dev.dart` | `flutter run -t lib/main_provider_dev.dart` |
| **Provider App** | Production | `lib/main_provider_prod.dart` | `flutter run -t lib/main_provider_prod.dart` |

---

## 🛠️ Prerequisites

- **Flutter SDK**: `>=3.10.4`
- **Dart SDK**: `>=3.10.4`
- **iOS Tools**: Xcode 15+, CocoaPods
- **Android Tools**: Android Studio, Android SDK 21+

---

## 🚀 Getting Started

1. **Install Flutter Dependencies:**
   ```bash
   flutter pub get
   ```

2. **Setup iOS Pods:**
   ```bash
   cd ios
   pod install
   cd ..
   ```

3. **Environment Setup:**
   Ensure `.env` file is present in the project root directory with required API keys and base URLs.

4. **Run the Application:**
   ```bash
   # Launch User App in Development Mode
   flutter run -t lib/main_user_dev.dart

   # Launch Service Provider App in Development Mode
   flutter run -t lib/main_provider_dev.dart
   ```

---

## 📦 Building Production Releases

### Android Builds

```bash
# User App (APK & App Bundle)
flutter build apk -t lib/main_user_prod.dart --release
flutter build appbundle -t lib/main_user_prod.dart --release

# Provider App (APK & App Bundle)
flutter build apk -t lib/main_provider_prod.dart --release
flutter build appbundle -t lib/main_provider_prod.dart --release
```

### iOS Builds

```bash
# User App iOS Release
flutter build ipa -t lib/main_user_prod.dart --release

# Provider App iOS Release
flutter build ipa -t lib/main_provider_prod.dart --release
```
