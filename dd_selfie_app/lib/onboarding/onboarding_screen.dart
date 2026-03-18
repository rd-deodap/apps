import 'package:dd_selfie_app/onboarding/components/care_view.dart';
import 'package:dd_selfie_app/onboarding/components/center_next_button.dart';
import 'package:dd_selfie_app/onboarding/components/mood_diary_vew.dart';
import 'package:dd_selfie_app/onboarding/components/relax_view.dart';
import 'package:dd_selfie_app/onboarding/components/splash_view.dart';
import 'package:dd_selfie_app/onboarding/components/top_back_skip_view.dart';
import 'package:dd_selfie_app/onboarding/components/welcome_view.dart';
import 'package:flutter/material.dart';
import 'package:dd_selfie_app/login/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  _IntroductionAnimationScreenState createState() =>
      _IntroductionAnimationScreenState();
}

class _IntroductionAnimationScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  AnimationController? _animationController;

  @override
  void initState() {
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 8));
    _animationController?.animateTo(0.0);
    super.initState();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7EBE1),
      body: ClipRect(
        child: Stack(
          children: [
            SplashView(animationController: _animationController!),
            RelaxView(animationController: _animationController!),
            CareView(animationController: _animationController!),
            MoodDiaryVew(animationController: _animationController!),
            WelcomeView(animationController: _animationController!),

            TopBackSkipView(
              onBackClick: _onBackClick,
              onSkipClick: _onSkipClick,
              animationController: _animationController!,
            ),

            CenterNextButton(
              animationController: _animationController!,
              onNextClick: _onNextClick,
              onLoginClick: _signUpClick, // ✅ Sign Up -> Login
            ),
          ],
        ),
      ),
    );
  }

  void _onSkipClick() {
    _animationController?.animateTo(0.8,
        duration: const Duration(milliseconds: 1200));
  }

  void _onBackClick() {
    if (_animationController!.value >= 0 && _animationController!.value <= 0.2) {
      _animationController?.animateTo(0.0);
    } else if (_animationController!.value > 0.2 &&
        _animationController!.value <= 0.4) {
      _animationController?.animateTo(0.2);
    } else if (_animationController!.value > 0.4 &&
        _animationController!.value <= 0.6) {
      _animationController?.animateTo(0.4);
    } else if (_animationController!.value > 0.6 &&
        _animationController!.value <= 0.8) {
      _animationController?.animateTo(0.6);
    } else if (_animationController!.value > 0.8 &&
        _animationController!.value <= 1.0) {
      _animationController?.animateTo(0.8);
    }
  }

  void _onNextClick() {
    if (_animationController!.value >= 0 && _animationController!.value <= 0.2) {
      _animationController?.animateTo(0.4);
    } else if (_animationController!.value > 0.2 &&
        _animationController!.value <= 0.4) {
      _animationController?.animateTo(0.6);
    } else if (_animationController!.value > 0.4 &&
        _animationController!.value <= 0.6) {
      _animationController?.animateTo(0.8);
    } else if (_animationController!.value > 0.6 &&
        _animationController!.value <= 0.8) {
      _signUpClick(); // last step -> login
    }
  }

  void _signUpClick() {
    // ✅ Replace LoginScreen() with your actual login widget
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }
}
