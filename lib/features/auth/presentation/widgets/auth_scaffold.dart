import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// Layout of every auth screen (Stitch "01. Onboarding & Login"):
/// purple brand hero on top, a rounded sheet overlapping it below.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.heroHeight = 290,
  });

  final String title;
  final String subtitle;
  final Widget child;

  /// Minimum hero height, below the status bar.
  final double heroHeight;

  /// How far the sheet slides up over the hero.
  static const _overlap = 24.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // white status bar icons over the hero
      child: Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Hero(minHeight: heroHeight + _overlap),
              Transform.translate(
                offset: const Offset(0, -_overlap),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: AppRadius.sheetTop,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        blurRadius: 30,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.xl + bottomInset,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: scheme.outlineVariant.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(title, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        child,
                      ],
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

/// Coral text link used in the auth sheets ("Forgot?", "Register →").
class AuthLink extends StatelessWidget {
  const AuthLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = scheme.brightness == Brightness.dark ? scheme.secondary : AppColors.accentText;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

/// "New student? Register →" row at the bottom of a sheet.
class AuthFooter extends StatelessWidget {
  const AuthFooter({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Wrap, not Row: on narrow screens or large fonts the link goes to a
    // second line instead of overflowing.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      children: [
        Text(
          prompt,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        AuthLink(label: action, onTap: onTap),
      ],
    );
  }
}

/// Horizontal rule with a centered caption ("or continue with ...").
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(child: Divider(height: 1, color: scheme.surfaceContainerHigh)),
          Flexible(
            flex: 4, // the label wraps instead of overflowing on large font sizes
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          Expanded(child: Divider(height: 1, color: scheme.surfaceContainerHigh)),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.minHeight});

  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.hero),
      child: CustomPaint(
        painter: const _PulseWavesPainter(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight + top),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              top + AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xl + AuthScaffold._overlap, // room for the overlapping sheet
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (context.canPop())
                      _GlassPill(
                        tooltip: 'Back',
                        onTap: () => context.pop(),
                        child: const Icon(Icons.arrow_back, size: 18, color: Colors.white),
                      ),
                    const Spacer(),
                    const _ThemeSwitch(),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Column(
                    children: [
                      const _BrandMark(),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'CampusPulse',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontSize: 30,
                          height: 38 / 30,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your campus, in your pocket.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.onHero,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// App icon: white rounded square with a cap and a coral "pulse" dot.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.school, size: 28, color: AppColors.primary),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "☀ LIGHT" / "☾ DARK" pill: switches the app theme.
class _ThemeSwitch extends ConsumerWidget {
  const _ThemeSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return _GlassPill(
      tooltip: 'Toggle theme',
      onTap: () => ref
          .read(themeModeProvider.notifier)
          .set(dark ? ThemeMode.light : ThemeMode.dark),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(dark ? Icons.dark_mode : Icons.light_mode, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            dark ? 'DARK' : 'LIGHT',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Translucent white pill used on top of the hero.
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child, required this.onTap, required this.tooltip});

  final Widget child;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.2),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Decorative rings and wave behind the hero (from the design's SVG, 400x300 viewBox).
class _PulseWavesPainter extends CustomPainter {
  const _PulseWavesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 400;
    final sy = size.height / 300;
    final center = Offset(340 * sx, 40 * sy);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawCircle(center, 140 * sx, ring);

    ring
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(center, 210 * sx, ring);

    final wave = Path()
      ..moveTo(-20 * sx, 220 * sy)
      ..quadraticBezierTo(80 * sx, 150 * sy, 180 * sx, 200 * sy)
      ..quadraticBezierTo(280 * sx, 250 * sy, 380 * sx, 140 * sy);
    ring
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawPath(wave, ring);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
