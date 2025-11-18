import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/constants.dart' as app_constants;
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../widgets/common_widgets.dart';

class BussesScreen extends StatefulWidget {
  const BussesScreen({super.key});

  @override
  State<BussesScreen> createState() => _BussesScreenState();
}

class _BussesScreenState extends State<BussesScreen> {
  final DataService _dataService = DataService();
  bool _isLoading = true;
  List<DocumentSnapshot> _buses = [];
  final Map<String, bool> _busStartStatus = {};
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  Future<void> _loadBuses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final String? userId = _authService.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final busesSnapshot = await _dataService.busesCollection
          .where('userId', isEqualTo: userId)
          .get();

      setState(() {
        _buses = busesSnapshot.docs;

        // Initialize the start status for each bus
        for (var bus in _buses) {
          final data = bus.data() as Map<String, dynamic>;
          final busNumber = data['busNumber'] as String;
          final isStarted = data['isStarted'] ?? false;
          _busStartStatus[busNumber] = isStarted;
        }

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load buses: ${e.toString()}'),
            backgroundColor: AppTheme.redColor,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteBus(String busId, String busNumber) async {
    // Show confirmation dialog
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete Bus'),
            content: Text('Are you sure you want to delete bus $busNumber?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child:
                    Text('Delete', style: TextStyle(color: AppTheme.redColor)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _dataService.busesCollection.doc(busId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bus deleted successfully'),
            backgroundColor: AppTheme.greenColor,
          ),
        );
      }

      // Reload buses
      _loadBuses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete bus: ${e.toString()}'),
            backgroundColor: AppTheme.redColor,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBusStatus(
      String busId, String busNumber, bool currentStatus) async {
    final newStatus = !currentStatus;
    final statusText = newStatus ? 'start' : 'stop';

    setState(() {
      _isLoading = true;
    });

    try {
      // Update bus status in Firestore
      await _dataService.updateBusStatus(busId, newStatus);

      // If starting the bus, reset availableSeats to totalSeats
      if (newStatus) {
        final busDoc = await _dataService.getBusById(busId);
        if (busDoc != null && busDoc.exists) {
          final data = busDoc.data() as Map<String, dynamic>;
          final int totalSeats = data['totalSeats'] ?? 0;
          await _dataService.busesCollection.doc(busId).update({
            'availableSeats': totalSeats,
          });
        }
      }

      setState(() {
        _busStartStatus[busNumber] = newStatus;
        _isLoading = false;
      });
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bus $busNumber ${statusText}ed successfully'),
            backgroundColor:
                newStatus ? AppTheme.greenColor : AppTheme.redColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // If starting the bus, navigate to ticket screen
      if (newStatus && mounted) {
        Navigator.pushReplacementNamed(
          context,
          app_constants.AppConstants.ticketRoute,
          arguments: {
            'busNumber': busNumber,
          },
        );
      } else {
        // If stopping the bus, just reload the buses list
        _loadBuses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to $statusText bus: ${e.toString()}'),
            backgroundColor: AppTheme.redColor,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const Center(child: AppLogo()),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'My Buses',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentColor,
                                  ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  app_constants.AppConstants.addBusRoute,
                                ).then((_) => _loadBuses());
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Bus',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _buses.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.directions_bus_outlined,
                                          size: 80,
                                          color: AppTheme.accentColor
                                              .withValues(alpha: 0.5),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No buses found',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                color: AppTheme.accentColor,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Add a bus to get started',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                        const SizedBox(height: 24),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.pushNamed(
                                              context,
                                              app_constants
                                                  .AppConstants.addBusRoute,
                                            ).then((_) => _loadBuses());
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.accentColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 15),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          icon: const Icon(Icons.add),
                                          label: const Text('Add Bus',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16)),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24.0),
                                    itemCount: _buses.length,
                                    itemBuilder: (context, index) {
                                      final bus = _buses[index];
                                      final data =
                                          bus.data() as Map<String, dynamic>;
                                      final busNumber =
                                          data['busNumber'] as String;
                                      final route = List<String>.from(
                                          data['route'] ?? []);
                                      final totalSeats =
                                          data['totalSeats'] ?? 0;
                                      final isStarted =
                                          _busStartStatus[busNumber] ?? false;

                                      return Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 16.0),
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    busNumber,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleLarge
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: AppTheme
                                                              .accentColor,
                                                        ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: isStarted
                                                          ? AppTheme.greenColor
                                                              .withValues(
                                                                  alpha: 0.2)
                                                          : AppTheme.greyColor
                                                              .withValues(
                                                                  alpha: 0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: Text(
                                                      isStarted
                                                          ? 'Running'
                                                          : 'Stopped',
                                                      style: TextStyle(
                                                        color: isStarted
                                                            ? AppTheme
                                                                .greenColor
                                                            : AppTheme
                                                                .greyColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Route: ${route.join(' → ')}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Total Seats: $totalSeats',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium,
                                              ),
                                              const SizedBox(height: 16),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  // Edit button
                                                  IconButton(
                                                    onPressed: () {
                                                      Navigator.pushNamed(
                                                        context,
                                                        app_constants
                                                            .AppConstants
                                                            .addBusRoute,
                                                        arguments: {
                                                          'busId': bus.id,
                                                          'busNumber':
                                                              busNumber,
                                                          'route': route,
                                                          'totalSeats':
                                                              totalSeats,
                                                          'isEditing': true,
                                                        },
                                                      ).then(
                                                          (_) => _loadBuses());
                                                    },
                                                    icon: Icon(
                                                      Icons.edit,
                                                      color:
                                                          AppTheme.accentColor,
                                                    ),
                                                    tooltip: 'Edit',
                                                  ),
                                                  // Delete button
                                                  IconButton(
                                                    onPressed: () => _deleteBus(
                                                        bus.id, busNumber),
                                                    icon: Icon(
                                                      Icons.delete,
                                                      color: AppTheme.redColor,
                                                    ),
                                                    tooltip: 'Delete',
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // Start/Stop button
                                                  ElevatedButton.icon(
                                                    onPressed: () =>
                                                        _toggleBusStatus(
                                                      bus.id,
                                                      busNumber,
                                                      isStarted,
                                                    ),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor: isStarted
                                                          ? AppTheme.redColor
                                                          : AppTheme.greenColor,
                                                      foregroundColor:
                                                          Colors.white,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 16,
                                                          vertical: 12),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      elevation: 3,
                                                    ),
                                                    icon: Icon(isStarted
                                                        ? Icons.stop_circle
                                                        : Icons.play_circle),
                                                    label: Text(
                                                      isStarted
                                                          ? 'Stop'
                                                          : 'Start',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                  if (_isLoading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: const Center(
                        child: CircularProgressIndicator(),
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
}
