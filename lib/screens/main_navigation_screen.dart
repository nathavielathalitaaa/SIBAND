import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_model.dart';
import 'home_screen.dart';
import 'placeholder_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  final List<ChildModel>? initialChildren;
  final String? initialUserName;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
    this.initialChildren,
    this.initialUserName,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onNavigateToPanduan: () => _onTabSelected(1),
        initialChildren: widget.initialChildren,
        initialUserName: widget.initialUserName,
      ),
      const PlaceholderScreen(
        title: 'Panduan',
        message: 'Segera hadir',
        icon: Icons.menu_book_rounded,
      ),
      const PlaceholderScreen(
        title: 'Rekap',
        message: 'Segera hadir',
        icon: Icons.bar_chart_rounded,
      ),
      const PlaceholderScreen(
        title: 'GPS',
        message: 'Segera hadir',
        icon: Icons.location_on_rounded,
      ),
      ProfileScreen(
        onChildrenChanged: () {
          // Re-trigger rebuild of HomeScreen if needed
          setState(() {});
        },
      ),
    ];

    final navItems = [
      {'label': 'Beranda', 'icon': Icons.home_rounded},
      {'label': 'Panduan', 'icon': Icons.menu_book_rounded},
      {'label': 'Rekap', 'icon': Icons.bar_chart_rounded},
      {'label': 'GPS', 'icon': Icons.location_on_rounded},
      {'label': 'Profil', 'icon': Icons.person_rounded},
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(navItems.length, (index) {
                final item = navItems[index];
                final isSelected = _currentIndex == index;
                final label = item['label'] as String;
                final icon = item['icon'] as IconData;

                return Expanded(
                  child: Semantics(
                    label: 'Tab $label',
                    selected: isSelected,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _onTabSelected(index),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            horizontal: isSelected ? 8 : 4,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE3EEDF) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 22,
                                color: isSelected ? const Color(0xFF1F5C4A) : const Color(0xFF6F7B74),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? const Color(0xFF1F5C4A) : const Color(0xFF6F7B74),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
