import 'package:flutter/material.dart';

import '../../theme/app_styles.dart';
import '../../widgets/mascot_logo.dart';
import '../../widgets/ui.dart';
import '../auth/login_screen.dart';
import 'quiz_screen.dart';

/// First screen for a signed-out user: what TimeWise is, then Get Started
/// (onboarding quiz) or Log In.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final linkColor = readableOn(context.primary, context.cs.surface);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 192,
                            height: 192,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  context.primary.withValues(alpha: 0.22),
                                  context.primary.withValues(alpha: 0.10),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40),
                              gradient: context.primaryGradient,
                              boxShadow: [
                                BoxShadow(color: context.primary.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: const Center(child: MascotLogo(size: 120)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text('TimeWise', style: context.h1.copyWith(fontSize: 32, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text(
                        'Smart Time Management',
                        style: context.h3.copyWith(color: linkColor),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Plan your time, organize your tasks, and let AI help you build a schedule that works for you.',
                        textAlign: TextAlign.center,
                        style: context.bodyMuted.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: GradientButton(
                label: 'Get Started',
                icon: Icons.arrow_forward,
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizScreen())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 4),
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: linkColor),
                child: const Text('Already have an account? Log In', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
