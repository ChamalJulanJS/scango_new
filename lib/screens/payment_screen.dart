import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  int _currentIndex = 2;
  bool _isPaymentProcessing = false;
  bool _isPaymentComplete = false;
  Map<String, dynamic> _ticketDetails = {};

  @override
  void initState() {
    super.initState();
    _processPayment();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _ticketDetails = args;
    }
  }

  Future<void> _processPayment() async {
    setState(() {
      _isPaymentProcessing = true;
    });

    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isPaymentProcessing = false;
      _isPaymentComplete = true;
    });

    // Wait a bit and then go back to home
    if (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      Navigator.pushNamedAndRemoveUntil(
        // ignore: use_build_context_synchronously
        context,
        AppConstants.homeRoute,
        (route) => false,
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
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      const Center(child: AppLogo()),
                      const SizedBox(height: 40),
                      // QR Code placeholder (in a real app, this would be a real QR code)
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppTheme.greyColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: _isPaymentProcessing
                              ? const CircularProgressIndicator(
                                  color: AppTheme.accentColor,
                                )
                              : _isPaymentComplete
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: AppTheme.greenColor,
                                      size: 80,
                                    )
                                  : const Text('QR Code'),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        _isPaymentProcessing
                            ? 'Processing Payment...'
                            : _isPaymentComplete
                                ? 'Payment Successful!'
                                : 'Pay Now',
                        style: Theme.of(context).textTheme.displayMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      // Show total price amount
                      if (_ticketDetails.containsKey('totalPrice'))
                        Text(
                          'Amount: Rs. ${_ticketDetails['totalPrice']?.toStringAsFixed(0)}',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 20),
                      Text(
                        _isPaymentProcessing
                            ? 'Please wait while we process your payment.'
                            : _isPaymentComplete
                                ? 'Thank you for your purchase!'
                                : 'Scan the QR code to complete payment.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            CustomBottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                if (_isPaymentProcessing) return;

                setState(() {
                  _currentIndex = index;
                });

                switch (index) {
                  case 0:
                    Navigator.pushNamedAndRemoveUntil(
                        context, AppConstants.mainRoute, (route) => false);
                    break;
                  case 1:
                    Navigator.pushNamedAndRemoveUntil(
                        context, AppConstants.mainRoute, (route) => false,
                        arguments: {'initialTab': 1});
                    break;
                  case 2:
                    // Already on payment screen or navigate back to ticket
                    if (_isPaymentComplete) {
                      Navigator.pushNamedAndRemoveUntil(
                          context, AppConstants.mainRoute, (route) => false,
                          arguments: {'initialTab': 2});
                    }
                    break;
                  case 3:
                    Navigator.pushNamedAndRemoveUntil(
                        context, AppConstants.mainRoute, (route) => false,
                        arguments: {'initialTab': 3});
                    break;
                  case 4:
                    Navigator.pushNamedAndRemoveUntil(
                        context, AppConstants.mainRoute, (route) => false,
                        arguments: {'initialTab': 4});
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
