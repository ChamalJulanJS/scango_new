import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';
import 'home_screen.dart';
import 'add_bus_screen.dart';
import 'ticket_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialTab;

  const MainScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late PageController _pageController;

  // Keep track of tabs that have been instantiated
  final List<bool> _instantiatedTabs = [true, false, false, false, false];

  final List<Widget> _pages = [
    const HomeScreen(),
    const AddBusScreen(),
    const TicketScreen(),
    const HistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    // Mark the initial tab as instantiated
    for (int i = 0; i < _instantiatedTabs.length; i++) {
      _instantiatedTabs[i] = i == _currentIndex;
    }
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we have arguments with initialTab
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null &&
        args is Map<String, dynamic> &&
        args.containsKey('initialTab')) {
      final newTab = args['initialTab'] as int;
      if (newTab != _currentIndex) {
        setState(() {
          _currentIndex = newTab;
          _pageController.jumpToPage(newTab);
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swiping
        children: _pages,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
            _instantiatedTabs[index] = true; // Mark this tab as instantiated
          });
        },
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          // Don't animate if tapping the current tab
          if (index == _currentIndex) return;

          setState(() {
            _currentIndex = index;
            // Use jumpToPage instead of animate for immediate switching
            // This prevents transitioning through all screens
            _pageController.jumpToPage(index);
          });
        },
      ),
    );
  }
}
