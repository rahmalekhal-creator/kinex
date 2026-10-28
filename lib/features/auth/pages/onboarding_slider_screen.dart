import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import 'package:reeducation/features/auth/pages/login_screen.dart';
import 'package:reeducation/l10n/l10n.dart';
import 'package:reeducation/widgets/kinex_logo.dart';
import 'package:reeducation/widgets/language_button.dart';

class ScanSliderScreen extends StatefulWidget {
  const ScanSliderScreen({super.key});

  @override
  _ScanSliderScreenState createState() => _ScanSliderScreenState();
}

class _ScanSliderScreenState extends State<ScanSliderScreen> {
  int _currentIndex = 0;

  List<Map<String, dynamic>> _slides(AppLocalizations l10n) => [
    {
      'image': 'assets/slider1.png',
      'eyebrow': l10n.onboardingEyebrow1,
      'title': l10n.onboardingTitle1,
      'subtitle': l10n.onboardingSubtitle1,
      'icon': Icons.insights_rounded,
    },
    {
      'image': 'assets/slider2.png',
      'eyebrow': l10n.onboardingEyebrow2,
      'title': l10n.onboardingTitle2,
      'subtitle': l10n.onboardingSubtitle2,
      'icon': Icons.accessibility_new_rounded,
    },
    {
      'image': 'assets/slider3.png',
      'eyebrow': l10n.onboardingEyebrow3,
      'title': l10n.onboardingTitle3,
      'subtitle': l10n.onboardingSubtitle3,
      'icon': Icons.favorite_outline_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scans = _slides(l10n);
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final carouselHeight = screenHeight < 760 ? 410.0 : 470.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF071120),
              Color(0xFF0C1730),
              Color(0xFF121F3F),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -40,
                right: -10,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF63E6FF).withValues(alpha: 0.14),
                  ),
                ),
              ),
              Positioned(
                bottom: 60,
                left: -50,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF8A7CFF).withValues(alpha: 0.10),
                  ),
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              KinexLogo(size: 20, radius: 6),
                              SizedBox(width: 10),
                              Text(
                                'Kinex',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const LanguageButton(color: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      l10n.onboardingHeadline,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.onboardingIntro,
                      style: const TextStyle(
                        color: Color(0xFFA8B3CF),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.onboardingAudience,
                      style: const TextStyle(
                        color: Color(0xFF63E6FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 28),
                    CarouselSlider.builder(
                      itemCount: scans.length,
                      options: CarouselOptions(
                        height: carouselHeight,
                        autoPlay: true,
                        enlargeCenterPage: true,
                        viewportFraction: 0.9,
                        onPageChanged: (index, reason) {
                          setState(() => _currentIndex = index);
                        },
                      ),
                      itemBuilder: (context, index, realIndex) {
                        final scan = scans[index];

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final compactCard = constraints.maxHeight < 390;
                            final imageMaxHeight = compactCard ? 104.0 : 190.0;
                            final titleFontSize = compactCard ? 18.0 : 24.0;
                            final subtitleFontSize = compactCard ? 11.0 : 15.0;
                            final titleMaxLines = compactCard ? 1 : 2;
                            final helperMaxLines = compactCard ? 1 : 2;
                            final subtitleMaxLines = compactCard ? 1 : 2;
                            final helperGap = compactCard ? 1.0 : 2.0;
                            final subtitleGap = compactCard ? 6.0 : 8.0;

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              padding: EdgeInsets.all(compactCard ? 12 : 18),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF162544),
                                    Color(0xFF0E1931),
                                  ],
                                ),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.24),
                                    blurRadius: 28,
                                    offset: const Offset(0, 18),
                                  ),
                                ],
                              ),
                              child: SizedBox(
                                height: constraints.maxHeight,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      color: const Color(0xFF63E6FF).withValues(alpha: 0.14),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          scan['icon'] as IconData,
                                          color: const Color(0xFF63E6FF),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            scan['eyebrow'] as String,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF63E6FF),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: compactCard ? 8 : 18),
                                  Expanded(
                                    child: Center(
                                      child: Container(
                                        width: double.infinity,
                                        constraints: BoxConstraints(maxHeight: imageMaxHeight),
                                        padding: EdgeInsets.all(compactCard ? 12 : 16),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(24),
                                          color: Colors.white.withValues(alpha: 0.05),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                        ),
                                        child: Image.asset(
                                          scan['image'] as String,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Center(
                                              child: Icon(
                                                Icons.image_not_supported_outlined,
                                                color: Color(0xFFA8B3CF),
                                                size: 48,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: compactCard ? 6 : 16),
                                  Expanded(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 400),
                                      child: Column(
                                        key: ValueKey(index),
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            scan['title'] as String,
                                            maxLines: titleMaxLines,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: titleFontSize,
                                              fontWeight: FontWeight.w800,
                                              height: 1.2,
                                            ),
                                          ),
                                          SizedBox(height: helperGap),
                                          Text(
                                            l10n.onboardingCardHelper,
                                            maxLines: helperMaxLines,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF63E6FF),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: subtitleGap),
                                          Text(
                                            scan['subtitle'] as String,
                                            maxLines: subtitleMaxLines,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: const Color(0xFFA8B3CF),
                                              fontSize: subtitleFontSize,
                                              height: 1.45,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(scans.length, (index) {
                        final isActive = _currentIndex == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: isActive ? 28 : 10,
                          height: 10,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            color: isActive ? const Color(0xFF63E6FF) : Colors.white.withValues(alpha: 0.20),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Colors.white.withValues(alpha: 0.06),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_moon_outlined, color: Color(0xFF8A7CFF)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.onboardingFooter,
                              style: const TextStyle(
                                color: Color(0xFFA8B3CF),
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(context, _createRoute());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF63E6FF),
                          foregroundColor: const Color(0xFF071120),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          l10n.continueToLogin,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Route _createRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
}

