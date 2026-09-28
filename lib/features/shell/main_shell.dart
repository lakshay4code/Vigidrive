import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../auth/services/auth_service.dart';
import '../home/presentation/home_screen.dart';
import '../notifications/presentation/notifications_screen.dart';
import '../recordings/presentation/recordings_screen.dart';
import '../settings/presentation/settings_screen.dart';
import '../systems/presentation/active_systems_screen.dart';
import '../systems/services/systems_repository.dart';
import '../violations/services/violations_repository.dart';

/// Top-level shell that hosts the 4-tab floating footer navigation.
///
/// Tab order: Home (0) · Notifications (1) · My Systems (2) · Settings (3)
class MainShell extends StatefulWidget {
  final AuthService authService;
  final SystemsRepository systemsRepository;
  final ViolationsRepository violationsRepository;

  /// Optionally start on a specific tab index (default: 0 = Home).
  final int initialIndex;

  const MainShell({
    super.key,
    required this.authService,
    required this.systemsRepository,
    required this.violationsRepository,
    this.initialIndex = 0,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  void _openRecordings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RecordingsScreen(
          systemsRepository: widget.systemsRepository,
          violationsRepository: widget.violationsRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      HomeScreen(
        authService: widget.authService,
        systemsRepository: widget.systemsRepository,
        violationsRepository: widget.violationsRepository,
        onOpenRecordings: _openRecordings,
      ),
      NotificationsScreen(
        systemsRepository: widget.systemsRepository,
        violationsRepository: widget.violationsRepository,
      ),
      ActiveSystemsScreen(
        repository: widget.systemsRepository,
        violationsRepository: widget.violationsRepository,
        authService: widget.authService,
      ),
      SettingsScreen(
        authService: widget.authService,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Tab content fills the whole screen.
          IndexedStack(
            index: _selectedIndex,
            children: tabs,
          ),

          // Floating footer navigation bar.
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: _FloatingNavBar(
              selectedIndex: _selectedIndex,
              onTap: _onTabSelected,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Floating navigation bar
// ---------------------------------------------------------------------------

class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _NavItem(
            key: const Key('nav_tab_home'),
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: AppStrings.navHome,
            selected: selectedIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            key: const Key('nav_tab_notifications'),
            icon: Icons.notifications_outlined,
            selectedIcon: Icons.notifications,
            label: AppStrings.navNotifications,
            selected: selectedIndex == 1,
            onTap: () => onTap(1),
          ),
          _NavItem(
            key: const Key('nav_tab_systems'),
            icon: Icons.remove_red_eye_outlined,
            selectedIcon: Icons.remove_red_eye,
            label: AppStrings.navSystems,
            selected: selectedIndex == 2,
            onTap: () => onTap(2),
          ),
          _NavItem(
            key: const Key('nav_tab_settings'),
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
            label: AppStrings.navSettings,
            selected: selectedIndex == 3,
            onTap: () => onTap(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox.expand(
          child: Center(
            child: Icon(
              selected ? selectedIcon : icon,
              color: color,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
