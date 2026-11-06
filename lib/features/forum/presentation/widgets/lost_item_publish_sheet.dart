import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/entities/lost_item.dart';
import '../../domain/entities/lost_item_draft.dart';
import '../../domain/forum_rules.dart';
import '../providers/forum_providers.dart';
import '../utils/lost_found_formatters.dart';
import 'forum_sheet_parts.dart';
import 'lost_found_visuals.dart';

/// Central collection points, offered as quick picks for a found item.
const lostFoundCollectionPoints = ['Accueil Bloc C (Ghazela)', 'Hall Central (Charguia)'];

/// Opens the "Publier une annonce" form. Resolves to the published item, or
/// null if the student closed the sheet.
Future<LostItem?> showPublishLostItemSheet(BuildContext context) =>
    showModalBottomSheet<LostItem>(
      context: context,
      // Above the bottom navigation bar, like the request sheet.
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      builder: (_) => const LostItemPublishSheet(),
    );

/// Lost or found notice form. The Perdu / Trouvé toggle switches the
/// kind-specific fields: detail, reward and urgency for a lost item, the
/// drop-off desk for a found one.
class LostItemPublishSheet extends ConsumerStatefulWidget {
  const LostItemPublishSheet({super.key});

  @override
  ConsumerState<LostItemPublishSheet> createState() => _LostItemPublishSheetState();
}

class _LostItemPublishSheetState extends ConsumerState<LostItemPublishSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _zone = TextEditingController();
  final _location = TextEditingController();
  final _detail = TextEditingController();
  final _reward = TextEditingController();
  final _desk = TextEditingController();

  LostItemKind _kind = LostItemKind.lost;
  LostItemCategory? _category;
  LostItemPlace? _place;
  bool _urgent = false;

  /// Set by the first tap on "Publier": errors show from then on.
  bool _submitted = false;
  bool _sending = false;
  String? _error;

  bool get _isLost => _kind == LostItemKind.lost;

  @override
  void dispose() {
    for (final c in [_title, _zone, _location, _detail, _reward, _desk]) {
      c.dispose();
    }
    super.dispose();
  }

  LostItemDraft _draft() => LostItemDraft(
        kind: _kind,
        title: _title.text,
        category: _category!,
        zone: _zone.text,
        location: _location.text,
        place: _place!,
        distinctiveDetail: _isLost ? _detail.text : null,
        reward: _isLost ? _reward.text : null,
        isUrgent: _isLost && _urgent,
        pickupDesk: _isLost ? null : _desk.text,
      );

  Future<void> _publish() async {
    if (_sending) return;
    setState(() {
      _submitted = true;
      _error = null;
    });
    final fieldsOk = _formKey.currentState!.validate();
    if (!fieldsOk || _category == null || _place == null) return;

    setState(() => _sending = true);
    final result = await ref.read(forumRepositoryProvider).publishLostItem(_draft());
    if (!mounted) return;
    result.when(
      success: (item) => Navigator.of(context).pop(item),
      failure: (f) => setState(() {
        _sending = false;
        _error = f.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ForumSheetScaffold(
      children: [
        ForumSheetHeader(
          icon: Icons.campaign_outlined,
          iconColors: toneColors(scheme, BadgeTone.accent),
          title: 'Publier une annonce',
          subtitle: 'Objets perdus & trouvés · ESPRIT',
          onClose: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: AppSpacing.lg),
        _KindToggle(
          kind: _kind,
          onChanged: _sending ? null : (kind) => setState(() => _kind = kind),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _isLost
              ? "Décrivez l'objet : la communauté ESPRIT vous aidera à le retrouver."
              : 'Merci ! Indiquez où son propriétaire pourra le récupérer.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        Form(
          key: _formKey,
          autovalidateMode:
              _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _title,
                label: 'Objet',
                hint: _isLost
                    ? 'Ex : Clés Peugeot + porte-clé ESPRIT'
                    : 'Ex : Calculatrice TI-84 Plus CE',
                textInputAction: TextInputAction.next,
                validator: lostItemTitleError,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ChoiceGroup<LostItemCategory>(
                label: 'Catégorie',
                values: LostItemCategory.values,
                selected: _category,
                labelOf: lostItemCategoryLabel,
                iconOf: lostItemCategoryIcon,
                error: _submitted && _category == null
                    ? "Choisissez une catégorie d'objet."
                    : null,
                onSelected: _sending ? null : (c) => setState(() => _category = c),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _zone,
                label: 'Zone',
                hint: 'Ex : Bloc C, Parking, Bibliothèque',
                textInputAction: TextInputAction.next,
                validator: lostItemZoneError,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _location,
                label: 'Lieu précis',
                hint: 'Ex : Salle C12 (Ghazela)',
                textInputAction: TextInputAction.next,
                validator: lostItemLocationError,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ChoiceGroup<LostItemPlace>(
                label: 'Type de lieu',
                values: LostItemPlace.values,
                selected: _place,
                labelOf: lostItemPlaceLabel,
                iconOf: lostItemPlaceIcon,
                error: _submitted && _place == null ? 'Choisissez le type de lieu.' : null,
                onSelected: _sending ? null : (p) => setState(() => _place = p),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_isLost) ..._lostFields() else ..._foundFields(),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          ForumSheetError(_error!),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: "Publier l'annonce",
          icon: Icons.campaign_outlined,
          variant: AppButtonVariant.accent,
          isLoading: _sending,
          onPressed: _publish,
        ),
      ],
    );
  }

  List<Widget> _lostFields() => [
        AppTextField(
          controller: _detail,
          label: 'Détail distinctif (optionnel)',
          hint: 'Ex : porte-clé drapeau Tunisie',
          textInputAction: TextInputAction.next,
          validator: lostItemDetailError,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _reward,
          label: 'Récompense (optionnel)',
          hint: 'Ex : Café offert ☕',
          textInputAction: TextInputAction.done,
          validator: lostItemRewardError,
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          value: _urgent,
          onChanged: _sending ? null : (v) => setState(() => _urgent = v),
          contentPadding: EdgeInsets.zero,
          title: const Text('Urgent'),
          subtitle: const Text("Papiers, clés, carte d'étudiant... : l'annonce est mise en avant."),
        ),
      ];

  List<Widget> _foundFields() => [
        AppTextField(
          controller: _desk,
          label: "Où récupérer l'objet ?",
          hint: 'Ex : Accueil Bloc C (Ghazela)',
          textInputAction: TextInputAction.done,
          validator: lostItemPickupDeskError,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final point in lostFoundCollectionPoints)
              ActionChip(
                avatar: const Icon(Icons.pin_drop_outlined, size: 16),
                label: Text(point),
                onPressed: _sending
                    ? null
                    : () {
                        _desk.text = point;
                        if (_submitted) _formKey.currentState!.validate();
                      },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const ForumSheetNote(
          icon: Icons.lock_outline,
          text: 'Gardez un détail secret (autocollant, numéro de série) : il servira '
              'à vérifier le propriétaire.',
        ),
      ];
}

/// "Perdu" / "Trouvé" toggle, coral for lost and purple for found (like the
/// filter pills of the board).
class _KindToggle extends StatelessWidget {
  const _KindToggle({required this.kind, required this.onChanged});

  final LostItemKind kind;
  final ValueChanged<LostItemKind>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = kind == LostItemKind.lost
        ? (scheme.secondary, scheme.onSecondary)
        : (scheme.primary, scheme.onPrimary);
    final onChanged = this.onChanged;

    return SegmentedButton<LostItemKind>(
      segments: const [
        ButtonSegment(
          value: LostItemKind.lost,
          icon: Icon(Icons.search_off),
          label: Text('Perdu'),
        ),
        ButtonSegment(
          value: LostItemKind.found,
          icon: Icon(Icons.volunteer_activism_outlined),
          label: Text('Trouvé'),
        ),
      ],
      selected: {kind},
      showSelectedIcon: false,
      onSelectionChanged: onChanged == null ? null : (s) => onChanged(s.single),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: bg,
        selectedForegroundColor: fg,
        foregroundColor: scheme.onSurfaceVariant,
      ),
    );
  }
}

/// A label, a wrap of single-choice chips with icons, and an error.
class _ChoiceGroup<T> extends StatelessWidget {
  const _ChoiceGroup({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.iconOf,
    required this.onSelected,
    this.error,
  });

  final String label;
  final List<T> values;
  final T? selected;
  final String Function(T) labelOf;
  final IconData Function(T) iconOf;
  final ValueChanged<T>? onSelected;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSelected = this.onSelected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ForumFieldLabel(label),
        const SizedBox(height: AppSpacing.xs + 2),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final value in values)
              ChoiceChip(
                avatar: Icon(
                  iconOf(value),
                  size: 16,
                  color: value == selected ? scheme.onSecondaryContainer : scheme.primary,
                ),
                showCheckmark: false,
                label: Text(labelOf(value)),
                selected: value == selected,
                onSelected: onSelected == null ? null : (_) => onSelected(value),
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          ForumSheetError(error!),
        ],
      ],
    );
  }
}
