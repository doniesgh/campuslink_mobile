import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/forum_post.dart';
import '../../domain/forum_rules.dart';
import '../providers/forum_providers.dart';
import 'forum_sheet_parts.dart';

/// Themes offered as the badge of a new idea (the first one is the default).
const ideaThemes = [defaultIdeaTag, 'Vie de campus', 'Pédagogie', 'Événements', 'Numérique'];

/// Opens the "Proposer une idée" sheet. Resolves to the published idea (already
/// added to [ideasProvider]), or null if the student closed the sheet.
Future<ForumPost?> showIdeaComposerSheet(BuildContext context) =>
    showModalBottomSheet<ForumPost>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      builder: (_) => const IdeaComposerSheet(),
    );

class IdeaComposerSheet extends ConsumerStatefulWidget {
  const IdeaComposerSheet({super.key});

  @override
  ConsumerState<IdeaComposerSheet> createState() => _IdeaComposerSheetState();
}

class _IdeaComposerSheetState extends ConsumerState<IdeaComposerSheet> {
  final _body = TextEditingController();
  String _theme = ideaThemes.first;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Rebuild so the submit button follows the field content.
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  bool get _canSend => _body.text.trim().isNotEmpty && !_sending;

  Future<void> _publish() async {
    if (!_canSend) return;
    final error = ideaBodyError(_body.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await ref
        .read(ideasProvider.notifier)
        .publish(body: _body.text.trim(), tag: _theme);
    if (!mounted) return;
    result.when(
      success: (idea) => Navigator.of(context).pop(idea),
      failure: (f) => setState(() {
        _sending = false;
        _error = f.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (iconBg, iconFg) = toneColors(scheme, BadgeTone.accent);

    return ForumSheetScaffold(
      children: [
        ForumSheetHeader(
          icon: Icons.tips_and_updates_outlined,
          iconColors: (iconBg, iconFg),
          title: 'Proposer une idée',
          subtitle: 'Visible par tous les étudiants ESPRIT',
          onClose: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: AppSpacing.lg),
        const ForumFieldLabel('Thème'),
        const SizedBox(height: AppSpacing.xs + 2),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final t in ideaThemes)
              ChoiceChip(
                label: Text(t),
                selected: t == _theme,
                onSelected: _sending ? null : (_) => setState(() => _theme = t),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const ForumFieldLabel('Votre idée'),
        const SizedBox(height: AppSpacing.xs + 2),
        TextField(
          controller: _body,
          enabled: !_sending,
          minLines: 4,
          maxLines: 8,
          maxLength: IdeaLimits.bodyMax,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ex : des bornes de recharge près des espaces calmes de la '
                'bibliothèque centrale...',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ForumSheetNote(
          icon: Icons.how_to_vote_outlined,
          text: 'Les idées les plus soutenues sont étudiées chaque mois par le BDE.',
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          ForumSheetError(_error!),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Publier mon idée',
          icon: Icons.send_outlined,
          variant: AppButtonVariant.accent,
          isLoading: _sending,
          onPressed: _canSend ? _publish : null,
        ),
      ],
    );
  }
}
