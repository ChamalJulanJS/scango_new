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
import 'package:flutter_gemini/flutter_gemini.dart';
import 'dart:convert';
import '../utils/config.dart';

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
  // Gemini instance
  final Gemini _gemini = Gemini.instance;

  String? _selectedBusNumber;
  String? _selectedPickupLocation;

  // Controllers for the text fields
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _seatCountController = TextEditingController();

  // Data from Firebase
  List<String> _busNumbers = [];
  List<String> _pickupLocations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBusNumbers();
    _initSpeech();
    _initGemini();
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
          });

          // Only set processing state if we're not already processing (for Gemini)
          // This prevents overriding the Gemini processing state
          if (!_isProcessing) {
            setState(() {
              _isProcessing = true;
            });

            // Show processing state briefly, then reset
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                setState(() {
                  _isProcessing = false;
                });
              }
            });
          }
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
    try {
      await _speech.stop();
      // Inform the user that listening has stopped
      _showInfoSnackBar('Speech recognition stopped');
    } catch (e) {
      log('Error stopping speech recognition: $e');
    } finally {
      // Ensure the state is updated regardless of whether the stop call succeeded
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
    }
  }

  // Handle speech recognition results
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });

    // Log the transcribed text
    log('Transcribed text: ${result.recognizedWords}');

    // If the speech result is final, process it with Gemini
    if (result.finalResult && result.recognizedWords.isNotEmpty) {
      log('FINAL result: ${result.recognizedWords}');
      _processSinhalaTextWithGemini(result.recognizedWords);
    }
  }

  // Process Sinhala text with Gemini
  Future<void> _processSinhalaTextWithGemini(String sinhalaText) async {
    // Make sure speech recognition is stopped
    if (_isListening) {
      _stopListening();
    }

    setState(() {
      _isProcessing = true;
    });

    // Show a processing message to the user
    _showInfoSnackBar('Processing your speech...');

    try {
      // Simplified prompt that works better with Gemini API
      final String systemPrompt = """
Extract the city name and number of seats from this Sinhala text.
Return as JSON with "city" in English and "seats" as a number.
If not found, use null.
Examples:
"මට කොළඹට යන්න ඕනෙ, ආසන තුනක් වෙන් කරන්න" → {"city": "Colombo", "seats": 3}
"ගාල්ලට ආසන දෙකක් වෙන් කරන්න" → {"city": "Galle", "seats": 2}
"මහනුවර" → {"city": "Kandy", "seats": null}
""";

      // First try a text-only approach which is more reliable for Gemini
      try {
        final prompt = "$systemPrompt\nText: $sinhalaText\nJSON:";
        final response = await _gemini.text(prompt);

        if (response != null && response.output != null) {
          log('Gemini text response: ${response.output}');

          // Try to parse JSON from the response
          final jsonResponse = _extractJsonFromResponse(response.output!);
          if (jsonResponse != null) {
            // Update UI with extracted information
            _updateFieldsFromGeminiResponse(jsonResponse);

            // Show success message
            _showSuccessSnackBar('Information extracted successfully!');
            return; // Success with text method
          }
        }
      } catch (e) {
        log('Text method failed, trying chat method: $e');
      }

      // If text method fails, try chat method as fallback
      final content = [
        Content(
          parts: [Part.text(systemPrompt)],
          role: 'user',
        ),
        Content(
          parts: [Part.text("Text: $sinhalaText\nJSON:")],
          role: 'model',
        ),
      ];

      // Call Gemini API
      final response = await _gemini.chat(content);

      if (response != null && response.output != null) {
        log('Gemini chat response: ${response.output}');

        try {
          // Try to parse JSON from the response
          final jsonResponse = _extractJsonFromResponse(response.output!);
          if (jsonResponse != null) {
            // Update UI with extracted information
            _updateFieldsFromGeminiResponse(jsonResponse);

            // Show success message
            _showSuccessSnackBar('Information extracted successfully!');
          } else {
            log('Failed to extract JSON from Gemini response');
            _showErrorSnackBar('Could not extract information from speech');
          }
        } catch (e) {
          log('Error parsing Gemini response: $e');
          _showErrorSnackBar('Error parsing response: $e');
        }
      }
    } catch (e) {
      log('Error processing with Gemini: $e');
      _showErrorSnackBar('Error processing with AI: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isListening = false;
        });
      }
    }
  }

  // Extract JSON from Gemini's text response
  Map<String, dynamic>? _extractJsonFromResponse(String response) {
    try {
      // First try to directly parse the entire response as JSON
      try {
        return json.decode(response) as Map<String, dynamic>;
      } catch (_) {
        // If that fails, try to extract JSON using regex
      }

      // Look for JSON pattern in the response using regex
      final RegExp jsonRegExp = RegExp(r'{[\s\S]*}');
      final Match? match = jsonRegExp.firstMatch(response);

      if (match != null) {
        final String jsonString = match.group(0)!;
        return json.decode(jsonString) as Map<String, dynamic>;
      }

      // If no JSON pattern found with regex, look for key-value pattern
      if (response.contains('"city"') && response.contains('"seats"')) {
        // Try to construct a valid JSON from the response
        String cleanedResponse =
            response.replaceAll(RegExp(r'\s+'), ' ').trim();
        // Create a simple JSON structure
        if (!cleanedResponse.startsWith('{'))
          cleanedResponse = '{$cleanedResponse';
        if (!cleanedResponse.endsWith('}'))
          cleanedResponse = '$cleanedResponse}';

        return json.decode(cleanedResponse) as Map<String, dynamic>;
      }

      // Last resort: extract values manually
      final RegExp cityRegExp = RegExp(r'"city"\s*:\s*"([^"]+)"');
      final RegExp seatsRegExp = RegExp(r'"seats"\s*:\s*(\d+|null)');

      final cityMatch = cityRegExp.firstMatch(response);
      final seatsMatch = seatsRegExp.firstMatch(response);

      if (cityMatch != null || seatsMatch != null) {
        final result = <String, dynamic>{};
        if (cityMatch != null) {
          result['city'] = cityMatch.group(1);
        }
        if (seatsMatch != null) {
          final seatsValue = seatsMatch.group(1);
          result['seats'] =
              seatsValue == 'null' ? null : int.parse(seatsValue!);
        }
        return result;
      }

      log('Could not extract JSON from: $response');
      return null;
    } catch (e) {
      log('JSON extraction error: $e');
      return null;
    }
  }

  // Update form fields from Gemini response
  void _updateFieldsFromGeminiResponse(Map<String, dynamic> jsonResponse) {
    if (mounted) {
      setState(() {
        // Update destination field if city is available
        if (jsonResponse.containsKey('city') && jsonResponse['city'] != null) {
          _destinationController.text = jsonResponse['city'].toString();
        }

        // Update seat count field if seats is available
        if (jsonResponse.containsKey('seats') &&
            jsonResponse['seats'] != null) {
          _seatCountController.text = jsonResponse['seats'].toString();
        }

        // Ensure both listening and processing states are turned off
        _isListening = false;
        _isProcessing = false;
      });
    }
  }

  // Fetch bus numbers from Firebase Buses collection
  Future<void> _fetchBusNumbers() async {
    setState(() {
      _isLoading = true;
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
      _showErrorSnackBar('Failed to load bus numbers: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fetch pickup locations (routes) for the selected bus
  Future<void> _fetchPickupLocations(String busNumber) async {
    setState(() {
      _isLoading = true;
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
        _showErrorSnackBar('Bus routes not found');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load pickup locations: ${e.toString()}');
      setState(() {
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
      _showErrorSnackBar('Please select a bus number');
      return;
    }

    if (_selectedPickupLocation == null) {
      _showErrorSnackBar('Please select a pickup location');
      return;
    }

    if (_destinationController.text.isEmpty) {
      _showErrorSnackBar('Please enter a destination');
      return;
    }

    if (_seatCountController.text.isEmpty) {
      _showErrorSnackBar('Please enter the number of seats');
      return;
    }

    final seatCount = int.tryParse(_seatCountController.text);
    if (seatCount == null || seatCount <= 0) {
      _showErrorSnackBar('Please enter a valid seat count');
      return;
    }

    final totalPrice = _calculateTotalPrice();

    // Show processing state
    setState(() {
      _isLoading = true;
    });

    // Show a processing message to the user
    _showInfoSnackBar('Processing your ticket...');

    try {
      // Get current user ID
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        _showErrorSnackBar('User not authenticated');
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
      _showSuccessSnackBar('Ticket created successfully!');

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
      _showErrorSnackBar('Failed to submit ticket: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Shows error as SnackBar without updating _errorMessage state
  void _showErrorSnackBar(String message) {
    // Clear any existing SnackBars
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.redColor,
        duration: const Duration(seconds: 2),
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
                                      ? null // Disable while processing
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
                                      ? "Processing speech with AI..."
                                      : _isListening
                                          ? "Listening in Sinhala..."
                                          : "Tap to speak destination & seats",
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
                                      child: Column(
                                        children: [
                                          Text(
                                            'Transcribed Sinhala:',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppTheme.accentColor
                                                      .withOpacity(0.7),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
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
                                        ],
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

  // Initialize Gemini
  void _initGemini() {
    try {
      // This ensures Gemini is initialized properly
      if (AppConfig.geminiApiKey == 'AIzaSyDslSUKSPsgiikshlUOYHNGjpjx-gBF1_k') {
        log('WARNING: Using default Gemini API key. Replace with your actual key in config.dart');
      }

      // Test if Gemini is already initialized
      final gemini = Gemini.instance;
      log('Gemini initialized successfully in TicketScreen');
    } catch (e) {
      log('Error initializing Gemini: $e');

      // Try to initialize with the API key
      try {
        Gemini.init(apiKey: AppConfig.geminiApiKey);
        log('Gemini initialized in TicketScreen');
      } catch (e) {
        log('Failed to initialize Gemini: $e');
      }
    }
  }

  // Shows success message as SnackBar
  void _showSuccessSnackBar(String message) {
    // Clear any existing SnackBars
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.greenColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Shows info message as SnackBar (neutral information)
  void _showInfoSnackBar(String message) {
    // Clear any existing SnackBars
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
