// lib/splash/onboarding_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dd_clo_packing_app/auth/login.dart';
import 'package:dd_clo_packing_app/theme/app_color.dart';
import 'package:dd_clo_packing_app/splash/onboardingVo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenViewState();
}

class _OnboardingScreenViewState extends State<OnboardingScreen> {
  final List<Map<String, String>> onBoardingData = const [

    {
      "image": "assets/images/a1.png",
      "title": "Welcome to DeoDap CLO Packaging App",
      "description":
      "Streamline warehouse operations with DeoDap’s CLO packaging app. Manage orders, packaging tasks, and inventory from one place.",
    },
    {
      "image": "assets/images/a2.png",
      "title": "Scan Orders & Products Quickly",
      "description":
      "Scan QR codes for orders and products to ensure fast, accurate order verification and packaging within your warehouse workflow.",
    },
    {
      "image": "assets/images/a3.png",
      "title": "Order Packaging & Tracking",
      "description":
      "View all packaging orders in real time. Track order status, manage packaging progress, mark delays, and ensure timely dispatch.",
    },
  ];


  final PageController pageController = PageController();
  int currentPage = 0;

  void _onChanged(int index) => setState(() => currentPage = index);

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  void _goToLogin(BuildContext context) {
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Soft background with a gentle vertical gradient toward purple
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(0, -1),
            end: Alignment(0, 1),
            colors: [Color(0xFFF9F7FF), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Optional texture overlay (won't crash if missing)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.03,
                    child: Image(
                      image: AssetImage('assets/images/leather_texture.png'),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),

              // === PAGE CONTENT (image big + bottom curved panel) ===
              LayoutBuilder(
                builder: (context, constraints) {
                  final double maxW = constraints.maxWidth;
                  final double maxH = constraints.maxHeight;

                  // Larger image height — sits behind the curved bottom panel
                  final double imageTopPadding = maxH * 0.2;
                  final double imageHeightFactor = 0.80; // increased

                  return PageView.builder(
                    controller: pageController,
                    itemCount: onBoardingData.length,
                    onPageChanged: _onChanged,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final data = onBoardingData[index];

                      return Stack(
                        children: [
                          // ===== Big Illustration (top) =====
                          Positioned.fill(
                            child: Column(
                              children: [
                                SizedBox(height: imageTopPadding),
                                Expanded(
                                  flex: (imageHeightFactor * 1000).toInt(),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: maxW * 0.06,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.contain,
                                      alignment: Alignment.topCenter,
                                      child: SizedBox(
                                        width: maxW * 0.95,
                                        child: AspectRatio(
                                          aspectRatio: 1.15,
                                          child: Image.asset(
                                            data['image']!,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const SizedBox.shrink(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 0),
                              ],
                            ),
                          ),

                          // ===== Curved Bottom Panel =====
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: OnboardingBottomPanel(
                              width: maxW,
                              height: maxH * 0.34, // curved panel height
                              sidePad: maxW * 0.06,
                              title: data['title']!,
                              description: data['description']!,
                              titleSize: _clamp(maxW * 0.058, 20, 26),
                              descSize: _clamp(maxW * 0.041, 13, 16),
                              pageCount: onBoardingData.length,
                              currentPage: currentPage,
                              onNext: () {
                                if (currentPage < onBoardingData.length - 1) {
                                  pageController.nextPage(
                                    duration:
                                        const Duration(milliseconds: 420),
                                    curve: Curves.easeOutCubic,
                                  );
                                } else {
                                  _goToLogin(context);
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

              // Skip button (top-right)
              Positioned(
                top: 8,
                right: 8,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      onPressed: () => _goToLogin(context),
                      child: Text(
                        'Skip',
                        style: GoogleFonts.inter(
                          textStyle: const TextStyle(
                            color: AppColors.navyblue,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Utility to clamp a value between min and max.
double _clamp(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}
