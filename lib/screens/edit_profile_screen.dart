import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCheckingUsername = false;
  UserModel? _user;
  String? _errorMessage;
  String? _usernameError;
  Timer? _debounce;

  // Previous username to compare against
  String? _originalUsername;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final newUsername = _usernameController.text.trim();

    // Skip validation if it's the same as original username
    if (newUsername == _originalUsername) {
      setState(() {
        _usernameError = null;
      });
      return;
    }

    // Clear the previous timer if it exists
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Skip validation if username is empty
    if (newUsername.isEmpty) {
      setState(() {
        _usernameError = null;
      });
      return;
    }

    // Set a new timer
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _validateUsername(newUsername);
    });
  }

  Future<void> _validateUsername(String username) async {
    try {
      setState(() {
        _isCheckingUsername = true;
      });

      final exists = await _authService.usernameExists(username);

      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _usernameError = exists ? 'Username already exists' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _usernameError =
              null; // Clear error on exception, we'll validate on final submit
        });
      }
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = await _authService.getUserProfile();

      setState(() {
        _user = user;
        _isLoading = false;
        if (user != null && user.username != null) {
          _usernameController.text = user.username!;
          _originalUsername = user.username;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    // Manual check for username uniqueness
    if (_usernameError != null || _isCheckingUsername) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newUsername = _usernameController.text.trim();

    // Skip the check if username hasn't changed
    if (newUsername != _originalUsername) {
      try {
        setState(() {
          _isSaving = true;
          _errorMessage = null;
        });

        // Final check before saving
        final exists = await _authService.usernameExists(newUsername);

        if (exists) {
          setState(() {
            _isSaving = false;
            _usernameError = 'Username already exists';
          });
          return;
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to validate username: ${e.toString()}';
          _isSaving = false;
        });
        return;
      }
    }

    try {
      await _authService.updateUserProfile(
        username: newUsername,
      );

      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppTheme.greenColor,
          ),
        );
        Navigator.pop(
            context, true); // Pass true to indicate update was successful
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update profile: ${e.toString()}';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.accentColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.accentColor),
              )
            : _user == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppTheme.redColor,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text('User profile not found'),
                        const SizedBox(height: 24),
                        CustomButton(
                          text: 'Go Back',
                          onPressed: () => Navigator.pop(context),
                          backgroundColor: AppTheme.accentColor,
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar placeholder
                            Center(
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.greyColor,
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Email display (non-editable)
                            Text(
                              'Email',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.greyColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _user?.email ?? '',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Username field
                            Text(
                              'Username',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                hintText: 'Enter your username',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: AppTheme.accentColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: AppTheme.accentColor, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                errorText: _usernameError,
                                suffixIcon: _isCheckingUsername
                                    ? Container(
                                        width: 24,
                                        height: 24,
                                        padding: const EdgeInsets.all(8),
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.accentColor,
                                        ),
                                      )
                                    : _usernameError == null &&
                                            _usernameController.text.isNotEmpty
                                        ? const Icon(Icons.check_circle,
                                            color: AppTheme.greenColor)
                                        : null,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Username is required';
                                }
                                return _usernameError;
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
                                text: _isSaving ? 'Saving...' : 'Save Changes',
                                onPressed: (_isSaving || _isCheckingUsername)
                                    ? () {}
                                    : _saveProfile,
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
