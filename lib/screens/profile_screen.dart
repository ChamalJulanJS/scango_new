import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  UserModel? _user;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
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
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load profile: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppConstants.loginRoute);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log out: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: AppTheme.accentColor,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading profile...',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.accentColor,
                                ),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppTheme.redColor,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _errorMessage!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.redColor,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                CustomButton(
                                  text: 'Try Again',
                                  onPressed: _loadUserProfile,
                                  backgroundColor: AppTheme.accentColor,
                                ),
                              ],
                            ),
                          ),
                        )
                      : _user == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.person_off,
                                    color: AppTheme.accentColor,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No user data found',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppTheme.accentColor,
                                        ),
                                  ),
                                  const SizedBox(height: 24),
                                  CustomButton(
                                    text: 'Log Out',
                                    onPressed: _logout,
                                    backgroundColor: AppTheme.redColor,
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 20),
                                    const Center(child: AppLogo()),
                                    const SizedBox(height: 30),
                                    // Profile avatar placeholder
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
                                    _buildProfileItem('Username',
                                        _user?.username ?? 'Not set'),
                                    const SizedBox(height: 20),
                                    _buildProfileItem(
                                        'Email', _user?.email ?? ''),
                                    const SizedBox(height: 20),
                                    _buildProfileItem(
                                        'PIN',
                                        _user?.pin != null
                                            ? '****'
                                            : 'Not set'),
                                    const SizedBox(height: 20),
                                    _buildProfileItem('Joined',
                                        _formatDate(_user?.timestamp)),
                                    const SizedBox(height: 30),
                                    _buildActionButton(
                                      'Edit Profile',
                                      Icons.edit,
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          AppConstants.editProfileRoute,
                                        ).then((result) {
                                          if (result == true) {
                                            _loadUserProfile();
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    _buildActionButton(
                                      'Edit Pin',
                                      Icons.lock,
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          AppConstants.editPinRoute,
                                        ).then((result) {
                                          if (result == true) {
                                            _loadUserProfile();
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 40),
                                    SizedBox(
                                      width: double.infinity,
                                      child: CustomButton(
                                        text: 'Log Out',
                                        onPressed: _logout,
                                        backgroundColor: AppTheme.redColor,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not available';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildProfileItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.greyColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String text, IconData icon,
      {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accentColor),
          const SizedBox(width: 10),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
