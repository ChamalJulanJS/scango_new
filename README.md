# ScaNGo - Bus Ticketing App

A Flutter mobile application for bus ticketing based on Figma designs.

## Features

- User authentication (Login, Sign Up, PIN creation)
- Add Bus Management
- Ticket Purchase Flow
- Trip History
- User Profile Management

## Firebase Integration

This project now has Firebase integrated for authentication, database, and storage. The Firebase configuration has been migrated from the RP-2025 project.

### Firebase Services Used

- **Firebase Authentication**: For user registration, login, and authentication state management
- **Cloud Firestore**: For storing user profiles, bus information, and ticket data
- **Firebase Storage**: For storing user profile images and other assets

### Setup Instructions

To run this project with Firebase, you'll need to:

1. **Create a Firebase project** in the [Firebase Console](https://console.firebase.google.com/)
2. **Register your app** (both Android and iOS) with Firebase
3. **Download the configuration files**:
   - For Android: `google-services.json` and place it in the `android/app/` directory
   - For iOS: `GoogleService-Info.plist` and place it in the `ios/Runner/` directory
4. **Update Firebase configuration** in `lib/services/firebase_service.dart` with your Firebase project details

### Firebase Configuration

The Firebase configuration is initialized in the `firebase_service.dart` file. Make sure to update the following values with your own Firebase project details:

```dart
static Future<void> initializeFirebase() async {
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "YOUR_API_KEY",
      authDomain: "YOUR_AUTH_DOMAIN",
      projectId: "YOUR_PROJECT_ID",
      storageBucket: "YOUR_STORAGE_BUCKET",
      messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
      appId: "YOUR_APP_ID",
      measurementId: "YOUR_MEASUREMENT_ID",
    ),
  );
}
```

### Data Models

The following models have been created to work with Firebase:

- `UserModel`: For storing user profile information
- `BusModel`: For storing bus information
- `TicketModel`: For storing ticket information

### Authentication

The app uses Firebase Authentication for user management. The following features are implemented:

- User registration with email and password
- User login with email and password
- Profile management
- Password reset

### Firestore Database

The app uses Cloud Firestore for storing data with the following collections:

- `users`: For user profiles
- `buses`: For bus information
- `tickets`: For ticket information

## Setup Instructions

1. Clone the repository
2. Install Flutter (https://flutter.dev/docs/get-started/install)
3. Get dependencies:

```
flutter pub get
```

4. Configure Firebase as described above
5. Run the app:

```
flutter run
```

## Requirements

- Flutter 3.6.1 or higher
- Dart 3.0.0 or higher

## Font Requirements

This project uses custom fonts:

- Konkhmer Sleokchher
- ADLaM Display
- Tiro Bangla

You'll need to download these fonts and place them in the `assets/fonts` directory before running the app.

## Credits

UI Design from Figma - scaNGo

## Getting Started

To run this project:

1. Install dependencies: `flutter pub get`
2. Configure Firebase as described above
3. Run the app: `flutter run`

## Flutter Development

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
