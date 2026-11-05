import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/entities/lost_item.dart';
import '../providers/forum_providers.dart';
import 'lost_found_visuals.dart';

/// Opens the claim / "J'ai trouvé cet objet" / serial-number sheet for [item].
/// Resolves to true once the request has been sent to the security desk.
Future<bool> showLostItemRequestSheet(BuildContext context, LostItem item) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    // Above the bottom navigation bar, as in the mockup.
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    builder: (_) => LostItemRequestSheet(item: item),
  );
  return sent ?? false;
}

class LostItemRequestSheet extends ConsumerStatefulWidget {
  const LostItemRequestSheet({super.key, required this.item});

  final LostItem item;

  @override
  ConsumerState<LostItemRequestSheet> createState() => _LostItemRequestSheetState();
}

class _LostItemRequestSheetState extends ConsumerState<LostItemRequestSheet> {
  final _proof = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Rebuild so the submit button follows the field content.
    _proof.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _proof.dispose();
    super.dispose();
  }

  bool get _canSend => _proof.text.trim().isNotEmpty && !_sending;

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await ref
        .read(forumRepositoryProvider)
        .sendLostItemRequest(itemId: widget.item.id, proof: _proof.text.trim());
    if (!mounted) return;
    result.when(
      success: (_) => Navigator.of(context).pop(true),
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
    final item = widget.item;
    final desk = item.pickupDesk ?? item.location;

    final (String title, String subtitle, String submit, Color iconBg, Color iconFg) =
        switch (item.action) {
      LostItemAction.claim => (
          'Réclamer: ${item.title}',
          'Retrait au guichet: $desk',
          'Envoyer ma demande de réclamation',
          scheme.surfaceContainer,
          scheme.primary,
        ),
      LostItemAction.reportFound => (
          'Contacter le propriétaire',
          'Objet: ${item.title} (${item.location})',
          "Signaler que j'ai l'objet",
          toneColors(scheme, BadgeTone.accent).$1,
          lostFoundAccentText(scheme),
        ),
      LostItemAction.verifySerial => (
          'Vérification Numéro de Série',
          '${item.title} - $desk',
          'Transmettre les 4 derniers chiffres',
          scheme.surfaceContainer,
          lostFoundSuccessColor(scheme),
        ),
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: iconBg,
                    child: Icon(lostItemCategoryIcon(item.category), size: 20, color: iconFg),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.of(context).pop(false),
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surfaceContainer,
                      foregroundColor: scheme.onSurfaceVariant,
                      minimumSize: const Size(32, 32),
                      fixedSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: scheme.primary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        "Un agent du campus ou l'étudiant vérifie l'identité avec la "
                        "carte d'étudiant avant remise officielle.",
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _proof,
                label: 'Indice distinctif ou preuve de propriété',
                hint: item.action == LostItemAction.verifySerial
                    ? 'Ex: 4 derniers chiffres du numéro de série'
                    : 'Ex: autocollant au dos, couleur de la housse...',
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: submit,
                icon: Icons.send_outlined,
                isLoading: _sending,
                onPressed: _canSend ? _send : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
