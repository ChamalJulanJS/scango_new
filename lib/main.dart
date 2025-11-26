import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/nfc_payment_screen.dart';
import 'services/firebase_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/create_pin_screen.dart';
import 'screens/confirm_pin_screen.dart';
import 'screens/verify_pin_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/main_screen.dart';
import 'screens/add_bus_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/edit_pin_screen.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';
import 'utils/config.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await FirebaseService.initializeFirebase();

  // Initialize Gemini API
  if (AppConfig.geminiApiKey == 'AIzaSyA2spRfNLtuV5CeVaaJ-Vligmn_j6C7Cok') {
    debugPrint(
        '⚠️ WARNING: Default Gemini API key detected. Please replace with your actual API key in lib/utils/config.dart');
  }

  try {
    Gemini.init(
        apiKey: dotenv.env['AIzaSyA2spRfNLtuV5CeVaaJ-Vligmn_j6C7Cok'] ?? '');
    debugPrint('✓ Gemini initialized successfully');
  } catch (e) {
    debugPrint('❌ Failed to initialize Gemini: $e');
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'scaNGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      home: const AuthWrapper(),
      routes: {
        AppConstants.loginRoute: (context) => const LoginScreen(),
        AppConstants.signupRoute: (context) => const SignupScreen(),
        AppConstants.createPinRoute: (context) => const CreatePinScreen(),
        AppConstants.confirmPinRoute: (context) => const ConfirmPinScreen(),
        AppConstants.verifyPinRoute: (context) {
          // Extract arguments from route settings
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final targetRoute =
              args?['targetRoute'] as String? ?? AppConstants.mainRoute;
          final routeArgs = args?['arguments'] as Map<String, dynamic>?;

          return VerifyPinScreen(
            targetRoute: targetRoute,
            arguments: routeArgs,
          );
        },
        AppConstants.mainRoute: (context) => const MainScreen(),
        AppConstants.homeRoute: (context) => const MainScreen(initialTab: 0),
        AppConstants.addBusRoute: (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final busNumber = args?['busNumber'] as String?;
          final busId = args?['busId'] as String?;
          final route = args?['route'] as List<String>?;
          final totalSeats = args?['totalSeats'] as int?;
          final isEditing = args?['isEditing'] as bool?;
          return AddBusScreen(
            busNumber: busNumber,
            busId: busId,
            route: route,
            totalSeats: totalSeats,
            isEditing: isEditing ?? false,
          );
        },
        AppConstants.bussesRoute: (context) => const MainScreen(initialTab: 1),
        AppConstants.ticketRoute: (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final busNumber = args?['busNumber'] as String?;
          final pickupLocation = args?['pickupLocation'] as String?;
          return MainScreen(
              initialTab: 2,
              busNumber: busNumber,
              pickupLocation: pickupLocation);
        },
        AppConstants.historyRoute: (context) => const MainScreen(initialTab: 3),
        AppConstants.profileRoute: (context) => const MainScreen(initialTab: 4),
        AppConstants.editProfileRoute: (context) => const EditProfileScreen(),
        AppConstants.editPinRoute: (context) => const EditPinScreen(),
        AppConstants.checkoutRoute: (context) => const CheckoutScreen(),
        AppConstants.nfcPaymentRoute: (context) => const NFCPaymentScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // User is signed in
          return const MainScreen(initialTab: 0);
        } else {
          // User is not signed in
          return const LoginScreen();
        }
      },
    );
  }
}
