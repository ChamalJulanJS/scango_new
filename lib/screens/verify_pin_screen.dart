import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class VerifyPinScreen extends StatefulWidget {
  final String targetRoute;
  final Map<String, dynamic>? arguments;

  const VerifyPinScreen({
    super.key,
    required this.targetRoute,
    this.arguments,
  });

  @override
  State<VerifyPinScreen> createState() => _VerifyPinScreenState();
}

class _VerifyPinScreenState extends State<VerifyPinScreen> {
  String _pin = '';
  final int _pinLength = 4;
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _verifyPin() async {
    if (_pin.length < _pinLength) {
      setState(() {
        _errorMessage = 'Please enter a 4-digit PIN.';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Get user profile to verify PIN
      final user = await _authService.getUserProfile();
      if (user == null) {
        setState(() {
          _errorMessage = 'User not found.';
          _isLoading = false;
        });
        return;
      }

      // Check if PIN matches
      if (user.pin != _pin) {
        setState(() {
          _errorMessage = 'Incorrect PIN. Please try again.';
          _pin = '';
          _isLoading = false;
        });
        return;
      }

      // PIN is correct, navigate to target route
      if (mounted) {
        print(
            "PIN verified successfully. Navigating to: ${widget.targetRoute}");
        print("Arguments: ${widget.arguments}");

        // Add a small delay to ensure the navigation works properly
        await Future.delayed(Duration(milliseconds: 100));

        // Instead of just replacing the PIN screen, clear the entire navigation
        // stack to prevent issues with the back button and dropdowns
        if (widget.targetRoute == AppConstants.mainRoute) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            widget.targetRoute,
            (route) => false, // Remove all previous routes
            arguments: widget.arguments,
          );
        } else {
          // For other routes that aren't the main screen, just replace
          Navigator.of(context).pushReplacementNamed(
            widget.targetRoute,
            arguments: widget.arguments,
          );
        }
      }
    } catch (e) {
      print("Error during PIN verification: $e");
      setState(() {
        _errorMessage = 'Failed to verify PIN: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _handleKeyPress(String value) {
    if (_isLoading) return;

    setState(() {
      _errorMessage = null; // Clear error message on new key press
      if (value == 'X') {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else if (value == '>') {
        if (_pin.length == _pinLength) {
          _verifyPin();
        }
      } else if (_pin.length < _pinLength) {
        _pin += value;
        // Auto-verify when PIN length is complete
        if (_pin.length == _pinLength) {
          _verifyPin();
        }
      }
    });
  }

  // Navigate back to home page
  void _goBackToHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppConstants.homeRoute,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Handle back button press
      onWillPop: () async {
        _goBackToHome();
        return false; // Prevent default back behavior
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.accentColor),
            onPressed: _goBackToHome,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Top section with logo and title
              const Center(child: AppLogo()),
              const SizedBox(height: 40),
              Text(
                'Enter PIN',
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'Please enter your PIN to continue',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // PIN display section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 50),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.accentColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(_pinLength, (index) {
                      bool isActive = index < _pin.length;
                      return Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? AppTheme.accentColor
                              : Colors.transparent,
                          border: Border.all(
                            color: AppTheme.accentColor,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              // Error message
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: AppTheme.redColor),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Loading indicator
              const SizedBox(height: 20),
              if (_isLoading)
                const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.accentColor)),

              // Spacer to push the keypad to the bottom
              const Spacer(),

              // Custom keypad fixed at the bottom
              PinKeypad(onKeyPressed: _handleKeyPress),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
