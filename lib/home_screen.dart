import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/planning_provider.dart';
import 'dashboard_screen.dart';
import 'calendar_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import '../widgets/scan_fab.dart';

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlanningProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const DashboardScreen(),
      const CalendarScreen(),
      const HistoryScreen(),
      SettingsScreen(
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      floatingActionButton: ScanFab(
        onScanPressed: () => _onScanPressed(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Accueil',
            index: 0,
            currentIndex: _currentIndex,
            onTap: () => setState(() => _currentIndex = 0),
          ),
          _NavItem(
            icon: Icons.calendar_month_rounded,
            label: 'Calendrier',
            index: 1,
            currentIndex: _currentIndex,
            onTap: () => setState(() => _currentIndex = 1),
          ),
          const SizedBox(width: 60), // Space for FAB
          _NavItem(
            icon: Icons.history_rounded,
            label: 'Historique',
            index: 2,
            currentIndex: _currentIndex,
            onTap: () => setState(() => _currentIndex = 2),
          ),
          _NavItem(
            icon: Icons.settings_rounded,
            label: 'Réglages',
            index: 3,
            currentIndex: _currentIndex,
            onTap: () => setState(() => _currentIndex = 3),
          ),
        ],
      ),
    );
  }

  Future<void> _onScanPressed(BuildContext context) async {
    Navigator.pushNamed(context, '/scan');
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.5);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}