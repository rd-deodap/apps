// lib/splash/widgets/onboarding_bottom_panel.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dd_clo_packing_app/theme/app_color.dart';

class OnboardingBottomPanel extends StatelessWidget {
  final double width;
  final double height;
  final double sidePad;
  final String title;
  final String description;
  final double titleSize;
  final double descSize;
  final int pageCount;
  final int currentPage;
  final VoidCallback onNext;

  const OnboardingBottomPanel({
    super.key,
    required this.width,
    required this.height,
    required this.sidePad,
    required this.title,
    required this.description,
    required this.titleSize,
    required this.descSize,
    required this.pageCount,
    required this.currentPage,
    required this.onNext,
  });

  bool get _isLast => currentPage == pageCount - 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.94),
            AppColors.navyblueLight.withOpacity(0.72),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(sidePad, 16, sidePad, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              textStyle: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                height: 1.15,
                letterSpacing: -0.2,
                color: AppColors.textDark,
                shadows: [
                  Shadow(
                    color: Colors.white.withOpacity(0.5),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              textStyle: TextStyle(
                fontSize: descSize,
                fontWeight: FontWeight.w400,
                height: 1.45,
                letterSpacing: -0.1,
                color: AppColors.textMuted,
              ),
            ),
          ),

          const Spacer(),

          // Indicators + CTA (inside a small elevated strip)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.95),
                  AppColors.navyblueLight.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.6),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Indicators
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: List.generate(pageCount, (i) {
                      final bool active = i == currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 8,
                        width: active ? 26 : 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: active
                              ? const LinearGradient(
                                  colors: [AppColors.navyblue, AppColors.navyblueDark],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: active ? null : const Color(0xFFCEC9DB),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: AppColors.navyblue.withOpacity(0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                      );
                    }),
                  ),
                ),

                // CTA
                _isLast
                    // Last page: "Get Started" button
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.navyblue, AppColors.navyblueDark],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.navyblue.withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          onPressed: onNext,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Get Started',
                                style: GoogleFonts.inter(
                                  textStyle: const TextStyle(
                                    fontSize: 17,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
                                        offset: Offset(0, 1),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                CupertinoIcons.chevron_right,
                                size: 18,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      )
                    // Other pages: circular next button
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.navyblue, AppColors.navyblueDark],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.navyblue.withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          borderRadius: BorderRadius.circular(999),
                          minimumSize: const Size(52, 52),
                          onPressed: onNext,
                          child: const SizedBox(
                            width: 52,
                            height: 52,
                            child: Center(
                              child: Icon(
                                CupertinoIcons.chevron_right,
                                size: 22,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
