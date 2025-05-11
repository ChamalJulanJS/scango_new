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
  final String? initialBusNumber;
  final String? initialPickupLocation;

  const TicketScreen({
    super.key,
    this.initialBusNumber,
    this.initialPickupLocation,
  });

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final bool _autoProcess = false;
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

    // Initialize values from widget parameters
    _selectedBusNumber = widget.initialBusNumber;
    _selectedPickupLocation = widget.initialPickupLocation;

    // Debug print to verify values
    debugPrint(
        'DEBUG: TicketScreen initialized with busNumber: $_selectedBusNumber, pickupLocation: $_selectedPickupLocation');

    // Fetch bus numbers from Firebase
    _fetchBusNumbers();

    // Initialize speech and Gemini
    _initSpeech();
    _initGemini();

    // If initial bus number is provided but pickup locations aren't loaded yet, fetch them
    if (_selectedBusNumber != null && _pickupLocations.isEmpty) {
      _fetchPickupLocations(_selectedBusNumber!);
    }

    // If we came from the Busses screen with a started bus, show a message
    if (_selectedBusNumber != null) {
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Bus $_selectedBusNumber started. Ready to issue tickets.'),
              backgroundColor: AppTheme.greenColor,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // If we have initialPickupLocation but pickup locations are already loaded,
    // check if we can select the initialPickupLocation
    if (widget.initialPickupLocation != null &&
        _pickupLocations.isNotEmpty &&
        _pickupLocations.contains(widget.initialPickupLocation) &&
        _selectedPickupLocation != widget.initialPickupLocation) {
      setState(() {
        _selectedPickupLocation = widget.initialPickupLocation;
      });

      debugPrint(
          'DEBUG: didChangeDependencies updated pickup location to: $_selectedPickupLocation');
    }
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
        localeId: 'si-LK');

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
        final response = await _gemini.chat([
          Content(parts: [Part.text(prompt)], role: 'user')
        ]);

        if (response != null && response.output != null) {
          log('Gemini text response: ${response.output}');

          final jsonResponse = _extractJsonFromResponse(response.output!);
          if (jsonResponse != null) {
            _updateFieldsFromGeminiResponse(jsonResponse);
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
          final jsonResponse = _extractJsonFromResponse(response.output!);
          if (jsonResponse != null) {
            _updateFieldsFromGeminiResponse(jsonResponse);
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
        if (!cleanedResponse.startsWith('{')) {
          cleanedResponse = '{$cleanedResponse';
        }
        if (!cleanedResponse.endsWith('}')) {
          cleanedResponse = '$cleanedResponse}';
        }

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

      // Check if both destination and seat count are filled via voice input
      // If so, automatically proceed to checkout
      if (_destinationController.text.isNotEmpty &&
          _seatCountController.text.isNotEmpty &&
          jsonResponse.containsKey('city') &&
          jsonResponse.containsKey('seats') &&
          _canProceedToCheckout()) {
        // Allow UI to update first
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _submitTicket();
          }
        });
      }
    }
  }

  // Fetch bus numbers from Firebase Buses collection (only for current user)
  Future<void> _fetchBusNumbers() async {
    setState(() {
      _isLoading = true;
    });

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

      // Query buses where userId matches current user
      final busesSnapshot = await _firestore
          .collection('Buses')
          .where('userId', isEqualTo: userId)
          .get();

      final buses = busesSnapshot.docs.map((doc) {
        return doc.data()['busNumber'] as String;
      }).toList();

      setState(() {
        _busNumbers = buses;
        _isLoading = false;
        // No snackbar message here - even if no buses are found
      });
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to load bus numbers: ${e.toString()}');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fetch pickup locations (routes) for the selected bus
  Future<void> _fetchPickupLocations(String busNumber) async {
    setState(() {
      _isLoading = true;
      // Don't reset the pickup locations and selected pickup location here
      // to preserve the initial values when returning from checkout
      _pickupLocations = [];
      // Only reset selected pickup location if it doesn't match the initialPickupLocation
      if (widget.initialPickupLocation != _selectedPickupLocation) {
        _selectedPickupLocation = null;
      }
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

          // If we have an initialPickupLocation from the widget, try to select it
          if (widget.initialPickupLocation != null &&
              _pickupLocations.contains(widget.initialPickupLocation)) {
            _selectedPickupLocation = widget.initialPickupLocation;
          }

          // Debug print to verify pickup locations and selected value
          debugPrint('DEBUG: Pickup locations loaded: $_pickupLocations');
          debugPrint(
              'DEBUG: Selected pickup location: $_selectedPickupLocation');
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

  double _calculateTotalPrice() {
    final seatCount = int.tryParse(_seatCountController.text) ?? 0;
    return seatCount * 100.0;
  }

  Future<void> _submitTicket() async {
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

    setState(() {
      _isLoading = true;
    });
    _showInfoSnackBar('Processing your ticket...');

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        _showErrorSnackBar('User not authenticated');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Check if destination is in the bus routes
      final isValidDestination = await _validateDestination();
      if (!isValidDestination) {
        _showErrorSnackBar('Destination not on this bus route');
        setState(() {
          _isLoading = false;
        });
        return;
      }
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

      // Process for checkout (simulating payment processing without user interaction)
      await Future.delayed(const Duration(seconds: 1));

      // Go to checkout screen first - this will show the ticket details
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Navigate to checkout screen
          Navigator.pushNamed(
            context,
            AppConstants.checkoutRoute,
            arguments: {
              'busNumber': _selectedBusNumber,
              'pickupLocation': _selectedPickupLocation,
              'destination': _destinationController.text.trim(),
              'seatCount': _seatCountController.text,
              'totalPrice': totalPrice,
              'autoProcess': true,
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
                          if (_autoProcess) _voiceRecognitionButton(),
                          const SizedBox(height: 20),

                          // Bus Number Dropdown
                          Text(
                            'Bus Number',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          _buildBusNumberDropdown(),
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
                            CustomButton(
                              width: MediaQuery.sizeOf(context).width,
                              text:
                                  'Pay Total ${_calculateTotalPrice().toStringAsFixed(0)}',
                              onPressed: () =>
                                  !_autoProcess ? _submitTicket() : null,
                            ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // Loading overlay
                  if (_isLoading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
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

  Center _voiceRecognitionButton() {
    return Center(
      child: Column(
        children: [
          InkWell(
            onTap: _isProcessing
                ? null
                : (_isListening ? _stopListening : _startListening),
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
                    color: Colors.black.withValues(alpha: 0.1),
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.w500,
                ),
          ),
          if (_lastWords.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12.0, bottom: 12.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreyColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.accentColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Transcribed Sinhala:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.accentColor.withValues(alpha: 0.7),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastWords,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
    );
  }

  Widget _buildBusNumberDropdown() {
    bool isFromBussesScreen = widget.initialBusNumber != null;

    if (_selectedBusNumber != null &&
        !_busNumbers.contains(_selectedBusNumber)) {
      if (isFromBussesScreen && _selectedBusNumber != null) {
        _busNumbers.add(_selectedBusNumber!);
      }
    }

    return DropdownButtonFormField<String>(
      value: _selectedBusNumber,
      decoration: InputDecoration(
        labelText: 'Bus Number',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        prefixIcon: const Icon(Icons.directions_bus),
        filled: isFromBussesScreen,
        fillColor: isFromBussesScreen ? Colors.grey.shade200 : null,
      ),
      items: _busNumbers.map((String busNumber) {
        return DropdownMenuItem<String>(
          value: busNumber,
          child: Text(busNumber),
        );
      }).toList(),
      onChanged: isFromBussesScreen
          ? null
          : (String? newValue) {
              setState(() {
                _selectedBusNumber = newValue;
                _selectedPickupLocation = null;
                _pickupLocations = [];
              });
              if (newValue != null) {
                _fetchPickupLocations(newValue);
              }
            },
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required void Function(String?)? onChanged,
  }) {
    return GestureDetector(
      onTap: () {
        AppConfig.fromDropDown = true;
      },
      child: Container(
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
            icon:
                const Icon(Icons.arrow_drop_down, color: AppTheme.accentColor),
            isExpanded: true,
            dropdownColor: AppTheme.primaryColor,
            menuMaxHeight: MediaQuery.of(context).size.height * 0.4,
            focusColor: Colors.transparent,
            elevation: 8,
            underline: Container(height: 0),
          ),
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

  void _initGemini() {
    try {
      if (AppConfig.geminiApiKey == 'AIzaSyDslSUKSPsgiikshlUOYHNGjpjx-gBF1_k') {
        log('WARNING: Using default Gemini API key. Replace with your actual key in config.dart');
      }

      Gemini.instance;
      log('Gemini initialized successfully in TicketScreen');
    } catch (e) {
      log('Error initializing Gemini: $e');

      try {
        Gemini.init(apiKey: AppConfig.geminiApiKey);
        log('Gemini initialized in TicketScreen');
      } catch (e) {
        log('Failed to initialize Gemini: $e');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.greenColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<bool> _validateDestination() async {
    try {
      // Get the routes for the selected bus
      final busDoc = await _firestore
          .collection('Buses')
          .where('busNumber', isEqualTo: _selectedBusNumber)
          .get();

      if (busDoc.docs.isEmpty) return false;

      final routes = List<String>.from(busDoc.docs.first.data()['route'] ?? []);
      final destination = _destinationController.text.trim();

      // First check if the destination exactly matches any route
      if (routes.contains(destination)) return true;

      // If not an exact match, use Gemini to check if the destination is included
      final prompt =
          """I have a bus with the following routes: ${routes.join(', ')}. 
      Is '$destination' included in or near these routes? Answer only with 'yes' or 'no'.""";

      final response = await _gemini.chat([
        Content(parts: [Part.text(prompt)], role: 'user')
      ]);

      if (response != null && response.output != null) {
        final answer = response.output!.toLowerCase();
        return answer.contains('yes');
      }

      return false;
    } catch (e) {
      debugPrint('Error validating destination: $e');
      return true; // Allow the ticket if validation fails
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
}
