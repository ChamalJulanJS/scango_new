import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

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

      if (mounted) {
        await Future.delayed(Duration(milliseconds: 100));

        // Handle normal PIN verification flow
        if (widget.targetRoute == AppConstants.mainRoute) {
          String target = widget.targetRoute;
          if (widget.arguments?['initialTab'] == 1) {
            target = AppConstants.bussesRoute;
          } else if (widget.arguments?['initialTab'] == 2) {
            target = AppConstants.ticketRoute;
          } else if (widget.arguments?['initialTab'] == 3) {
            target = AppConstants.historyRoute;
          } else if (widget.arguments?['initialTab'] == 4) {
            target = AppConstants.profileRoute;
          }
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              target,
              (route) => false,
              arguments: widget.arguments,
            );
          }
        } else {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(
              widget.targetRoute,
              arguments: widget.arguments,
            );
          }
        }
      }
    } catch (e) {
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (result, resultCallback) {
        _goBackToHome();
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
