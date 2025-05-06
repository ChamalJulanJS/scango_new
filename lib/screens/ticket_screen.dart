import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'dart:developer';
import '../utils/constants.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key});

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Speech to text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isProcessing = false;
  String _lastWords = '';
  bool _speechEnabled = false;

  String? _selectedBusNumber;
  String? _selectedPickupLocation;

  // Controllers for the text fields
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _seatCountController = TextEditingController();

  // Data from Firebase
  List<String> _busNumbers = [];
  List<String> _pickupLocations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchBusNumbers();
    _initSpeech();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _seatCountController.dispose();
    super.dispose();
  }

  // Initialize speech recognition
  void _initSpeech() async {
    _speechEnabled = await _speech.initialize(
      onError: (error) {
        log('Speech error: $error');
        setState(() {
          _isListening = false;
        });
      },
      onStatus: (status) {
        log('Speech status: $status');
        // Update UI based on status
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _isListening = false;
            _isProcessing = true;
          });

          // Show processing state briefly
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              setState(() {
                _isProcessing = false;
              });
            }
          });
        }
      },
    );
    setState(() {});

    // Check if Sinhala is available
    _checkLanguageAvailability();
  }

  // Check if Sinhala language is available
  void _checkLanguageAvailability() async {
    try {
      final languages = await _speech.locales();
      final sinhalaLocale = languages
          .where((locale) =>
              locale.localeId.contains('si') ||
              locale.localeId.contains('LK') ||
              locale.localeId.toLowerCase() == 'si-lk')
          .toList();

      if (sinhalaLocale.isNotEmpty) {
        log('Sinhala language found: ${sinhalaLocale.map((e) => e.localeId).join(', ')}');
      } else {
        log('Sinhala language not found in available languages');
        log('Available languages: ${languages.map((e) => e.localeId).join(', ')}');
      }
    } catch (e) {
      log('Error checking language availability: $e');
    }
  }

  // Start listening to speech
  void _startListening() async {
    if (!_speechEnabled) {
      log('Speech recognition not available');
      return;
    }

    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(),
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 10),
      partialResults: true,
      localeId: 'si-LK',
      cancelOnError: true,
      listenMode: stt.ListenMode.confirmation,
    );

    setState(() {
      _isListening = true;
    });
  }

  // Stop listening to speech
  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  // Handle speech recognition results
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });

    // Log the transcribed text
    log('Transcribed text: ${result.recognizedWords}');

    // If the speech result is final, you can decide what to do with it
    if (result.finalResult) {
      // For now, just log it, but later you can use it to populate fields
      log('FINAL result: ${result.recognizedWords}');
    }
  }

  // Fetch bus numbers from Firebase Buses collection
  Future<void> _fetchBusNumbers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final busesSnapshot = await _firestore.collection('Buses').get();

      final buses = busesSnapshot.docs.map((doc) {
        return doc.data()['busNumber'] as String;
      }).toList();

      setState(() {
        _busNumbers = buses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load bus numbers: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Fetch pickup locations (routes) for the selected bus
  Future<void> _fetchPickupLocations(String busNumber) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _pickupLocations = [];
      _selectedPickupLocation = null;
    });

    try {
      final busDoc = await _firestore
          .collection('Buses')
          .where('busNumber', isEqualTo: busNumber)
          .get();

      if (busDoc.docs.isNotEmpty) {
        final routes =
            List<String>.from(busDoc.docs.first.data()['route'] ?? []);

        setState(() {
          _pickupLocations = routes;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Bus routes not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load pickup locations: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Calculate total price based on seat count
  double _calculateTotalPrice() {
    final seatCount = int.tryParse(_seatCountController.text) ?? 0;
    return seatCount * 100.0;
  }

  // Submit ticket data to Firebase
  Future<void> _submitTicket() async {
    // Validate inputs
    if (_selectedBusNumber == null) {
      _showError('Please select a bus number');
      return;
    }

    if (_selectedPickupLocation == null) {
      _showError('Please select a pickup location');
      return;
    }

    if (_destinationController.text.isEmpty) {
      _showError('Please enter a destination');
      return;
    }

    if (_seatCountController.text.isEmpty) {
      _showError('Please enter the number of seats');
      return;
    }

    final seatCount = int.tryParse(_seatCountController.text);
    if (seatCount == null || seatCount <= 0) {
      _showError('Please enter a valid seat count');
      return;
    }

    final totalPrice = _calculateTotalPrice();

    // Show processing state
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Show a processing message to the user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Processing your ticket...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      // Get current user ID
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        _showError('User not authenticated');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Create new ticket document
      await _firestore.collection('Ticket').add({
        'userId': userId,
        'busNumber': _selectedBusNumber,
        'pickup': _selectedPickupLocation,
        'destination': _destinationController.text.trim(),
        'seatCount': seatCount,
        'totalPrice': totalPrice,
        'timestamp': FieldValue.serverTimestamp(),
        'isUsed': false,
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket created successfully!'),
          backgroundColor: AppTheme.greenColor,
          duration: Duration(seconds: 1),
        ),
      );

      // Use addPostFrameCallback to navigate after the current frame completes
      // This prevents ScrollController not attached errors
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushNamed(
            context,
            AppConstants.checkoutRoute,
            arguments: {
              'busNumber': _selectedBusNumber,
              'pickupLocation': _selectedPickupLocation,
              'destination': _destinationController.text.trim(),
              'seatCount': _seatCountController.text,
              'totalPrice': totalPrice,
            },
          );
        });
      }
    } catch (e) {
      _showError('Failed to submit ticket: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.redColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          const Center(child: AppLogo()),
                          const SizedBox(height: 30),

                          // Voice recognition button
                          Center(
                            child: Column(
                              children: [
                                InkWell(
                                  onTap: _isProcessing
                                      ? null
                                      : (_isListening
                                          ? _stopListening
                                          : _startListening),
                                  borderRadius: BorderRadius.circular(50),
                                  child: Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      color: _isProcessing
                                          ? AppTheme.greyColor
                                          : _isListening
                                              ? AppTheme.accentColor
                                              : AppTheme.greyColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _isProcessing
                                          ? Icons.hourglass_top
                                          : _isListening
                                              ? Icons.mic
                                              : Icons.mic_none,
                                      color: _isProcessing
                                          ? AppTheme.accentColor
                                          : _isListening
                                              ? Colors.white
                                              : AppTheme.accentColor,
                                      size: 40,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isProcessing
                                      ? "Processing..."
                                      : _isListening
                                          ? "Listening in Sinhala..."
                                          : "Tap to talk",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.accentColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                                if (_lastWords.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 12.0, bottom: 12.0),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: AppTheme.lightGreyColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: AppTheme.accentColor
                                                .withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        _lastWords,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppTheme.accentColor,
                                              fontStyle: _isListening
                                                  ? FontStyle.italic
                                                  : FontStyle.normal,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Bus Number Dropdown
                          Text(
                            'Bus Number',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdown(
                            value: _selectedBusNumber,
                            items: _busNumbers,
                            hint: 'Select bus number',
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedBusNumber = value;
                                      _selectedPickupLocation = null;
                                    });
                                    if (value != null) {
                                      _fetchPickupLocations(value);
                                    }
                                  },
                          ),
                          const SizedBox(height: 20),

                          // Pickup Location Dropdown
                          Text(
                            'Pickup Location',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdown(
                            value: _selectedPickupLocation,
                            items: _pickupLocations,
                            hint: _selectedBusNumber == null
                                ? 'Select a bus number first'
                                : _isLoading
                                    ? 'Loading locations...'
                                    : 'Select pickup location',
                            onChanged: _selectedBusNumber == null || _isLoading
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedPickupLocation = value;
                                    });
                                  },
                          ),
                          const SizedBox(height: 20),

                          // Destination TextField (changed from dropdown)
                          Text(
                            'Destination',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _destinationController,
                            decoration: InputDecoration(
                              hintText: 'Enter destination',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide: const BorderSide(
                                    color: AppTheme.accentColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide: const BorderSide(
                                    color: AppTheme.accentColor, width: 2.0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Seat Count TextField (changed from dropdown, numeric only)
                          Text(
                            'Seat Count',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _seatCountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              hintText: 'Enter number of seats',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide: const BorderSide(
                                    color: AppTheme.accentColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide: const BorderSide(
                                    color: AppTheme.accentColor, width: 2.0),
                              ),
                            ),
                            onChanged: (value) {
                              // Trigger rebuild to update total price
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 30),

                          // Total Price Display
                          if (_seatCountController.text.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(15.0),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor,
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: Text(
                                'Total Price: Rs. ${_calculateTotalPrice().toStringAsFixed(0)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const SizedBox(height: 30),

                          // Error message display
                          if (_errorMessage != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10.0),
                              decoration: BoxDecoration(
                                color: AppTheme.redColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: AppTheme.redColor),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          // Checkout Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: CustomButton(
                                  text:
                                      _isLoading ? 'Processing...' : 'Checkout',
                                  onPressed: _isLoading
                                      ? () {}
                                      : () => _submitTicket(),
                                  backgroundColor: _canProceedToCheckout()
                                      ? AppTheme.accentColor
                                      : AppTheme.greyColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // Loading overlay
                  if (_isLoading)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: AppTheme.accentColor,
                                strokeWidth: 3,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedBusNumber != null &&
                                        _pickupLocations.isEmpty
                                    ? 'Loading routes...'
                                    : 'Loading...',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppTheme.accentColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Error message overlay
                  if (!_isLoading && _errorMessage != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: AppTheme.redColor.withOpacity(0.9),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(
                          _errorMessage!,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required void Function(String?)? onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.accentColor),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }).toList(),
          onChanged: onChanged,
          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.accentColor),
          isExpanded: true,
          dropdownColor: AppTheme.primaryColor,
        ),
      ),
    );
  }

  bool _canProceedToCheckout() {
    return _selectedBusNumber != null &&
        _selectedPickupLocation != null &&
        _destinationController.text.isNotEmpty &&
        _seatCountController.text.isNotEmpty &&
        (int.tryParse(_seatCountController.text) ?? 0) > 0;
  }
}
