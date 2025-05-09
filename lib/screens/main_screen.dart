import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'home_screen.dart';
import 'busses_screen.dart';
import 'ticket_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import '../widgets/common_widgets.dart';

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

  final Set<int> _pinProtectedTabs = {1, 3, 4};

  bool _initialPinCheckDone = false;

  bool _isTabSwitching = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _busNumber = widget.busNumber;
    _pickupLocation = widget.pickupLocation;


    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialTabProtection();
    });
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

      debugPrint(
          'DEBUG: Initial tab requires PIN. Showing verification for tab: $_currentIndex');

      Future.delayed(Duration(milliseconds: 300), () {
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

 //     _handleNavigationArguments(args);

      // Debug: Print which tab we're currently on after navigation
      debugPrint('DEBUG: Current tab index after navigation: $_currentIndex');
    }
  }

  void _navigateToTab(int index) {
    setState(() {
      _isTabSwitching = true;
    });
    

    debugPrint(
        'DEBUG: Attempting to navigate from tab $_currentIndex to tab $index');

    // Check if tab requires PIN verification
    if (_pinProtectedTabs.contains(index) && index != _currentIndex) {
      // Create arguments for the target tab
      final targetArgs = <String, dynamic>{
        'initialTab': index,
      };

      // Include bus/pickup info if available
      if (_busNumber != null) {
        targetArgs['busNumber'] = _busNumber;
      }
      if (_pickupLocation != null) {
        targetArgs['pickupLocation'] = _pickupLocation;
      }

      // Create arguments for VerifyPinScreen
      final verifyPinArgs = <String, dynamic>{
        'targetRoute': AppConstants.mainRoute,
        'arguments': targetArgs,
      };

      debugPrint('DEBUG: Tab requires PIN. Showing verification for tab: $index');

      // Reset tab switching flag after a short delay, even if we're navigating away
      Future.delayed(Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isTabSwitching = false;
          });
        }
      });

      // Use pushNamed instead of pushing a new route to maintain proper navigation stack
      Navigator.pushReplacementNamed(
        context,
        AppConstants.verifyPinRoute,
        arguments: verifyPinArgs,
      );
    } else {
      // Navigate directly to the tab
      debugPrint('DEBUG: No PIN required. Directly navigating to tab: $index');
      setState(() {
        _currentIndex = index;

        // Reset tab switching flag after a short delay
        Future.delayed(Duration(milliseconds: 300), () {
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
    debugPrint('DEBUG: Building MainScreen with currentIndex: $_currentIndex');

    // Rebuild the pages each time build is called to ensure latest parameters are used
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
          // Add modal barrier during tab switching to prevent dropdown interactions
          if (_isTabSwitching)
            ModalBarrier(
              color: Colors.black.withValues(alpha: 0.01),
              dismissible: false,
            ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == _currentIndex || _isTabSwitching) return;
          _navigateToTab(index);
        },
      ),
    );
  }
}
