import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'home_screen.dart';
import 'busses_screen.dart';
import 'ticket_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import '../widgets/common_widgets.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';

class MainScreen extends StatefulWidget {
  final int initialTab;
  final String? busNumber;
  final String? pickupLocation;
  final bool verifyForBusStop;
  final String? busId;

  const MainScreen({
    super.key,
    this.initialTab = 0,
    this.busNumber,
    this.pickupLocation,
    this.verifyForBusStop = false,
    this.busId,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  String? _busNumber;
  String? _pickupLocation;

  final Set<int> _pinProtectedTabs = {
    1,
    3
  }; // Profile (4) removed from PIN protection

  bool _initialPinCheckDone = false;
  bool _isTabSwitching = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _busNumber = widget.busNumber;
    _pickupLocation = widget.pickupLocation;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentIndex == 2 && _busNumber == null) {
        _validateTicketAccess();
      } else {
        _checkInitialTabProtection();
      }
    });
  }

  Future<void> _validateTicketAccess() async {
    final activeBus = await DataService().getActiveBus();

    if (!mounted) return;

    if (activeBus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please start a bus route first to issue tickets.'),
          backgroundColor: AppTheme.redColor,
          duration: Duration(seconds: 3),
        ),
      );
      _navigateToTab(1);
    } else {
      final data = activeBus.data() as Map<String, dynamic>;
      setState(() {
        _busNumber = data['busNumber'];
      });
      _checkInitialTabProtection();
    }
  }

  void _checkInitialTabProtection() {
    if (!_initialPinCheckDone && _pinProtectedTabs.contains(_currentIndex)) {
      _initialPinCheckDone = true;

      setState(() {
        _isTabSwitching = true;
      });

      final Map<String, dynamic> targetArgs = {'initialTab': _currentIndex};

      if (_busNumber != null) {
        targetArgs['busNumber'] = _busNumber;
      }
      if (_pickupLocation != null) {
        targetArgs['pickupLocation'] = _pickupLocation;
      }

      final Map<String, dynamic> verifyPinArgs = {
        'targetRoute': AppConstants.mainRoute,
        'arguments': targetArgs,
      };

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isTabSwitching = false;
          });
        }
      });

      Navigator.pushReplacementNamed(
        context,
        AppConstants.verifyPinRoute,
        arguments: verifyPinArgs,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _initialPinCheckDone = true;
      debugPrint('DEBUG: Current tab index after navigation: $_currentIndex');
    }
  }

  void _navigateToTab(int index) {
    setState(() {
      _isTabSwitching = true;
    });

    debugPrint(
        'DEBUG: Attempting to navigate from tab $_currentIndex to tab $index');

    if (_pinProtectedTabs.contains(index) && index != _currentIndex) {
      final targetArgs = <String, dynamic>{'initialTab': index};

      if (_busNumber != null) {
        targetArgs['busNumber'] = _busNumber;
      }
      if (_pickupLocation != null) {
        targetArgs['pickupLocation'] = _pickupLocation;
      }

      final verifyPinArgs = <String, dynamic>{
        'targetRoute': AppConstants.mainRoute,
        'arguments': targetArgs,
      };

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isTabSwitching = false;
          });
        }
      });

      Navigator.pushReplacementNamed(
        context,
        AppConstants.verifyPinRoute,
        arguments: verifyPinArgs,
      );
    } else {
      setState(() {
        _currentIndex = index;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _isTabSwitching = false;
            });
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      const BussesScreen(),
      TicketScreen(
        initialBusNumber: _busNumber,
        initialPickupLocation: _pickupLocation,
      ),
      const HistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          if (_isTabSwitching)
            ModalBarrier(
              color: Colors.black.withValues(alpha: 0.01),
              dismissible: false,
            ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) async {
          if (index == _currentIndex || _isTabSwitching) return;

          if (index == 2) {
            final activeBus = await DataService().getActiveBus();

            // FIX: Check context.mounted to satisfy linter
            if (!context.mounted) return;

            if (activeBus == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Please start a bus route first to issue tickets.'),
                  backgroundColor: AppTheme.redColor,
                ),
              );
              _navigateToTab(1);
              return;
            } else {
              final data = activeBus.data() as Map<String, dynamic>;
              setState(() {
                _busNumber = data['busNumber'];
              });
            }
          }

          // Check again before navigation
          if (context.mounted) {
            _navigateToTab(index);
          }
        },
      ),
    );
  }
}
