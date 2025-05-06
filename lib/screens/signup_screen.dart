import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Validate input
      if (_usernameController.text.isEmpty ||
          _emailController.text.isEmpty ||
          _passwordController.text.isEmpty ||
          _confirmPasswordController.text.isEmpty) {
        throw Exception('Please fill in all fields');
      }

      // Validate passwords match
      if (_passwordController.text != _confirmPasswordController.text) {
        throw Exception('Passwords do not match');
      }

      // Sign up with email and password
      await _authService.signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        username: _usernameController.text.trim(),
      );

      // Navigate to create pin screen on success
      if (mounted) {
        Navigator.pushNamed(context, AppConstants.createPinRoute);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Center(child: AppLogo()),
                const SizedBox(height: 30),
                Text(
                  'Sign Up',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  hintText: 'Username',
                  controller: _usernameController,
                ),
                const SizedBox(height: 15),
                CustomTextField(
                  hintText: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),
                CustomTextField(
                  hintText: 'Password',
                  controller: _passwordController,
                  obscureText: true,
                ),
                const SizedBox(height: 15),
                CustomTextField(
                  hintText: 'Confirm Password',
                  controller: _confirmPasswordController,
                  obscureText: true,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : CustomButton(
                    text: 'Sign Up',
                          onPressed: _signUp,
                  ),
                ),
                const SizedBox(height: 20),
                const CustomDivider(text: 'Or Continue With'),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SocialLoginButton(
                      iconPath: 'assets/icons/apple.svg',
                      onPressed: () {
                        // Handle Apple signup
                      },
                    ),
                    SocialLoginButton(
                      iconPath: 'assets/icons/google.svg',
                      onPressed: () {
                        // Handle Google signup
                      },
                    ),
                    SocialLoginButton(
                      iconPath: 'assets/icons/facebook.svg',
                      onPressed: () {
                        // Handle Facebook signup
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, AppConstants.loginRoute);
                    },
                    child: Text(
                      "Already have an account? Log In",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
