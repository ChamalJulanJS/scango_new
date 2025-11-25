import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class ConfirmPinScreen extends StatefulWidget {
  const ConfirmPinScreen({super.key});

  @override
  State<ConfirmPinScreen> createState() => _ConfirmPinScreenState();
}

class _ConfirmPinScreenState extends State<ConfirmPinScreen> {
  String _pin = '';
  final int _pinLength = 4;
  String? _originalPin;
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _originalPin = ModalRoute.of(context)?.settings.arguments as String?;
  }

  Future<void> _savePin() async {
    if (_pin != _originalPin) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN does not match. Please try again.'),
          backgroundColor: AppTheme.redColor,
        ),
      );
      setState(() {
        _pin = '';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // Save PIN to user profile
      await _authService.updateUserProfile(pin: _pin);

      // Navigate to home screen
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.homeRoute,
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save PIN: ${e.toString()}'),
            backgroundColor: AppTheme.redColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleKeyPress(String value) {
    if (_isLoading) return;

    setState(() {
      if (value == 'X') {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else if (value == '>') {
        if (_pin.length == _pinLength) {
          _savePin();
        }
      } else if (_pin.length < _pinLength) {
        _pin += value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top section with logo and title
            const SizedBox(height: 20),
            const Center(child: AppLogo()),
            const SizedBox(height: 40),
            Text(
              'Confirm Pin',
              style: Theme.of(context).textTheme.displayMedium,
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
            
            // Loading indicator
            const SizedBox(height: 20),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            
            // Spacer to push the keypad to the bottom
            const Spacer(),
            
            // Custom keypad fixed at the bottom
            PinKeypad(onKeyPressed: _handleKeyPress),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
