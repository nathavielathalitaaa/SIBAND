import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class OnboardingItem {
  final String image;
  final String eyebrow;
  final String title;
  final String description;

  const OnboardingItem({
    required this.image,
    required this.eyebrow,
    required this.title,
    required this.description,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _items = const [
    OnboardingItem(
      image: 'assets/onboarding/onboarding_1.png',
      eyebrow: 'SELAMAT DATANG DI SIBAND',
      title: 'Temani tumbuhnya,\ndengan lebih tenang.',
      description:
          'Ruang pendamping bagi orang tua untuk memahami kebutuhan, emosi, dan keseharian anak.',
    ),
    OnboardingItem(
      image: 'assets/onboarding/onboarding_2.png',
      eyebrow: 'PAHAMI POLANYA',
      title: 'Setiap anak punya\ncaranya sendiri.',
      description:
          'Kenali pemicu sensorik, suasana hati, dan hal-hal yang membantu anak merasa aman.',
    ),
    OnboardingItem(
      image: 'assets/onboarding/onboarding_3.png',
      eyebrow: 'LANGKAH KECIL BERARTI',
      title: 'Catat hari ini,\nlihat perkembangannya.',
      description:
          'Simpan jurnal dan catatan kejadian agar orang tua dan pendamping bisa melihat pola dari waktu ke waktu.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    if (_currentPage < _items.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done', true);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F4EF),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final width = constraints.maxWidth;

          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: _items.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Stack(
                    children: [
                      // Top illustration: menempel ke atas, full width, sampai ±47%
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: height * 0.47,
                        child: Image.asset(
                          item.image,
                          width: width,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                      // Text block: mulai ±49.5%, padding kiri ~43dp
                      Positioned(
                        top: height * 0.495,
                        left: 43,
                        right: 36,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.eyebrow.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                                color: const Color(0xFF1F5C4A),
                              ),
                            ),
                            SizedBox(height: height * 0.018),
                            Text(
                              item.title,
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                                color: const Color(0xFF1E2A24),
                              ),
                            ),
                            SizedBox(height: height * 0.014),
                            Text(
                              item.description,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                                color: const Color(0xFF6F7B74),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              // Indikator: aktif pill 22x5dp #1F5C4A, tidak aktif titik 5dp #CDEBA5, jarak 6dp, di tengah horizontal, posisi ±76.5%
              Positioned(
                top: height * 0.765,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < _items.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          width: _currentPage == i ? 22 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: _currentPage == i
                                ? const Color(0xFF1F5C4A)
                                : const Color(0xFFCDEBA5),
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Tombol: lingkaran 44dp #1F5C4A, ikon chevron putih 24dp, kanan 22dp, bawah ~36dp (+safe area)
              Positioned(
                right: 22,
                bottom: 36 + bottomSafeArea,
                child: Semantics(
                  label: 'Lanjut',
                  button: true,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Material(
                      color: const Color(0xFF1F5C4A),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _handleNext,
                        child: const Center(
                          child: Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
