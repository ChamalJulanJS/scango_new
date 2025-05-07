import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firebase_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/create_pin_screen.dart';
import 'screens/confirm_pin_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/main_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/edit_pin_screen.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';
import 'utils/config.dart';
import 'package:flutter_gemini/flutter_gemini.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await FirebaseService.initializeFirebase();

  // Initialize Gemini API
  if (AppConfig.geminiApiKey == 'AIzaSyDslSUKSPsgiikshlUOYHNGjpjx-gBF1_k') {
    print(
        '⚠️ WARNING: Default Gemini API key detected. Please replace with your actual API key in lib/utils/config.dart');
  }

  try {
    Gemini.init(apiKey: AppConfig.geminiApiKey);
    print('✓ Gemini initialized successfully');
  } catch (e) {
    print('❌ Failed to initialize Gemini: $e');
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
        AppConstants.mainRoute: (context) => const MainScreen(),
        // The following routes are kept for backward compatibility
        // but we'll gradually transition to using mainRoute with initialTab arguments
        AppConstants.homeRoute: (context) => const MainScreen(initialTab: 0),
        AppConstants.addBusRoute: (context) => const MainScreen(initialTab: 1),
        AppConstants.ticketRoute: (context) => const MainScreen(initialTab: 2),
        AppConstants.historyRoute: (context) => const MainScreen(initialTab: 3),
        AppConstants.profileRoute: (context) => const MainScreen(initialTab: 4),
        AppConstants.editProfileRoute: (context) => const EditProfileScreen(),
        AppConstants.editPinRoute: (context) => const EditPinScreen(),
        AppConstants.checkoutRoute: (context) => const CheckoutScreen(),
        AppConstants.paymentRoute: (context) => const PaymentScreen(),
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
