import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isNFCListening = false;
  bool _isPaymentProcessing = false;
  bool _isPaymentComplete = false;

  // Flags to handle device capabilities
  bool _nfcAvailable = true;
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
    // Only start listening if NFC is actually available
    if (_nfcAvailable && _isNFCReady) {
      _startNFCListening();
    }
  }

  Future<void> _checkNFCStatus() async {
    try {
      // Check if the device actually has NFC hardware
      bool isAvailable = await NfcManager.instance.isAvailable();

      if (!mounted) return;

      setState(() {
        _nfcAvailable = isAvailable;
        if (isAvailable) {
          _isNFCReady = true;
          _nfcStatus = 'NFC is ready. Tap your credit card to pay';
        } else {
          _isNFCReady = false;
          // Show the message for non-NFC phones
          _nfcStatus = 'NFC not available or not supported on this device';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _nfcAvailable = false;
        _isNFCReady = false;
        _nfcStatus = 'NFC not available or not supported on this device';
      });
    }
  }

  Future<void> _startNFCListening() async {
    if (!_isNFCReady || !_nfcAvailable) return;

    setState(() {
      _isNFCListening = true;
      _nfcStatus = 'Hold your credit card near the device';
    });

    try {
      await NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        // NFC Tag Detected! Trigger booking automatically.
        await _processBooking();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _nfcStatus = 'Error starting NFC. Please pay manually.';
        _isNFCListening = false;
        _nfcAvailable = false; // Switch to manual mode if NFC fails
      });
    }
  }

  Future<void> _stopNFCListening() async {
    if (!_nfcAvailable) return;
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isNFCListening = false;
      });
    }
  }

  // UNIFIED BOOKING FUNCTION (Used by both NFC Tap and Manual Button)
  Future<void> _processBooking() async {
    // 1. Stop scanning if we were scanning
    await _stopNFCListening();

    if (!mounted) return;

    setState(() {
      _isPaymentProcessing = true;
      _nfcStatus = 'Processing payment...';
    });

    // Simulate processing delay
    await Future.delayed(const Duration(seconds: 2));

    try {
      final busDocId = _ticketDetails['busDocId'];
      final seatCountStr = _ticketDetails['seatCount'];
      final userId = _ticketDetails['userId'];
      // Safe parsing for seat count
      final int seats = int.tryParse(seatCountStr.toString()) ?? 0;

      if (busDocId != null && userId != null && seats > 0) {
        final busRef =
            FirebaseFirestore.instance.collection('Buses').doc(busDocId);

        // --- SAFE TRANSACTION TO PREVENT NEGATIVE SEATS ---
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final busSnapshot = await transaction.get(busRef);
          if (!busSnapshot.exists) throw Exception("Bus not found!");

          final data = busSnapshot.data() as Map<String, dynamic>;

          // Handle both String and Int types safely
          int currentAvailable = 0;
          var availableVal = data['availableSeats'];
          if (availableVal is int) {
            currentAvailable = availableVal;
          } else if (availableVal is String) {
            currentAvailable = int.tryParse(availableVal) ?? 0;
          } else {
            // Fallback if field is missing
            var totalVal = data['totalSeats'];
            currentAvailable = (totalVal is int)
                ? totalVal
                : int.tryParse(totalVal.toString()) ?? 0;
          }

          if (currentAvailable < seats) {
            throw Exception("Bus full! Only $currentAvailable seats left.");
          }

          // Deduct seats
          transaction.update(busRef, {
            'availableSeats': FieldValue.increment(-seats),
          });

          // Create Ticket
          final ticketRef =
              FirebaseFirestore.instance.collection('Ticket').doc();
          transaction.set(ticketRef, {
            'userId': userId,
            'busNumber': _ticketDetails['busNumber'],
            'pickup': _ticketDetails['pickupLocation'],
            'destination': _ticketDetails['destination'],
            'seatCount': seats,
            'totalPrice': _ticketDetails['totalPrice'],
            'timestamp': FieldValue.serverTimestamp(),
            'isUsed': false,
          });
        });
        // --------------------------------------------------

        if (!mounted) return;
        setState(() {
          _isPaymentProcessing = false;
          _isPaymentComplete = true;
          _nfcStatus = 'Payment & Booking Successful!';
        });

        // Redirect to Ticket/Home screen after success
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
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
      } else {
        throw Exception("Invalid ticket info");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _nfcStatus = 'Failed: ${e.toString().replaceAll("Exception: ", "")}';
        _isPaymentProcessing = false;
      });
      // If NFC failed, allow manual retry
      _nfcAvailable = false;
    }
  }

  Future<void> _retryNFC() async {
    await _initNFC();
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
                    children: [
                      const SizedBox(height: 20),
                      const Center(child: AppLogo()),
                      const SizedBox(height: 40),

                      // --- ANIMATED STATUS ICON ---
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppTheme.greyColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _isNFCListening
                                  ? AppTheme.accentColor
                                  : AppTheme.greyColor,
                              width: 2),
                        ),
                        child: Center(
                          child: _isPaymentProcessing
                              ? const CircularProgressIndicator(
                                  color: AppTheme.accentColor)
                              : _isPaymentComplete
                                  ? const Icon(Icons.check_circle,
                                      color: AppTheme.greenColor, size: 80)
                                  : _nfcAvailable
                                      // Show NFC Icon if supported
                                      ? Icon(Icons.contactless,
                                          size: 80,
                                          color: _isNFCListening
                                              ? AppTheme.accentColor
                                              : Colors.grey)
                                      // Show Warning Icon if NO NFC
                                      : const Icon(Icons.mobile_off,
                                          size: 80, color: AppTheme.redColor),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Status Message
                      Text(_nfcStatus,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                  color: _nfcAvailable
                                      ? Colors.black
                                      : AppTheme.redColor,
                                  fontWeight: _nfcAvailable
                                      ? FontWeight.normal
                                      : FontWeight.bold),
                          textAlign: TextAlign.center),

                      const SizedBox(height: 30),

                      // --- ACTION BUTTONS ---

                      // 1. Retry NFC (Only if NFC is theoretically available)
                      if (!_isPaymentProcessing &&
                          !_isPaymentComplete &&
                          _nfcAvailable &&
                          !_isNFCListening)
                        CustomButton(
                            text: 'Retry NFC',
                            onPressed: _retryNFC,
                            width: 200),

                      // 2. MANUAL CONFIRM BUTTON (The Fix for your problem)
                      // This appears if NFC is NOT available, allowing you to pay anyway.
                      if (!_isPaymentProcessing &&
                          !_isPaymentComplete &&
                          !_nfcAvailable)
                        Column(
                          children: [
                            const SizedBox(height: 10),
                            CustomButton(
                                text: 'Confirm Payment',
                                onPressed:
                                    _processBooking, // Calls the logic manually
                                backgroundColor: AppTheme.greenColor,
                                width: 200),
                          ],
                        ),

                      // 3. Cancel Button
                      if (!_isPaymentProcessing && !_isPaymentComplete)
                        Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: CustomButton(
                              text: 'Cancel',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Cancelled')));
                                // FIX: Redirect correctly on cancel
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  AppConstants.ticketRoute,
                                  (route) => false,
                                  arguments: {
                                    'busNumber': _ticketDetails['busNumber'],
                                    'pickupLocation':
                                        _ticketDetails['pickupLocation'],
                                  },
                                );
                              },
                              backgroundColor: AppTheme.greyColor,
                              textColor: AppTheme.accentColor,
                              width: 200),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Navigation (Index 2 is Ticket)
            CustomBottomNavigationBar(
              currentIndex: 2,
              onTap: (index) {
                if (_isPaymentProcessing || _isNFCListening) return;
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
}
