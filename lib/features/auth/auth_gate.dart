import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/brand_mark.dart';
import '../../state/auth_controller.dart';
import '../shell/home_shell.dart';
import 'welcome_screen.dart';

class BrandedSplash extends StatelessWidget {
  const BrandedSplash({super.key, this.message = 'Starting your workspace…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        backgroundColor: AppPalette.cream,
        body: Stack(
          children: [
            Positioned(
              top: -120,
              right: -100,
              child: _Glow(color: AppPalette.emerald.withValues(alpha: 0.12)),
            ),
            Positioned(
              bottom: -160,
              left: -120,
              child: _Glow(
                color: AppPalette.emeraldDeep.withValues(alpha: 0.12),
              ),
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandHeroMark(size: 104),
                    const SizedBox(height: 28),
                    const BrandLockup(
                      markSize: 0,
                      titleSize: 34,
                      showTagline: true,
                    ),
                    const SizedBox(height: 52),
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppPalette.emerald,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      message,
                      style: TextStyle(
                        color: AppPalette.ink.withValues(alpha: 0.55),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 26),
                child: Text(
                  'SELL · TRACK · GROW',
                  style: TextStyle(
                    color: AppPalette.emeraldDeep.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    return StreamBuilder(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const BrandedSplash();
        }
        if (snapshot.hasError) {
          return const BrandedSplash(
            message: 'Unable to reach your account. Check your connection.',
          );
        }
        if (snapshot.data == null) {
          return const WelcomeScreen();
        }
        return const HomeShell();
      },
    );
  }
}
