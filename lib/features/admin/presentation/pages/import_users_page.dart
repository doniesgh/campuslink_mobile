import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/result.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/bottom_action_bar.dart';
import '../../../../shared/widgets/detail_top_bar.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../domain/entities/user_import.dart';
import '../../domain/import_assist.dart';
import '../../domain/user_import_parser.dart';
import '../providers/admin_providers.dart';
import '../providers/import_file_picker.dart';
import '../widgets/admin_widgets.dart';

enum _Stage { pick, review, importing, done }

enum _Check { checking, checked, unchecked }

/// Administration › Import accounts: a CSV file (or cells pasted from a
/// spreadsheet) → a review of every line, checked by the server → the
/// accounts created in batches of [importBatchSize] → their sign-in details.
///
/// When the columns can't be found, or some roles or names can't be read,
/// "Read with AI" asks the server's AI how the file is laid out (when it has
/// one), rewrites the file as the template and reviews it again, with Undo.
class ImportUsersPage extends ConsumerStatefulWidget {
  const ImportUsersPage({super.key});

  @override
  ConsumerState<ImportUsersPage> createState() => _ImportUsersPageState();
}

class _ImportUsersPageState extends ConsumerState<ImportUsersPage> {
  /// Lines listed in the review (all of them are still imported).
  static const _maxListed = 200;

  final _paste = TextEditingController();
  final _pickScroll = ScrollController();
  _Stage _stage = _Stage.pick;
  bool _picking = false;
  String? _pickError;

  String _source = '';

  /// The lines of the file under review, as read (before any AI rewrite).
  List<ImportTableLine> _table = const [];
  ParsedImport _parsed = const ParsedImport();
  List<ImportProblem> _serverProblems = const [];
  _Check _check = _Check.unchecked;
  String? _checkError;

  /// Ignores the answer of a check started for a previous file.
  int _checkRun = 0;
  bool _skipProblems = false;
  bool _onlyProblems = false;

  int _sent = 0;
  int _total = 0;
  final _created = <ImportRow>[];
  final _refusedProblems = <ImportProblem>[];
  int _refusedCount = 0;
  String? _stopError;
  int _notSent = 0;
  bool _copied = false;

  /// A file whose columns weren't found: offered to the AI on the first step.
  ({String source, List<ImportTableLine> table})? _unread;

  /// What the AI understood, applied to [_table] (Undo goes back).
  ImportAssistAnswer? _assist;
  bool _assisting = false;
  String? _assistError;

  @override
  void dispose() {
    _paste.dispose();
    _pickScroll.dispose();
    super.dispose();
  }

  List<ImportProblem> get _problems => [..._parsed.problems, ..._serverProblems];

  Set<int> get _badRows => {for (final p in _problems) p.row};

  List<ImportRow> get _readyRows {
    final bad = _badRows;
    return [for (final r in _parsed.rows) if (!bad.contains(r.row)) r];
  }

  bool get _mustCopy => !_copied && _created.any((r) => r.passwordGenerated);

  // --- Pick ---------------------------------------------------------------

  /// Shows [message] at the top of the first step, scrolling back up to it:
  /// the admin is usually down at the buttons.
  void _showPickError(String message) {
    setState(() {
      _picking = false;
      _pickError = message;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pickScroll.hasClients) {
        _pickScroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _chooseFile() async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _pickError = null;
      _unread = null;
    });
    try {
      final file = await ref.read(importFilePickerProvider)();
      if (!mounted) return;
      setState(() => _picking = false);
      if (file != null) _read(file.name, file.text);
    } on ImportFileException catch (e) {
      if (mounted) _showPickError(e.message);
    } catch (_) {
      if (mounted) _showPickError("This file can't be read. Choose a CSV file.");
    }
  }

  void _readPasted() {
    FocusScope.of(context).unfocus();
    _unread = null;
    if (_paste.text.trim().isEmpty) {
      _showPickError('Paste the cells first, title line included.');
      return;
    }
    _read('Pasted cells', _paste.text);
  }

  static String _notUsable(ParsedImport parsed) =>
      parsed.error ??
      'Columns not found: ${parsed.missingColumns.join(', ')}. '
          'Put the column titles on the first line.';

  void _read(String source, String text) {
    final table = readImportTable(text);
    final parsed = parseImportTable(table);
    _assist = null;
    _assistError = null;
    if (!parsed.isUsable) {
      // The AI may find columns with unknown titles (not in a file without accounts).
      _unread = parsed.missingColumns.isEmpty ? null : (source: source, table: table);
      _showPickError(_notUsable(parsed));
      return;
    }
    _table = table;
    _unread = null;
    _review(source, parsed);
  }

  void _review(String source, ParsedImport parsed) {
    setState(() {
      _source = source;
      _parsed = parsed;
      _serverProblems = const [];
      _skipProblems = false;
      _onlyProblems = false;
      _pickError = null;
      _stage = _Stage.review;
    });
    _checkWithServer();
  }

  /// Dry run of the lines that passed the app's own checks: adds the
  /// server's problems (an account already uses this email...).
  Future<void> _checkWithServer() async {
    final bad = {for (final p in _parsed.problems) p.row};
    final rows = [for (final r in _parsed.rows) if (!bad.contains(r.row)) r];
    if (rows.isEmpty) {
      setState(() => _check = _Check.checked);
      return;
    }
    final run = ++_checkRun;
    setState(() {
      _check = _Check.checking;
      _checkError = null;
    });
    final result = await ref.read(adminRepositoryProvider).checkImport(rows);
    if (!mounted || run != _checkRun) return;
    setState(() {
      result.when(
        success: (check) {
          _serverProblems = check.problems;
          _check = _Check.checked;
        },
        failure: (f) {
          _check = _Check.unchecked;
          _checkError = f.message;
        },
      );
    });
  }

  // --- Read with AI -------------------------------------------------------

  /// Asks the AI how [table] is laid out, then reviews it rewritten as the
  /// template. Nothing is imported: the admin checks the lines as usual.
  Future<void> _readWithAi(String source, List<ImportTableLine> table) async {
    if (_assisting) return;
    setState(() {
      _assisting = true;
      _assistError = null;
    });
    final result = await ref.read(adminRepositoryProvider).assistImport(assistRequest(table));
    if (!mounted) return;
    switch (result) {
      case Err(:final failure):
        setState(() {
          _assisting = false;
          _assistError = failure.message;
        });
      case Success(value: final answer):
        final parsed = parseImportTable(applyAssist(table, answer.mapping));
        if (!parsed.isUsable) {
          setState(() {
            _assisting = false;
            _assistError = "The AI couldn't read this file either: ${_notUsable(parsed)} "
                'Template: $importTemplateHeader';
          });
          return;
        }
        _assisting = false;
        _table = table;
        _assist = answer;
        _unread = null;
        _review(source, parsed);
    }
  }

  /// Back to the file as it was read, before the AI.
  void _undoAssist() {
    final parsed = parseImportTable(_table);
    _assist = null;
    _assistError = null;
    if (parsed.isUsable) {
      _review(_source, parsed);
      return;
    }
    // The AI had read a file the app couldn't: back to the first step.
    _checkRun++;
    setState(() {
      _unread = (source: _source, table: _table);
      _stage = _Stage.pick;
      _parsed = const ParsedImport();
      _serverProblems = const [];
      _check = _Check.unchecked;
      _pickError = _notUsable(parsed);
    });
  }

  /// Some roles or names can't be read: the AI may know what they mean.
  bool get _canFixWithAi =>
      _assist == null &&
      _parsed.problems.any(
        (p) => p.code == 'INVALID_ROLE' || (p.field == 'displayName' && p.code == 'REQUIRED'),
      );

  /// The "Read with AI" card, only when the server has an AI.
  Widget _assistOffer({
    required String message,
    required String action,
    required VoidCallback onPressed,
  }) {
    final status = ref.watch(importAssistStatusProvider).valueOrNull;
    if (status == null || !status.available) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: _AssistOffer(
        message: message,
        action: action,
        model: status.model,
        busy: _assisting,
        error: _assistError,
        onPressed: onPressed,
      ),
    );
  }

  void _restart() {
    _checkRun++;
    setState(() {
      _assist = null;
      _assistError = null;
      _stage = _Stage.pick;
      _parsed = const ParsedImport();
      _serverProblems = const [];
      _check = _Check.unchecked;
    });
  }

  // --- Import -------------------------------------------------------------

  Future<void> _import() async {
    final rows = _readyRows;
    if (rows.isEmpty) return;
    setState(() {
      _stage = _Stage.importing;
      _total = rows.length;
      _sent = 0;
      _created.clear();
      _refusedProblems.clear();
      _refusedCount = 0;
      _stopError = null;
      _notSent = 0;
      _copied = false;
    });
    final repo = ref.read(adminRepositoryProvider);

    for (var start = 0; start < rows.length; start += importBatchSize) {
      final batch = rows.sublist(start, (start + importBatchSize).clamp(0, rows.length));
      final result = await repo.importUsers(batch);
      if (!mounted) return;
      switch (result) {
        case Success(value: ImportCreated()):
          _created.addAll(batch);
        case Success(value: ImportRefused(:final problems)):
          _refusedProblems.addAll(problems);
          _refusedCount += batch.length;
        case Err(:final failure):
          _stopError = failure.message;
          _notSent = rows.length - start;
      }
      setState(() => _sent = start + batch.length);
      if (_stopError != null) break;
    }
    refreshAdminData(ref);
    setState(() => _stage = _Stage.done);
  }

  Future<void> _copyDetails() async {
    await Clipboard.setData(ClipboardData(text: signInDetails(_created)));
    if (!mounted) return;
    setState(() => _copied = true);
    showAppSnack(context, 'Sign-in details copied: paste them into a spreadsheet.');
  }

  /// Leaves the screen, warning first when generated passwords would be lost.
  Future<void> _leave() async {
    if (_stage == _Stage.importing) {
      showAppSnack(context, 'Wait for the import to finish.');
      return;
    }
    if (_stage == _Stage.done && _mustCopy) {
      final leave = await confirmDestructive(
        context,
        title: 'Leave without the passwords?',
        message: "You haven't copied the sign-in details: the generated passwords will be lost.",
        confirmLabel: 'Leave anyway',
      );
      if (!leave || !mounted) return;
    }
    context.canPop() ? context.pop() : context.go(RoutePaths.adminUsers);
  }

  // --- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Asked once on opening, so "Read with AI" shows at once when needed.
    ref.watch(importAssistStatusProvider);
    final blockPop = _stage == _Stage.importing || (_stage == _Stage.done && _mustCopy);
    return PopScope(
      canPop: !blockPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: switch (_stage) {
                  _Stage.pick => _pickView(),
                  _Stage.review => _reviewView(),
                  _Stage.importing => _importingView(),
                  _Stage.done => _doneView(),
                },
              ),
              if (_stage == _Stage.review) _reviewBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.lg),
        child: DetailTopBar(
          backLabel: 'Users',
          fallbackPath: RoutePaths.adminUsers,
          trailing: [
            Flexible(
              child: AppBadge('Import', tone: BadgeTone.neutral, icon: Icons.upload_file),
            ),
          ],
        ),
      );

  Widget _pickView() {
    final theme = Theme.of(context);
    final pickError = _pickError;
    return ListView(
      controller: _pickScroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xl,
      ),
      children: [
        _topBar(),
        const AdminTitle(
          title: 'Import accounts',
          subtitle: 'Create up to $maxImportLines accounts at once from a spreadsheet. '
              'Nothing is created before you check the lines.',
        ),
        const SizedBox(height: AppSpacing.xl),
        if (pickError != null) ...[
          _ErrorNote(pickError),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (_unread case final unread?)
          _assistOffer(
            message: "This file doesn't follow the template. "
                'The AI can work out which column is which.',
            action: 'Read with AI',
            onPressed: () => _readWithAi(unread.source, unread.table),
          ),
        _Section(
          icon: Icons.upload_file_outlined,
          title: 'From a CSV file',
          subtitle: 'From Excel: File › Save as › CSV UTF-8.',
          child: AppButton(
            label: 'Choose a CSV file',
            icon: Icons.folder_open_outlined,
            variant: AppButtonVariant.outlined,
            isLoading: _picking,
            onPressed: _chooseFile,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Section(
          icon: Icons.content_paste_outlined,
          title: 'Or paste the cells',
          subtitle: 'Copy the cells in Excel or Google Sheets, title line included.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _paste,
                minLines: 4,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                decoration: const InputDecoration(hintText: importTemplateHeader),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(label: 'Read the rows', icon: Icons.fact_check_outlined, onPressed: _readPasted),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const InfoBanner(
          icon: Icons.table_chart_outlined,
          title: 'Columns',
          message: 'Required: Name (or First name and Last name) and Email. '
              'Optional: ENT ID, Role and Password.\n'
              'Role: Student when empty (Teacher, Admin and Alumni work too). '
              'Password: at least 8 characters; when empty, one is generated.\n'
              'French titles work too: Nom, Prénom, Courriel, Rôle, Mot de passe.',
        ),
      ],
    );
  }

  Widget _reviewView() {
    final theme = Theme.of(context);
    final problemsByRow = <int, List<ImportProblem>>{};
    for (final p in _problems) {
      (problemsByRow[p.row] ??= []).add(p);
    }
    final total = _parsed.rows.length;
    final bad = problemsByRow.length;
    final ready = total - bad;
    final generated = _readyRows.where((r) => r.passwordGenerated).length;
    final lines = _onlyProblems
        ? _parsed.rows.where((r) => problemsByRow.containsKey(r.row)).toList()
        : _parsed.rows;
    final listed = lines.take(_maxListed).toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xl,
      ),
      itemCount: listed.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(),
              AdminTitle(title: 'Check the lines', subtitle: _source),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppBadge(total == 1 ? '1 line' : '$total lines', tone: BadgeTone.neutral),
                  AppBadge('$ready ready', tone: BadgeTone.success, icon: Icons.check_circle_outline),
                  if (bad > 0)
                    AppBadge('$bad to fix', tone: BadgeTone.accent, icon: Icons.error_outline),
                  if (generated > 0)
                    AppBadge(
                      generated == 1 ? '1 password generated' : '$generated passwords generated',
                      tone: BadgeTone.primary,
                      icon: Icons.key_outlined,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (_assist case final assist?) ...[
                _AssistSummary(answer: assist, table: _table, onUndo: _undoAssist),
                const SizedBox(height: AppSpacing.md),
              ] else if (_canFixWithAi)
                _assistOffer(
                  message: "Some roles or names can't be read. "
                      'The AI can work out what they mean.',
                  action: 'Fix with AI',
                  onPressed: () => _readWithAi(_source, _table),
                ),
              _CheckStatus(check: _check, error: _checkError, onRetry: _checkWithServer),
              if (bad > 0) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Fix these lines in the file and choose it again, or leave them out.',
                  style: theme.textTheme.bodyMedium,
                ),
                CheckboxListTile(
                  value: _skipProblems,
                  onChanged: ready == 0 ? null : (v) => setState(() => _skipProblems = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'Import the $ready correct accounts and leave out the $bad lines to fix',
                  ),
                ),
                CheckboxListTile(
                  value: _onlyProblems,
                  onChanged: (v) => setState(() => _onlyProblems = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Show only the lines to fix'),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
            ],
          );
        }
        if (i == listed.length + 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (lines.length > listed.length)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    'And ${lines.length - listed.length} more lines.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Choose another file',
                icon: Icons.refresh,
                variant: AppButtonVariant.outlined,
                onPressed: _restart,
              ),
            ],
          );
        }
        final row = listed[i - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _ImportLine(row: row, problems: problemsByRow[row.row] ?? const []),
        );
      },
    );
  }

  Widget _reviewBar() {
    final theme = Theme.of(context);
    final ready = _readyRows.length;
    final bad = _badRows.length;
    final canImport =
        ready > 0 && (bad == 0 || _skipProblems) && _check != _Check.checking;
    return BottomActionBar(
      leading: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'READY',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          Text(ready == 1 ? '1 account' : '$ready accounts', style: theme.textTheme.titleMedium),
        ],
      ),
      action: AppButton(
        label: 'Import',
        icon: Icons.group_add_outlined,
        onPressed: canImport ? _import : null,
      ),
    );
  }

  Widget _importingView() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_add_outlined, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.lg),
            Text('Importing… $_sent of $_total', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            LinearProgressIndicator(value: _total == 0 ? null : _sent / _total),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Keep this screen open until the end.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _doneView() {
    final theme = Theme.of(context);
    final created = _created.length;
    final stopError = _stopError;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xl,
      ),
      children: [
        Icon(
          created > 0 ? Icons.task_alt : Icons.error_outline,
          size: 56,
          color: created > 0 ? theme.colorScheme.primary : theme.colorScheme.error,
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Import finished', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          created == 1 ? '1 account created.' : '$created accounts created.',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        if (_refusedCount > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          _ErrorNote(
            '$_refusedCount accounts weren\'t created: the server refused their batch.\n'
            '${_refusedProblems.take(3).map((p) => 'Line ${p.row}: ${p.message}').join('\n')}'
            '${_refusedProblems.length > 3 ? '\n… and ${_refusedProblems.length - 3} more problems.' : ''}',
          ),
        ],
        if (stopError != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _ErrorNote('$_notSent accounts weren\'t sent: $stopError'),
        ],
        if (created > 0) ...[
          const SizedBox(height: AppSpacing.xl),
          InfoBanner(
            icon: Icons.key_outlined,
            tone: _mustCopy ? BadgeTone.accent : BadgeTone.primary,
            title: 'Sign-in details',
            message: _created.any((r) => r.passwordGenerated)
                ? "Copy them now and pass them on: the generated passwords won't be shown again."
                : 'Name, email, ENT ID, role and password of each new account, for a spreadsheet.',
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: _copied ? 'Copied' : 'Copy the sign-in details',
            icon: _copied ? Icons.check : Icons.copy,
            variant: AppButtonVariant.outlined,
            onPressed: _copyDetails,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppButton(label: 'Done', onPressed: _leave),
      ],
    );
  }
}

/// A card with an icon, a title, a hint and its content.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.error),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// The tinted box of the AI cards.
BoxDecoration _assistDecoration(ColorScheme scheme) => BoxDecoration(
      color: scheme.primaryContainer.withValues(alpha: 0.35),
      borderRadius: AppRadius.lgAll,
      border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
    );

/// "Read with AI": offered when a file doesn't follow the template, or some
/// of its values can't be read. Says what is sent, and why it failed.
class _AssistOffer extends StatelessWidget {
  const _AssistOffer({
    required this.message,
    required this.action,
    required this.model,
    required this.busy,
    required this.error,
    required this.onPressed,
  });

  final String message;
  final String action;
  final String? model;
  final bool busy;
  final String? error;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final error = this.error;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _assistDecoration(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_outlined, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(message, style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The first $assistLines lines (emails and passwords masked) and the short lists '
            'of values, such as roles, are sent to ${model ?? 'an AI model'} through OpenRouter. '
            'Nothing is imported before you check the lines.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 18, color: scheme.error),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    error,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: action,
            icon: Icons.auto_awesome_outlined,
            variant: AppButtonVariant.outlined,
            isLoading: busy,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

/// What the AI understood, now applied to the file, with Undo.
class _AssistSummary extends StatelessWidget {
  const _AssistSummary({required this.answer, required this.table, required this.onUndo});

  final ImportAssistAnswer answer;
  final List<ImportTableLine> table;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mapping = answer.mapping;
    final header = mapping.headerRow;
    final columns = [
      for (final field in AssistField.values)
        if (mapping.columns[field] case final column?)
          field == AssistField.fullName
              ? '${field.label} ${columnLetter(column)} (${mapping.nameOrder.label})'
              : '${field.label} ${columnLetter(column)}',
    ];
    // A value the AI left out may still be read by the usual rules.
    final understood = <String>[];
    final unknown = <String>[];
    for (final (:text, :role) in mapping.roles) {
      final read = role ?? roleFromCell(text);
      if (read == null) {
        unknown.add('“$text”');
      } else {
        understood.add('“$text” → ${read.label}');
      }
    }
    final points = [
      header > 0 && header <= table.length
          ? 'Titles on line ${table[header - 1].line}.'
          : 'No title line in the file.',
      if (columns.isNotEmpty) 'Columns: ${columns.join(' · ')}.',
      if (understood.isNotEmpty) 'Roles: ${understood.join(', ')}.',
      if (unknown.isNotEmpty) 'Not understood: ${unknown.join(', ')}.',
      if (mapping.columns.containsKey(AssistField.fullName)) 'Check how the full names were split.',
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.lg,
      ),
      decoration: _assistDecoration(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Read with AI', style: theme.textTheme.titleSmall)),
              TextButton.icon(
                onPressed: onUndo,
                icon: const Icon(Icons.undo, size: 18),
                label: const Text('Undo'),
              ),
            ],
          ),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs, right: AppSpacing.sm),
              child: Text('• $point', style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Model: ${answer.model}',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// "Checking with the server…" / "Checked with the server." / why it couldn't.
class _CheckStatus extends StatelessWidget {
  const _CheckStatus({required this.check, required this.error, required this.onRetry});

  final _Check check;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final (Widget icon, String text) = switch (check) {
      _Check.checking => (
          const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          'Checking with the server…',
        ),
      _Check.checked => (
          Icon(Icons.verified_outlined, size: 18, color: theme.colorScheme.primary),
          'Checked with the server.',
        ),
      _Check.unchecked => (
          Icon(Icons.cloud_off_outlined, size: 18, color: muted),
          "Checked on this device only (${error ?? 'no answer'}). "
              'The server checks again during the import.',
        ),
    };
    return Row(
      children: [
        icon,
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: muted))),
        if (check == _Check.unchecked)
          TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

/// One line of the file: who it creates, and its problems in red.
class _ImportLine extends StatelessWidget {
  const _ImportLine({required this.row, required this.problems});

  final ImportRow row;
  final List<ImportProblem> problems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ok = problems.isEmpty;
    final details = [
      if (row.email.isNotEmpty) row.email,
      row.role?.label ?? 'Unknown role',
      if (row.studentId != null) row.studentId!,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: ok ? scheme.outlineVariant.withValues(alpha: 0.5) : scheme.error.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Line ${row.row} · ${row.displayName.isEmpty ? '(no name)' : row.displayName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ok
                  ? const AppBadge('Ready', tone: BadgeTone.success)
                  : const AppBadge('To fix', tone: BadgeTone.accent),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            details,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          for (final p in problems)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(p.message, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
            ),
        ],
      ),
    );
  }
}
