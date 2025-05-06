import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Validate input
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        throw Exception('Please fill in all fields');
      }

      // Sign in with email and password
      await _authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Navigate to home screen on success
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppConstants.homeRoute);
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
                const SizedBox(height: 40),
                const Center(child: AppLogo()),
                const SizedBox(height: 60),
                Text(
                  'Login',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 30),
                CustomTextField(
                  hintText: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  hintText: 'Password',
                  controller: _passwordController,
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
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : CustomButton(
                          text: 'Log In',
                          onPressed: _login,
                        ),
                ),
                const SizedBox(height: 30),
                const CustomDivider(text: 'Or Continue With'),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SocialLoginButton(
                      iconPath: 'assets/icons/apple.svg',
                      onPressed: () {
                        // Handle Apple login
                      },
                    ),
                    SocialLoginButton(
                      iconPath: 'assets/icons/google.svg',
                      onPressed: () {
                        // Handle Google login
                      },
                    ),
                    SocialLoginButton(
                      iconPath: 'assets/icons/facebook.svg',
                      onPressed: () {
                        // Handle Facebook login
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, AppConstants.signupRoute);
                    },
                    child: Text(
                      "Don't have an account? Sign Up",
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
