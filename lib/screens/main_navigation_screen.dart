import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_model.dart';
import '../widgets/thin_line_logo.dart';
import 'guide_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'recap_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  final List<ChildModel>? initialChildren;
  final String? initialUserName;
  final String? initialErrorMessage;
  final Future<List<ChildModel>> Function()? onFetchChildren;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
    this.initialChildren,
    this.initialUserName,
    this.initialErrorMessage,
    this.onFetchChildren,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  int _slideDirection = 1;
  late final AnimationController _tabController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _tabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1.0,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _tabController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _slideDirection = index > _currentIndex ? 1 : -1;
      _currentIndex = index;
    });
    _tabController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onNavigateToPanduan: () => _onTabSelected(1),
        initialChildren: widget.initialChildren,
        initialUserName: widget.initialUserName,
        initialErrorMessage: widget.initialErrorMessage,
        onFetchChildren: widget.onFetchChildren,
        isActiveTab: _currentIndex == 0,
      ),
      const GuideScreen(),
      RecapScreen(
        initialChildren: widget.initialChildren,
      ),
      ProfileScreen(
        onChildrenChanged: () {
          // Re-trigger rebuild of HomeScreen if needed
          setState(() {});
        },
      ),
    ];

    final navItems = [
      {'label': 'Beranda', 'type': ThinLineNavType.home},
      {'label': 'Panduan', 'type': ThinLineNavType.guide},
      {'label': 'Rekap', 'type': ThinLineNavType.recap},
      {'label': 'Profil', 'type': ThinLineNavType.profile},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F4EF),
      body: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            final t = _fadeAnimation.value;
            final dx = (1.0 - t) * 0.035 * _slideDirection;
            return Opacity(
              opacity: 0.85 + 0.15 * t,
              child: FractionalTranslation(
                translation: Offset(dx, 0),
                child: child,
              ),
            );
          },
          child: IndexedStack(
            index: _currentIndex,
            sizing: StackFit.expand,
            children: screens,
          ),
        ),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemCount = navItems.length;
                final tabWidth = constraints.maxWidth / itemCount;

                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: (details) {
                    if (tabWidth <= 0) return;
                    final targetIndex = (details.localPosition.dx ~/ tabWidth)
                        .clamp(0, itemCount - 1);
                    _onTabSelected(targetIndex);
                  },
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      AnimatedPositioned(
                        key: const Key('nav_sliding_pill'),
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        left: _currentIndex * tabWidth + 6,
                        top: 0,
                        bottom: 0,
                        width: math.max(0.0, tabWidth - 12),
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3EEDF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(itemCount, (index) {
                          final item = navItems[index];
                          final isSelected = _currentIndex == index;
                          final label = item['label'] as String;
                          final type = item['type'] as ThinLineNavType;

                          return Expanded(
                            child: Semantics(
                              label: 'Tab $label',
                              selected: isSelected,
                              button: true,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _onTabSelected(index),
                                child: Center(
                                  heightFactor: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 6,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AnimatedScale(
                                          scale: isSelected ? 1.08 : 1.0,
                                          duration: const Duration(
                                            milliseconds: 240,
                                          ),
                                          curve: Curves.easeOutBack,
                                          child: ThinLineNavIcon(
                                            type: type,
                                            size: 22,
                                            isSelected: isSelected,
                                            color: isSelected
                                                ? const Color(0xFF1F5C4A)
                                                : const Color(0xFF6F7B74),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        AnimatedDefaultTextStyle(
                                          duration: const Duration(
                                            milliseconds: 220,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? const Color(0xFF1F5C4A)
                                                : const Color(0xFF6F7B74),
                                          ),
                                          child: Text(
                                            label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
