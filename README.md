# Oweitu Delivery

Oweitu Delivery is a Flutter food-ordering application for Oweitu Cafe. It
provides menu browsing, cart and checkout flows, delivery tracking, rewards,
offers, account management, and customer-support screens.

> **Project status:** The user interface and local ordering flows are under
> active development. Application state is currently held in memory and the
> backend methods are placeholders; authentication, payments, and live order
> data are not yet connected to production services.

## Features

- Guest menu browsing and search
- Food categories, item details, favourites, and popular picks
- Cart quantities, special instructions, and promotional codes
- Delivery and takeaway checkout flows
- Saved delivery address selection
- Order confirmation, history, and tracking
- Rewards and points screens
- Deals, notifications, e-gift cards, gallery, and support screens
- Sign-in, registration, password recovery, profile, and settings interfaces
- Responsive layouts and bundled menu imagery

## Technology

- Flutter with Material 3
- Dart SDK `^3.11.5`
- `ChangeNotifier` and `InheritedNotifier` for application state
- Flutter widget tests

The repository contains Flutter targets for Android, iOS, web, Windows, macOS,
and Linux.

## Requirements

Install the following before running the project:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) with a compatible
  Dart SDK
- Platform tooling for the target you intend to run, such as Android Studio,
  Xcode, Chrome, or Visual Studio

Confirm the local environment is ready:

```sh
flutter doctor
```

## Getting started

Clone the repository, open its root directory, and install dependencies:

```sh
flutter pub get
```

Run the app on an available device:

```sh
flutter devices
flutter run
```

To select a specific device:

```sh
flutter run -d <device-id>
```

## Quality checks

Format and analyze the code:

```sh
dart format .
flutter analyze
```

Run the widget tests:

```sh
flutter test
```

Create a release build using the command appropriate for the target platform,
for example:

```sh
flutter build apk --release
flutter build appbundle --release
flutter build web --release
```

## Project structure

```text
.
|-- lib/
|   `-- main.dart          # App state, models, screens, and widgets
|-- assets/
|   |-- images/            # Menu and branding imagery
|   `-- icons/             # Application icons
|-- test/
|   `-- widget_test.dart   # Main user-flow widget tests
|-- android/               # Android runner
|-- ios/                   # iOS runner
|-- web/                   # Web runner
|-- windows/               # Windows runner
|-- macos/                 # macOS runner
|-- linux/                 # Linux runner
`-- pubspec.yaml           # Dependencies and asset declarations
```

Most application code currently resides in `lib/main.dart`. As the app grows,
it should be separated into feature, model, service, and shared-widget modules.

## Backend integration

`ApiService` in `lib/main.dart` describes the intended API surface and currently
throws `UnimplementedError`. Its configured base URL is:

```text
https://api.oweitu.com
```

Before a production release:

1. Move the base URL into environment-specific configuration.
2. Implement authentication, menu, checkout, and order endpoints.
3. Store credentials using secure device storage.
4. Persist appropriate cart and account state.
5. Connect and verify the payment providers.
6. Add integration and end-to-end tests for critical ordering flows.

Never commit production credentials, signing secrets, or payment keys to the
repository.

## Assets

Asset directories are registered in `pubspec.yaml`. When adding a new asset,
place it in an existing registered directory or update the `flutter.assets`
section, then run:

```sh
flutter pub get
```

Use exact, case-sensitive asset paths so builds work consistently across all
platforms.
