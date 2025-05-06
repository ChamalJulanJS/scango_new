import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedBusNumber;

  final DataService _dataService = DataService();
  List<String> _busNumbers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBusNumbers();
  }

  // Load bus numbers from Firebase
  Future<void> _loadBusNumbers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final busNumbers = await _dataService.getAllBusNumbers();
      setState(() {
        _busNumbers = busNumbers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load bus numbers: ${e.toString()}';
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
                        'Select Date',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 12.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.accentColor),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('yyyy-MM-dd').format(_selectedDate),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppTheme.accentColor,
                                    ),
                              ),
                              const Icon(
                                Icons.calendar_today,
                                color: AppTheme.accentColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Select Bus Number',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.accentColor),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedBusNumber,
                            hint: Text(
                              'All Buses',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            items: _busNumbers.map((item) {
                              return DropdownMenuItem<String>(
                                value: item,
                                child: Text(
                                  item,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.accentColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedBusNumber = value;
                              });
                            },
                            icon: const Icon(Icons.arrow_drop_down,
                                color: AppTheme.accentColor),
                            isExpanded: true,
                            dropdownColor: AppTheme.primaryColor,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.accentColor,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Ticket History Section Title
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: AppTheme.greyColor,
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: Text(
                          'Ticket History',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Display Error Message if any
                      if (_errorMessage != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: AppTheme.redColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                      // Loading Indicator
                      if (_isLoading)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                const CircularProgressIndicator(
                                  color: AppTheme.accentColor,
                                  strokeWidth: 3,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Loading bus information...',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.accentColor,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Ticket History Stream Builder
                      if (!_isLoading)
                        StreamBuilder<QuerySnapshot>(
                          stream: _dataService.getTicketsByDateAndBus(
                            date: _selectedDate,
                            busNumber: _selectedBusNumber,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    children: [
                                      const CircularProgressIndicator(
                                        color: AppTheme.accentColor,
                                        strokeWidth: 3,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Loading ticket history...',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppTheme.accentColor,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Text(
                                    'Error loading tickets: ${snapshot.error}',
                                    style: TextStyle(color: AppTheme.redColor),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }

                            final tickets = snapshot.data?.docs ?? [];

                            if (tickets.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Text(
                                    'No tickets found for the selected date and bus.',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: tickets.length,
                              itemBuilder: (context, index) {
                                final ticketData = tickets[index].data()
                                    as Map<String, dynamic>;

                                // Get timestamp or default to now
                                final timestamp =
                                    ticketData['timestamp'] as Timestamp? ??
                                        Timestamp.now();
                                final date = timestamp.toDate();

                                // Get price from totalPrice field
                                final price = ticketData['totalPrice'] ?? 0;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(10.0),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: AppTheme.accentColor),
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Bus: ${ticketData['busNumber'] ?? ''}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.accentColor,
                                                  ),
                                            ),
                                            Text(
                                              DateFormat('MMM dd, yyyy HH:mm')
                                                  .format(date),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: AppTheme.accentColor,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          'From: ${ticketData['pickup'] ?? ''}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: AppTheme.accentColor,
                                              ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          'To: ${ticketData['destination'] ?? ''}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: AppTheme.accentColor,
                                              ),
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Seats: ${ticketData['seatCount'] ?? ''}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: AppTheme.accentColor,
                                                  ),
                                            ),
                                            Text(
                                              'Rs. ${price.toString()}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.accentColor,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.accentColor, // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: AppTheme.accentColor, // Calendar text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentColor, // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
}
