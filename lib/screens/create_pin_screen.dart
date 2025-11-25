import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';

class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key});

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  String _pin = '';
  final int _pinLength = 4;

  void _handleKeyPress(String value) {
    setState(() {
      if (value == 'X') {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else if (value == '>') {
        if (_pin.length == _pinLength) {
          // Navigate to confirm pin screen
          Navigator.pushNamed(
            context,
            AppConstants.confirmPinRoute,
            arguments: _pin,
          );
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
              'Create New Pin',
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
