import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/class_session.dart';
import '../../domain/entities/timetable_slot.dart';
import '../../domain/timetable_slot_rules.dart';
import '../providers/timetable_admin_providers.dart';

/// Add or edit a class of the weekly timetable. Pops with the saved class.
/// Checks the server's rules before sending; clashes with other classes
/// (same room or teacher at overlapping times) are listed above the button.
class SlotFormPage extends ConsumerStatefulWidget {
  const SlotFormPage({super.key, this.slot});

  /// Null to add a class.
  final TimetableSlot? slot;

  @override
  ConsumerState<SlotFormPage> createState() => _SlotFormPageState();
}

final _hm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

const _kindLabels = {
  SessionKind.lecture: 'Lecture',
  SessionKind.lab: 'Lab',
  SessionKind.workshop: 'Workshop',
  SessionKind.exam: 'Exam',
};

class _SlotFormPageState extends ConsumerState<SlotFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TimetableSlot? _slot = widget.slot;
  late int _weekday = _slot?.weekday ?? DateTime.monday;
  late SessionKind _kind = _slot?.kind ?? SessionKind.lecture;
  late bool _online = _slot?.isOnline ?? false;
  late final _start = TextEditingController(text: _slot?.start ?? '08:30');
  late final _end = TextEditingController(text: _slot?.end ?? '10:00');
  late final _course = TextEditingController(text: _slot?.course);
  late final _teacher = TextEditingController(text: _slot?.teacher);
  late final _room = TextEditingController(text: _slot?.room);
  late final _meetUrl = TextEditingController(text: _slot?.meetUrl);
  late final _notes = TextEditingController(text: _slot?.notes);
  late final _coefficient = TextEditingController(text: _slot?.coefficient?.toString());

  bool _saving = false;
  SlotClash? _clash;
  String? _error;

  bool get _isNew => _slot == null;

  @override
  void dispose() {
    for (final c in [_start, _end, _course, _teacher, _room, _meetUrl, _notes, _coefficient]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _timeError(String? value) =>
      _hm.hasMatch(value?.trim() ?? '') ? null : 'Enter the time as HH:mm';

  String? _endError(String? value) {
    final own = _timeError(value);
    if (own != null) return own;
    if (!_hm.hasMatch(_start.text.trim())) return null;
    return validateTimes(_start.text.trim(), value!.trim());
  }

  String? _coefficientError(String? value) {
    final v = value?.trim().replaceAll(',', '.') ?? '';
    if (v.isEmpty) return null;
    final n = double.tryParse(v);
    return n == null ? SlotMessages.coefficient : validateCoefficient(n);
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final current = _hm.hasMatch(controller.text.trim())
        ? hmToMinutes(controller.text.trim())
        : 8 * 60 + 30;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => controller.text = minutesToHm(picked.hour * 60 + picked.minute));
  }

  SlotDraft _draft() {
    String? optional(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    return SlotDraft(
      weekday: _weekday,
      start: _start.text.trim(),
      end: _end.text.trim(),
      course: _course.text.trim(),
      teacher: _teacher.text.trim(),
      room: _room.text.trim(),
      kind: _kind,
      mode: _online ? SessionMode.online : SessionMode.onsite,
      meetUrl: _online ? optional(_meetUrl) : null,
      notes: optional(_notes),
      coefficient: _kind == SessionKind.exam
          ? double.tryParse(_coefficient.text.trim().replaceAll(',', '.'))
          : null,
    );
  }

  Future<void> _save() async {
    setState(() {
      _clash = null;
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final draft = _draft();
    final problem = validateSlotDraft(draft);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(timetableAdminRepositoryProvider);
    final slot = _slot;
    final result = slot == null ? await repo.createSlot(draft) : await repo.updateSlot(slot.id, draft);
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Success(value: SlotSaved(:final slot)):
        Navigator.of(context).pop(slot);
      case Success(value: final SlotClash clash):
        setState(() => _clash = clash);
      case Err(:final failure):
        setState(() => _error = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const gap = SizedBox(height: AppSpacing.lg);
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'Add a class' : 'Edit the class')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              DropdownButtonFormField<int>(
                key: const Key('slot-weekday'),
                initialValue: _weekday,
                decoration: const InputDecoration(labelText: 'Day'),
                items: [
                  for (var d = 1; d <= 7; d++)
                    DropdownMenuItem(value: d, child: Text(weekdayName(d))),
                ],
                onChanged: (d) => setState(() => _weekday = d ?? _weekday),
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _timeField('Start', _start, _timeError)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: _timeField('End', _end, _endError)),
                ],
              ),
              gap,
              _textField('Course', _course, validateCourse),
              gap,
              _textField('Teacher', _teacher, validateTeacher),
              gap,
              Text('Kind', style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final kind in _kindLabels.keys)
                    ChoiceChip(
                      label: Text(_kindLabels[kind]!),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
                ],
              ),
              gap,
              SwitchListTile(
                key: const Key('slot-online'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Online class'),
                subtitle: const Text('Students join with a Google Meet link'),
                value: _online,
                onChanged: (v) => setState(() => _online = v),
              ),
              if (_online) ...[
                const SizedBox(height: AppSpacing.sm),
                _textField(
                  'Google Meet link',
                  _meetUrl,
                  (v) => validateMeetUrl(v, online: true),
                  hint: 'https://meet.google.com/abc-defg-hij',
                  keyboardType: TextInputType.url,
                ),
              ],
              gap,
              _textField(
                _online ? 'Room (optional)' : 'Room',
                _room,
                (v) => validateRoom(v, online: _online),
              ),
              if (_kind == SessionKind.exam) ...[
                gap,
                _textField(
                  'Coefficient (optional)',
                  _coefficient,
                  _coefficientError,
                  hint: '2',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
              gap,
              _textField('Notes (optional)', _notes, validateNotes, maxLines: 3),
              if (_clash != null) ...[gap, _ConflictPanel(clash: _clash!)],
              if (_error != null) ...[
                gap,
                Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _isNew ? 'Add the class' : 'Save changes',
                icon: Icons.check,
                isLoading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeField(
    String label,
    TextEditingController controller,
    String? Function(String?) validator,
  ) =>
      TextFormField(
        key: Key('slot-${label.toLowerCase()}'),
        controller: controller,
        validator: validator,
        keyboardType: TextInputType.datetime,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'HH:mm',
          suffixIcon: IconButton(
            tooltip: 'Pick the ${label.toLowerCase()} time',
            icon: const Icon(Icons.schedule),
            onPressed: () => _pickTime(controller),
          ),
        ),
      );

  Widget _textField(
    String label,
    TextEditingController controller,
    String? Function(String) validator, {
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) =>
      TextFormField(
        key: Key('slot-${label.split(' ').first.toLowerCase()}'),
        controller: controller,
        validator: (v) => validator(v ?? ''),
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, hintText: hint),
      );
}

/// "This class clashes with..." and one line per clashing class.
class _ConflictPanel extends StatelessWidget {
  const _ConflictPanel({required this.clash});

  final SlotClash clash;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: const Key('slot-conflicts'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_busy_outlined, color: scheme.error),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(clash.message, style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final c in clash.conflicts)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                '${c.reason == ConflictReason.room ? 'Same room' : 'Same teacher'}: '
                '${c.slot.course}, ${weekdayName(c.slot.weekday)} ${c.slot.start}–${c.slot.end}'
                ' (${c.reason == ConflictReason.room ? c.slot.room : c.slot.teacher})',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Change the day, the time, the room or the teacher, then save again.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
