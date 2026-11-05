import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/entities/course_resource.dart';
import '../providers/course_providers.dart';
import '../utils/course_formatters.dart';

/// Bottom sheet to hand in a lab as a repository link. Returns the submitted
/// link, or null when dismissed.
Future<String?> showSubmitRepoSheet(
  BuildContext context, {
  required AssignmentResource lab,
  required DateTime now,
}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _SubmitRepoSheet(lab: lab, now: now),
    );

class _SubmitRepoSheet extends ConsumerStatefulWidget {
  const _SubmitRepoSheet({required this.lab, required this.now});

  final AssignmentResource lab;
  final DateTime now;

  @override
  ConsumerState<_SubmitRepoSheet> createState() => _SubmitRepoSheetState();
}

class _SubmitRepoSheetState extends ConsumerState<_SubmitRepoSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.lab.submittedRepoUrl ?? '');
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    final url = _controller.text.trim();
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await ref.read(courseRepositoryProvider).submitAssignment(widget.lab.id, url);
    if (!mounted) return;
    result.when(
      success: (_) => Navigator.of(context).pop(url),
      failure: (f) => setState(() {
        _submitting = false;
        _error = f.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lab = widget.lab;
    final status = lab.isSubmitted ? 'Submitted' : formatDueLabel(lab.dueAt, widget.now);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(lab.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${lab.description} • $status • ${lab.points} Pts',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _controller,
              label: 'Repository link',
              hint: 'https://github.com/you/your-repo',
              prefixIcon: Icons.link,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              validator: validateRepoUrl,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: lab.isSubmitted ? 'Resubmit' : 'Submit Repo',
              icon: Icons.upload_rounded,
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
