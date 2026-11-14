import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/palette.dart';
import '../../core/utils/error_messages.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/brand_mark.dart';
import '../../state/auth_controller.dart';
import 'auth_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _loading = false;

  Future<void> _continueAsGuest() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthController>().signInAnonymously();
    } catch (error) {
      if (mounted) {
        showAppSnack(context, friendlyError(error), isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openSignIn() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppPalette.cream,
      body: Stack(
        children: [
          const Positioned(top: -140, right: -120, child: _WelcomeGlow()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: BrandHeroMark(size: 92)),
                      const SizedBox(height: 24),
                      const Center(
                        child: BrandLockup(
                          markSize: 0,
                          titleSize: 32,
                          showTagline: true,
                        ),
                      ),
                      const SizedBox(height: 42),
                      Text(
                        'Run your shop with confidence',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppPalette.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Track sales, stock and profits in one place. Start in seconds — no account needed.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppPalette.ink.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 36),
                      FilledButton(
                        onPressed: _loading ? null : _continueAsGuest,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppPalette.charcoal,
                                ),
                              )
                            : const Text('Continue as guest'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _loading ? null : _openSignIn,
                        child: const Text('Sign in / Create account'),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        'Guest mode keeps your records on this device. Add an email later to secure them.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppPalette.ink.withValues(alpha: 0.4),
                          fontSize: 10.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeGlow extends StatelessWidget {
  const _WelcomeGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 340,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppPalette.emerald.withValues(alpha: 0.12),
            AppPalette.emerald.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
