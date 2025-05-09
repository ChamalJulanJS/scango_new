import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class EditPinScreen extends StatefulWidget {
  const EditPinScreen({super.key});

  @override
  State<EditPinScreen> createState() => _EditPinScreenState();
}

class _EditPinScreenState extends State<EditPinScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  
  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }
  
  Future<void> _savePin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    try {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });
      
      await _authService.updateUserProfile(
        pin: _pinController.text.trim(),
      );
      
      setState(() {
        _isSaving = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN updated successfully'),
            backgroundColor: AppTheme.greenColor,
          ),
        );
        Navigator.pop(context, true); // Pass true to indicate update was successful
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update PIN: ${e.toString()}';
        _isSaving = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit PIN'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.accentColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentColor),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Security icon
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.greyColor,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.security,
                              size: 60,
                              color: AppTheme.accentColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // Pin info text
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppTheme.accentColor,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your PIN is used to verify your identity when scanning tickets.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.accentColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // PIN field
                      Text(
                        'New PIN',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _pinController,
                        obscureText: _obscurePin,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: InputDecoration(
                          hintText: 'Enter 4-digit PIN',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppTheme.accentColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppTheme.accentColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePin ? Icons.visibility_off : Icons.visibility,
                              color: AppTheme.accentColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePin = !_obscurePin;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'PIN is required';
                          }
                          if (value.length != 4) {
                            return 'PIN must be 4 digits';
                          }
                          return null;
                        },
                        enabled: !_isSaving,
                      ),
                      const SizedBox(height: 24),
                      
                      // Confirm PIN field
                      Text(
                        'Confirm PIN',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _confirmPinController,
                        obscureText: _obscureConfirmPin,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: InputDecoration(
                          hintText: 'Confirm your PIN',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppTheme.accentColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppTheme.accentColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPin ? Icons.visibility_off : Icons.visibility,
                              color: AppTheme.accentColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPin = !_obscureConfirmPin;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please confirm your PIN';
                          }
                          if (value != _pinController.text) {
                            return 'PINs do not match';
                          }
                          return null;
                        },
                        enabled: !_isSaving,
                      ),
                      const SizedBox(height: 24),
                      
                      // Error message
                      if (_errorMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.redColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.redColor),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: AppTheme.redColor),
                          ),
                        ),
                      
                      const SizedBox(height: 30),
                      
                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: CustomButton(
                          text: _isSaving ? 'Saving...' : 'Save PIN',
                          onPressed: _isSaving ? () {} : _savePin,
                          backgroundColor: AppTheme.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }
} 