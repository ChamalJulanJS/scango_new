import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _currentIndex = 2;
  Map<String, dynamic> _ticketDetails = {};
  bool _isProcessing = false;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _ticketDetails = args;

      if (_ticketDetails.containsKey('autoProcess') &&
          _ticketDetails['autoProcess'] == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _processPayment();
        });
      }
    }
  }

  Future<void> _processPayment() async {
    if (!mounted) return;

    setState(() {
      _isProcessing = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      _isComplete = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment successful!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }

    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppConstants.ticketRoute,
        (route) => false,
        arguments: {
          'initialTab': 2, 
          'busNumber': _ticketDetails['busNumber'],
          'pickupLocation': _ticketDetails['pickupLocation'],
        },
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const Center(child: AppLogo()),
                      const SizedBox(height: 30),
                      Text(
                        'Ticket Details',
                        style: Theme.of(context).textTheme.displayMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      _buildDetailItem(
                          'Bus Number', _ticketDetails['busNumber'] ?? ''),
                      const SizedBox(height: 20),
                      _buildDetailItem('Pickup Location',
                          _ticketDetails['pickupLocation'] ?? ''),
                      const SizedBox(height: 20),
                      _buildDetailItem(
                          'Destination', _ticketDetails['destination'] ?? ''),
                      const SizedBox(height: 20),
                      _buildDetailItem(
                          'Seat Count', _ticketDetails['seatCount'] ?? ''),
                      const SizedBox(height: 20),
                      _buildDetailItem('Price',
                          'Rs. ${_ticketDetails['totalPrice']?.toStringAsFixed(0) ?? _calculatePrice()}'),
                      const SizedBox(height: 40),

                      if (_isProcessing)
                        Center(
                          child: Column(
                            children: [
                              const CircularProgressIndicator(
                                color: AppTheme.accentColor,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Processing payment...',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: AppTheme.accentColor,
                                    ),
                              ),
                            ],
                          ),
                        )
                      else if (_isComplete)
                        Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: AppTheme.greenColor,
                                size: 60,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Payment Complete!',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: AppTheme.greenColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        )
                      else if (!_ticketDetails.containsKey('autoProcess'))
                        Column(
                          children: [
                            Text(
                              'Checkout',
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: CustomButton(
                                    text: 'Modify',
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    backgroundColor: AppTheme.greyColor,
                                    textColor: AppTheme.accentColor,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: CustomButton(
                                    text: 'Pay',
                                    onPressed: _processPayment,
                                    backgroundColor: AppTheme.accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                if (_isProcessing) return;

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
                    Navigator.pop(context);
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

  Widget _buildDetailItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: AppTheme.accentColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.primaryColor,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.primaryColor,
                ),
          ),
        ],
      ),
    );
  }

  int _calculatePrice() {
    // Simple price calculation based on seat count
    final seatCount = int.tryParse(_ticketDetails['seatCount'] ?? '1') ?? 1;
    return seatCount * 150; // Rs. 150 per seat
  }
}
