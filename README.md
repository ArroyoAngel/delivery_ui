# delivery_ui

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Ejecutar en emulador Android

1. `flutter emulators --launch Pixel_6_API_36`
2. `flutter devices --device-timeout 120`
3. `flutter run -d emulator-5554`

## Build

- Clean + rebuild:
	1. `flutter clean`
	2. `flutter pub get`
	3. `flutter build apk --debug`

- APK debug: `flutter build apk --debug`
- APK release: `flutter build apk --release`
- App Bundle (Play Store): `flutter build appbundle --release`
- Web: `flutter build web`
- Windows: `flutter build windows`

```flutter clean
flutter pub get
flutter run -d emulator-5554
```