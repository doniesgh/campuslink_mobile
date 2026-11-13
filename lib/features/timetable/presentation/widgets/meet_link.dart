import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_snack.dart';

/// Opens a Google Meet link (the Meet app, or the browser). Answers false
/// when nothing could open it. Tests override it.
typedef MeetLauncher = Future<bool> Function(Uri url);

final meetLauncherProvider = Provider<MeetLauncher>(
  (ref) => (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);

/// "Online" chip of an online class.
class OnlineChip extends StatelessWidget {
  const OnlineChip({super.key});

  @override
  Widget build(BuildContext context) =>
      const AppBadge('Online', tone: BadgeTone.primary, icon: Icons.videocam_outlined);
}

/// "Join Google Meet": opens [url], or says why it can't.
class JoinMeetButton extends ConsumerWidget {
  const JoinMeetButton({super.key, required this.url, this.compact = false, this.onHero = false});

  /// Null while the link isn't known yet.
  final String? url;

  /// Smaller, for the cards of a list.
  final bool compact;

  /// White, on the purple "Up next" card.
  final bool onHero;

  Future<void> _open(BuildContext context, WidgetRef ref, String link) async {
    final uri = Uri.tryParse(link);
    var opened = false;
    try {
      opened = uri != null && await ref.read(meetLauncherProvider)(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      showAppSnack(context, 'Could not open Google Meet. The link is $link');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = url;
    final label = link == null ? 'Google Meet link coming soon' : 'Join Google Meet';
    final onPressed = link == null ? null : () => _open(context, ref, link);
    final style = FilledButton.styleFrom(
      visualDensity: compact ? VisualDensity.compact : null,
      padding: compact ? const EdgeInsets.symmetric(horizontal: 12) : null,
      backgroundColor: onHero ? Colors.white : null,
      foregroundColor: onHero ? Theme.of(context).colorScheme.primary : null,
    );
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: const Icon(Icons.videocam_outlined, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
