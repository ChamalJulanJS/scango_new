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
  final DataService _dataService = DataService();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isCheckingDuplicate = false;

  // List of available cities (routes)
  final List<String> colomboCities = [
    "Colombo 01 - Fort",
    "Colombo 02 - Slave Island",
    "Colombo 03 - Kollupitiya",
    "Colombo 04 - Bambalapitiya",
    "Colombo 05 - Havelock Town",
    "Colombo 06 - Wellawatte",
    "Colombo 07 - Cinnamon Gardens",
    "Colombo 08 - Borella",
    "Colombo 09 - Dematagoda",
    "Colombo 10 - Maradana",
    "Colombo 11 - Pettah",
    "Colombo 12 - Hulftsdorp",
    "Colombo 13 - Kotahena",
    "Colombo 14 - Grandpass",
    "Colombo 15 - Mutwal",
    "Dehiwala",
    "Mount Lavinia",
    "Maharagama",
    "Kottawa",
    "Nugegoda",
    "Rajagiriya",
    "Kotte",
    "Battaramulla",
    "Pelawatte",
    "Thalawathugoda",
    "Boralesgamuwa",
    "Homagama",
    "Pannipitiya",
    "Padukka",
    "Kesbewa",
    "Moratuwa",
    "Ratmalana",
    "Angoda",
    "Avissawella",
  ];

  // Selected routes
  final List<String> _selectedRoutes = [];

  @override
  void initState() {
    super.initState();
    // Add listener to bus number controller for auto uppercase
    _busNumberController.addListener(_onBusNumberChanged);
    // Check if user has any buses
    if (widget.isEditing) {
      _busNumberController.text = widget.busNumber ?? '';
      _seatCountController.text = widget.totalSeats?.toString() ?? '';
      _selectedRoutes.addAll(widget.route ?? []);
    }
  }

  @override
  void dispose() {
    _busNumberController.removeListener(_onBusNumberChanged);
    _busNumberController.dispose();
    _seatCountController.dispose();
    super.dispose();
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
      // Silently fail on duplicate check, will validate again on submit
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
    // Check if bus number has only allowed characters: A-Z, 0-9, -
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
      _showError('Please select exactly 2 cities for the route');
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
        // Update existing bus (bus number is read-only when editing)
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
        // Check for duplicate bus number before adding
        final isDuplicate = await _dataService.isBusNumberExists(busNumber);
        if (isDuplicate) {
          _showError('Bus number already exists');
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Add bus to Firestore
        await _dataService.addBus(
          busNumber: busNumber,
          route: _selectedRoutes,
          totalSeats: seatCount,
        );

        // Clear fields
        _busNumberController.clear();
        _seatCountController.clear();
        setState(() {
          _selectedRoutes.clear();
        });

        // Show success message
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

  // Function to show the multi-select dropdown
  Future<void> _showMultiSelectDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        // Create a local list to hold the selected items during dialog session
        List<String> tempSelectedRoutes = List.from(_selectedRoutes);

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              title: Text(
                'Select Exactly 2 Routes',
                style: TextStyle(
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: colomboCities.map((city) {
                      return CheckboxListTile(
                        title: Text(
                          city,
                          style: TextStyle(
                            fontWeight: tempSelectedRoutes.contains(city)
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        value: tempSelectedRoutes.contains(city),
                        activeColor: AppTheme.accentColor,
                        checkColor: Colors.white,
                        onChanged: (isChecked) {
                          setState(() {
                            if (isChecked!) {
                              if (tempSelectedRoutes.length >= 2) {
                                // Prevent selecting more than two
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('You can select only 2 routes'),
                                    backgroundColor: AppTheme.redColor,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              } else {
                                tempSelectedRoutes.add(city);
                              }
                            } else {
                              tempSelectedRoutes.remove(city);
                            }
                          });
                        },
                        secondary: tempSelectedRoutes.contains(city)
                            ? Icon(Icons.location_on,
                                color: AppTheme.accentColor)
                            : Icon(Icons.location_on_outlined,
                                color: Colors.grey),
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                  ),
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                  onPressed: () {
                    if (tempSelectedRoutes.length != 2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please select exactly 2 routes'),
                          backgroundColor: AppTheme.redColor,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    // Update the actual selected routes
                    this.setState(() {
                      _selectedRoutes.clear();
                      _selectedRoutes.addAll(tempSelectedRoutes);
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            );
          },
        );
      },
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
                      Text(
                        'Route',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showMultiSelectDialog,
                          borderRadius: BorderRadius.circular(10),
                          child: Ink(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.accentColor),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 15),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _selectedRoutes.isEmpty
                                        ? Text(
                                            'Select cities for route',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          )
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${_selectedRoutes.length} cities selected',
                                                style: TextStyle(
                                                  color: AppTheme.accentColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _selectedRoutes.join(', '),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ],
                                          ),
                                  ),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: AppTheme.accentColor,
                                    size: 28,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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
