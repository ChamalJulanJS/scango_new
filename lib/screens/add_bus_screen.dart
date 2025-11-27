import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scan_go/utils/constants.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';

class AddBusScreen extends StatefulWidget {
  final String? busId;
  final String? busNumber;
  final List<String>? route;
  final int? totalSeats;
  final bool isEditing;
  const AddBusScreen(
      {super.key,
      this.busId,
      this.busNumber,
      this.route,
      this.totalSeats,
      this.isEditing = false});

  @override
  State<AddBusScreen> createState() => _AddBusScreenState();
}

class _AddBusScreenState extends State<AddBusScreen> {
  final TextEditingController _busNumberController = TextEditingController();
  final TextEditingController _seatCountController = TextEditingController();

  // NEW: Controller for the clickable route field
  final TextEditingController _routeDisplayController = TextEditingController();

  final DataService _dataService = DataService();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isCheckingDuplicate = false;

  // NEW: Stores the list of routes downloaded from Firebase
  List<Map<String, dynamic>> _allRoutes = [];
  bool _isLoadingRoutes = true;

  // Selected routes (Stores the Start and End city for the database)
  final List<String> _selectedRoutes = [];

  @override
  void initState() {
    super.initState();

    // 1. Load the routes from Firebase when the screen starts
    _loadRoutes();

    _busNumberController.addListener(_onBusNumberChanged);

    // Check if user is editing an existing bus
    if (widget.isEditing) {
      _busNumberController.text = widget.busNumber ?? '';
      _seatCountController.text = widget.totalSeats?.toString() ?? '';
      _selectedRoutes.addAll(widget.route ?? []);

      // If editing, show the existing route in the text box
      if (_selectedRoutes.length >= 2) {
        _routeDisplayController.text =
            "${_selectedRoutes[0]} - ${_selectedRoutes[1]}";
      }
    }
  }

  @override
  void dispose() {
    _busNumberController.removeListener(_onBusNumberChanged);
    _busNumberController.dispose();
    _seatCountController.dispose();
    _routeDisplayController.dispose(); // Don't forget to dispose this
    super.dispose();
  }

  // --- NEW: Fetch Routes Logic ---
  Future<void> _loadRoutes() async {
    // This calls the function you added to DataService in Step 2
    final routes = await _dataService.getBusRoutes();
    routes.sort((a, b) {
      String numA = a['number'].toString();
      String numB = b['number'].toString();
      return numA.compareTo(numB); // Ascending order (01, 02, 100...)
    });

    if (mounted) {
      setState(() {
        _allRoutes = routes;
        _isLoadingRoutes = false;
      });
    }
  }

  // --- NEW: Search Popup Logic ---
  void _openRouteSearch() {
    if (_isLoadingRoutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Loading routes, please wait...")),
      );
      return;
    }

    if (_allRoutes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No routes found in database.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        String query = "";
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Filter the list based on what user types
            final filtered = _allRoutes.where((r) {
              return r['searchKey'].contains(query.toLowerCase());
            }).toList();

            return AlertDialog(
              title: const Text("Select Bus Route",
                  style: TextStyle(color: AppTheme.accentColor)),
              content: SizedBox(
                height: 400, // Fixed height for the popup list
                width: double.maxFinite,
                child: Column(
                  children: [
                    // Search Box inside the dialog
                    TextField(
                      decoration: InputDecoration(
                        hintText: "Search (e.g. 138, Pettah)",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 0, horizontal: 10),
                      ),
                      onChanged: (val) {
                        setDialogState(() => query = val);
                      },
                    ),
                    const SizedBox(height: 10),

                    // List of Results
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final route = filtered[index];
                          return ListTile(
                            title: Text(
                              route['display'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            onTap: () {
                              // When a user clicks a row, save it and close dialog
                              setState(() {
                                _selectedRoutes.clear();
                                _selectedRoutes.add(route['start']);
                                _selectedRoutes.add(route['end']);
                                _routeDisplayController.text = route['display'];
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel",
                      style: TextStyle(color: Colors.grey)),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _onBusNumberChanged() {
    final text = _busNumberController.text;

    if (text != text.toUpperCase()) {
      final String newText = text.toUpperCase();
      _busNumberController.value = _busNumberController.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }

    if (text.isNotEmpty && !widget.isEditing) {
      _checkDuplicateBusNumber(text);
    } else {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  Future<void> _checkDuplicateBusNumber(String busNumber) async {
    if (_isCheckingDuplicate || busNumber.isEmpty) return;

    setState(() {
      _isCheckingDuplicate = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final isDuplicate = await _dataService.isBusNumberExists(busNumber);

      if (isDuplicate && mounted) {
        setState(() {
          _errorMessage = 'Bus number already exists';
        });
      }
    } catch (e) {
      // Silently fail
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingDuplicate = false;
        });
      }
    }
  }

  // Validate bus number format
  bool _isValidBusNumber(String busNumber) {
    final RegExp validFormat = RegExp(r'^[A-Z0-9\-]+$');
    return validFormat.hasMatch(busNumber);
  }

  // Add bus to Firebase
  Future<void> _addBus() async {
    final busNumber = _busNumberController.text.trim();

    // Validate inputs
    if (busNumber.isEmpty) {
      _showError('Please enter a bus number');
      return;
    }

    if (!_isValidBusNumber(busNumber)) {
      _showError('Bus number can only contain letters, numbers, and hyphens');
      return;
    }

    if (_selectedRoutes.length != 2) {
      _showError('Please select a valid bus route');
      return;
    }

    if (_seatCountController.text.isEmpty) {
      _showError('Please enter the seat count');
      return;
    }

    int? seatCount = int.tryParse(_seatCountController.text);
    if (seatCount == null || seatCount <= 0) {
      _showError('Please enter a valid seat count');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.isEditing && widget.busId != null) {
        await _dataService.busesCollection.doc(widget.busId!).update({
          'route': _selectedRoutes,
          'totalSeats': seatCount,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bus updated successfully'),
              backgroundColor: AppTheme.greenColor,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        final isDuplicate = await _dataService.isBusNumberExists(busNumber);
        if (isDuplicate) {
          _showError('Bus number already exists');
          setState(() {
            _isLoading = false;
          });
          return;
        }

        await _dataService.addBus(
          busNumber: busNumber,
          route: _selectedRoutes,
          totalSeats: seatCount,
        );

        // Clear fields
        _busNumberController.clear();
        _seatCountController.clear();
        _routeDisplayController.clear(); // Clear the new controller too
        setState(() {
          _selectedRoutes.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bus added successfully'),
              backgroundColor: AppTheme.greenColor,
            ),
          );
        }
      }
    } catch (e) {
      _showError('Failed to save bus: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.accentColor),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context, AppConstants.bussesRoute, (route) => false),
        ),
        title: const Text('Add Bus',
            style: TextStyle(color: AppTheme.accentColor)),
      ),
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
                      const SizedBox(height: 10),
                      Text(
                        'Bus Number',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        readOnly: widget.isEditing,
                        controller: _busNumberController,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9\-]')),
                        ],
                        decoration: InputDecoration(
                          hintText: 'Enter bus number (e.g. AB-1234)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide:
                                const BorderSide(color: AppTheme.accentColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: const BorderSide(
                                color: AppTheme.accentColor, width: 2.0),
                          ),
                          errorText: _errorMessage != null &&
                                  _errorMessage!.contains('Bus number')
                              ? _errorMessage
                              : null,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // --- UPDATED ROUTE SECTION ---
                      Text(
                        'Bus Route',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _routeDisplayController,
                        readOnly: true, // User cannot type here manually
                        onTap: _openRouteSearch, // Open search on tap
                        decoration: InputDecoration(
                          hintText: 'Tap to search route',
                          suffixIcon: const Icon(Icons.arrow_drop_down,
                              color: AppTheme.accentColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide:
                                const BorderSide(color: AppTheme.accentColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: const BorderSide(
                                color: AppTheme.accentColor, width: 2.0),
                          ),
                        ),
                      ),
                      if (_selectedRoutes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 5.0, left: 5.0),
                          child: Text(
                            "Tap above to select a route from the list",
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                      // ---------------------------

                      const SizedBox(height: 20),
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
                          hintText: 'Enter seat count',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide:
                                const BorderSide(color: AppTheme.accentColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: const BorderSide(
                                color: AppTheme.accentColor, width: 2.0),
                          ),
                        ),
                      ),
                      if (_errorMessage != null &&
                          !_errorMessage!.contains('Bus number')) ...[
                        const SizedBox(height: 15),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                      Center(
                        child: SizedBox(
                          width: 200,
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : CustomButton(
                                  text: widget.isEditing ? 'Update' : 'Add',
                                  onPressed: _addBus,
                                  backgroundColor: AppTheme.redColor,
                                ),
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
}
