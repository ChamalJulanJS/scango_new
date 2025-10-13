import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../utils/constants.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';

class NFCPaymentScreen extends StatefulWidget {
  const NFCPaymentScreen({super.key});

  @override
  State<NFCPaymentScreen> createState() => _NFCPaymentScreenState();
}

class _NFCPaymentScreenState extends State<NFCPaymentScreen> {
  int _currentIndex = 2;
  bool _isNFCListening = false;
  bool _isPaymentProcessing = false;
  bool _isPaymentComplete = false;
  bool _isNFCReady = false;
  Map<String, dynamic> _ticketDetails = {};
  String _nfcStatus = 'Checking NFC availability...';

  @override
  void initState() {
    super.initState();
    _initNFC();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _ticketDetails = args;
    }
  }

  @override
  void dispose() {
    _stopNFCListening();
    super.dispose();
  }

  Future<void> _initNFC() async {
    await _checkNFCStatus();
    if (_isNFCReady) {
      _startNFCListening();
    }
  }

  Future<void> _checkNFCStatus() async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();

      if (!isAvailable) {
        setState(() {
          _isNFCReady = false;
          _nfcStatus = 'NFC not enabled or not supported on this device';
        });
        return;
      }

      try {
        await NfcManager.instance.startSession(
          onDiscovered: (NfcTag tag) async {
            await NfcManager.instance.stopSession();
          },
        );
        await NfcManager.instance.stopSession();

        setState(() {
          _isNFCReady = true;
          _nfcStatus = 'NFC is ready. Tap your credit card to pay';
        });
      } catch (e) {
        setState(() {
          _isNFCReady = false;
          _nfcStatus = 'NFC not enabled or not supported on this device';
        });
      }
    } catch (e) {
      setState(() {
        _isNFCReady = false;
        _nfcStatus = 'NFC not enabled or not supported on this device';
      });
    }
  }

  Future<void> _startNFCListening() async {
    if (!_isNFCReady) {
      setState(() {
        _nfcStatus = 'NFC not enabled or not supported on this device';
      });
      return;
    }

    setState(() {
      _isNFCListening = true;
      _nfcStatus = 'Hold your credit card near the device';
    });

    try {
      await NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        // When any NFC tag is detected, process as payment
        await _processNFCPayment(tag);
      });
    } catch (e) {
      setState(() {
        _nfcStatus = 'NFC not enabled or not supported on this device';
        _isNFCListening = false;
        _isNFCReady = false;
      });
    }
  }

  Future<void> _stopNFCListening() async {
    try {
      await NfcManager.instance.stopSession();
      setState(() {
        _isNFCListening = false;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _processNFCPayment(NfcTag tag) async {
    // Stop NFC listening first
    await _stopNFCListening();

    setState(() {
      _isPaymentProcessing = true;
      _nfcStatus = 'Processing payment...';
    });

    // Simulate payment processing (in real app, this would validate the card)
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isPaymentProcessing = false;
      _isPaymentComplete = true;
      _nfcStatus = 'Payment successful!';
    });

    // Wait a bit and then redirect to home
    if (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        goToTicketScreen();
      }
    }
  }

  void goToTicketScreen() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppConstants.ticketRoute,
      (route) => false,
      arguments: {
        'busNumber': _ticketDetails['busNumber'],
        'pickupLocation': _ticketDetails['pickupLocation'],
      },
    );
  }

  Future<void> _retryNFC() async {
    setState(() {
      _isPaymentProcessing = false;
      _isPaymentComplete = false;
      _nfcStatus = 'Checking NFC availability...';
    });

    // Re-check NFC status
    await _checkNFCStatus();

    if (_isNFCReady) {
      // Start listening again
      _startNFCListening();
    }
  }

  Widget _buildNFCStatusWidget() {
    if (!_isNFCReady) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.nfc_outlined,
            color: AppTheme.redColor,
            size: 80,
          ),
          const SizedBox(height: 10),
          Text(
            'NFC Issue',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.redColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      );
    }

    // NFC is ready
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.contactless,
          color: _isNFCListening
              ? AppTheme.accentColor
              : AppTheme.greyColor.withValues(alpha: 0.7),
          size: 80,
        ),
        const SizedBox(height: 10),
        if (_isNFCListening)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accentColor.withValues(alpha: 0.2),
            ),
            child: const Icon(
              Icons.wifi,
              color: AppTheme.accentColor,
              size: 20,
            ),
          ),
      ],
    );
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

                      // NFC Animation/Icon
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppTheme.greyColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isNFCListening
                                ? AppTheme.accentColor
                                : !_isNFCReady
                                    ? AppTheme.redColor
                                    : AppTheme.greyColor,
                            width: 2,
                          ),
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
                                  : _buildNFCStatusWidget(),
                        ),
                      ),
                      const SizedBox(height: 30),

                      Text(
                        _isPaymentProcessing
                            ? 'Processing Payment...'
                            : _isPaymentComplete
                                ? 'Payment Successful!'
                                : 'NFC Payment',
                        style: Theme.of(context).textTheme.displayMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      if (_ticketDetails.containsKey('seatCount'))
                        Text(
                          'Seat Count: ${_ticketDetails['seatCount']}',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 15),

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
                        _nfcStatus,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),

                      // Retry button - only show when NFC is not ready
                      if (!_isPaymentProcessing &&
                          !_isPaymentComplete &&
                          !_isNFCReady)
                        SizedBox(
                          width: 200,
                          child: CustomButton(
                            text: 'Retry NFC',
                            onPressed: _retryNFC,
                            backgroundColor: AppTheme.accentColor,
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Cancel button
                      if (!_isPaymentProcessing && !_isPaymentComplete)
                        SizedBox(
                          width: 200,
                          child: CustomButton(
                            text: 'Cancel Payment',
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Payment cancelled!'),
                                  backgroundColor: AppTheme.redColor,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              goToTicketScreen();
                            },
                            backgroundColor: AppTheme.greyColor,
                            textColor: AppTheme.accentColor,
                          ),
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
                if (_isPaymentProcessing || _isNFCListening) return;

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
