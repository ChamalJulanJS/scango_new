# scaNGo - Bus Ticketing App

A Flutter mobile application for bus ticketing with speech recognition and AI-powered natural language processing.

## Features

- User authentication with Firebase
- Bus ticket booking
- Payment processing
- Speech recognition in Sinhala
- AI-powered text extraction and translation using Google Gemini
- Ticket history tracking

## Speech Recognition Feature

The app includes a powerful speech recognition feature that:

- Listens to user speech in Sinhala
- Transcribes the speech to text
- Uses Google Gemini to extract relevant information (destination city and seat count)
- Automatically populates the booking form fields

## Setup Instructions

### 1. Firebase Setup

- Create a Firebase project
- Add Android and iOS apps to your Firebase project
- Download and place the configuration files (google-services.json and GoogleService-Info.plist)
- Enable Authentication, Firestore, and Storage services

### 2. Google Gemini API Key

- Sign up for a Google Gemini API key at https://aistudio.google.com/
- Open `lib/utils/config.dart` and replace the placeholder value with your actual API key:

```dart
static const String geminiApiKey = 'YOUR_ACTUAL_GEMINI_API_KEY';
```

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Run the App

```bash
flutter run
```

## Troubleshooting

### Gemini API Error (400 Status Code)

If you encounter errors like:

```
Error processing with Gemini: GeminiException ... status code of 400
```

Try the following:

1. **Check your API key**: Make sure you have a valid Gemini API key in `lib/utils/config.dart`
2. **Enable the API**: Ensure you've enabled the Gemini API in your Google Cloud/AI Studio project
3. **API Key Permissions**: Verify your API key has the necessary permissions to use Gemini
4. **Clean and rebuild**: Run `flutter clean` followed by `flutter pub get` and try again
5. **Check Network**: Ensure your device has internet connectivity

For speech recognition to work properly, make sure your device has the appropriate permissions enabled for microphone access.

## Usage

1. Select a bus number
2. Tap the microphone button and speak in Sinhala
   - Example: "මට කොළඹට යන්න ඕනෙ, ආසන තුනක් වෙන් කරන්න" (I want to go to Colombo, reserve three seats)
3. The app will automatically populate the destination and seat count fields
4. Select a pickup location
5. Complete the booking process

## License

[MIT License](LICENSE)
