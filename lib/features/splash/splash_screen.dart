import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ────────────────────────────────────────────
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _taglineCtrl;
  late final AnimationController _shimmerCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;

  @override
  void initState() {
    super.initState();

    // Force dark status bar icons so they show on the light splash
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // ── Logo: scale + fade + slight upward slide ─────────────────────
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));

    _logoScale = CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut)
        .drive(Tween(begin: 0.3, end: 1.0));

    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut)
        .drive(Tween(begin: 0.0, end: 1.0));

    _logoSlide = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut)
        .drive(Tween(begin: const Offset(0, 0.3), end: Offset.zero));

    // ── Brand name: fade + slide up ──────────────────────────────────
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _textFade = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut)
        .drive(Tween(begin: 0.0, end: 1.0));

    _textSlide = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut)
        .drive(Tween(begin: const Offset(0, 0.4), end: Offset.zero));

    // ── Tagline: fade + slide up ─────────────────────────────────────
    _taglineCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    _taglineFade = CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut)
        .drive(Tween(begin: 0.0, end: 1.0));

    _taglineSlide =
        CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut)
            .drive(Tween(begin: const Offset(0, 0.5), end: Offset.zero));

    // ── Shimmer on logo ───────────────────────────────────────────────
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    // Logo pops in first
    await Future.delayed(const Duration(milliseconds: 200));
    _logoCtrl.forward();

    // Brand name slides in shortly after
    await Future.delayed(const Duration(milliseconds: 400));
    _textCtrl.forward();

    // Tagline last
    await Future.delayed(const Duration(milliseconds: 250));
    _taglineCtrl.forward();

    // Wait for auth to initialise then navigate
    await Future.delayed(const Duration(milliseconds: 1400));
    _navigate();
  }

  void _navigate() {
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (auth.initialized) {
      context.go('/');
    } else {
      // Auth not ready yet — wait for it
      ref.listenManual(authProvider, (_, next) {
        if (next.initialized && mounted) context.go('/');
      });
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _taglineCtrl.dispose();
    _shimmerCtrl.dispose();
    // Restore normal status bar on exit
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF4C1D95), // violet-900
              Color(0xFF6D28D9), // violet-700
              Color(0xFF9333EA), // purple-600
              Color(0xFFD946EF), // fuchsia-500
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(children: [
          // ── Decorative background circles ─────────────────────────
          Positioned(
            top: -80, right: -80,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -100, left: -60,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            top: 160, left: -40,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                SlideTransition(
                  position: _logoSlide,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: _AnimatedLogo(shimmerCtrl: _shimmerCtrl),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Brand name
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: Column(children: [
                      const Text(
                        'Harahori Telecom',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                            letterSpacing: 3,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),

                const SizedBox(height: 12),

                // Tagline
                SlideTransition(
                  position: _taglineSlide,
                  child: FadeTransition(
                    opacity: _taglineFade,
                    child: const Text(
                      'Your Trusted Mobile Partner',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white60,
                        letterSpacing: 0.3,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom "Made in India" footer ─────────────────────────
          Positioned(
            bottom: 40,
            left: 0, right: 0,
            child: FadeTransition(
              opacity: _taglineFade,
              child: const Column(children: [
                Text(
                  'Made with 💜 in India',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white38,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Animated Logo Widget ───────────────────────────────────────────────────
class _AnimatedLogo extends StatelessWidget {
  final AnimationController shimmerCtrl;
  const _AnimatedLogo({required this.shimmerCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF5F3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFFD946EF).withOpacity(0.4),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(children: [
        // Shimmer overlay
        AnimatedBuilder(
          animation: shimmerCtrl,
          builder: (_, __) => ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.0),
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
                begin: Alignment(
                    -1.5 + shimmerCtrl.value * 3.0, -0.5),
                end: Alignment(
                    -0.5 + shimmerCtrl.value * 3.0, 0.5),
              ).createShader(bounds),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),

        // Logo icon — replace this with your actual logo image later:
        // Image.asset('assets/images/logo.png', fit: BoxFit.contain)
        Center(
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Image.asset('assets/images/harahori.jpg', fit: BoxFit.contain),
  ),
),
      ]),
    );
  }
}
