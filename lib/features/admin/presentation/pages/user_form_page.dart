import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/bottom_action_bar.dart';
import '../../../../shared/widgets/detail_top_bar.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/entities/managed_user.dart';
import '../../domain/user_import_parser.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/sign_in_details_dialog.dart';

/// Rules shared with the server (backend/src/modules/admin/admin.schemas.ts).
abstract final class UserFormRules {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _studentId = RegExp(r'^[A-Za-z0-9]{3,20}$');

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter the name';
    return v.length > 80 ? 'Name is too long (at most 80 characters)' : null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter the email';
    return _email.hasMatch(v) ? null : 'Enter a valid email';
  }

  /// Optional.
  static String? studentId(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    return _studentId.hasMatch(v) ? null : 'Use 3 to 20 letters or digits';
  }

  /// Required for a new account; empty keeps the current one when editing.
  static String? password(String? value, {required bool required}) {
    final v = value ?? '';
    if (v.isEmpty) return required ? 'Choose a password' : null;
    if (v.length < 8) return 'Use at least 8 characters';
    return v.length > 128 ? 'Use at most 128 characters' : null;
  }
}

/// Administration › Add user / Edit user. [userId] null creates an account.
///
/// On the admin's own account only the name, email and ENT ID can change
/// (the server refuses the rest), so an admin can't lock themselves out.
class UserFormPage extends ConsumerWidget {
  const UserFormPage({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = userId;
    if (id == null) return const _UserForm(user: null);

    final async = ref.watch(managedUserProvider(id));
    return async.when(
      // Keeps the form (and what was typed) while the account reloads.
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const _Frame(child: LoadingView()),
      error: (e, _) => _Frame(
        child: ErrorView(
          message: failureMessage(e),
          onRetry: () => ref.invalidate(managedUserProvider(id)),
        ),
      ),
      data: (user) => _UserForm(key: ValueKey(user.id), user: user),
    );
  }
}

/// Top bar + content, while the account loads or failed to.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.page, AppSpacing.md, AppSpacing.page, 0,
                ),
                child: DetailTopBar(backLabel: 'Users', fallbackPath: RoutePaths.adminUsers),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      );
}

class _UserForm extends ConsumerStatefulWidget {
  const _UserForm({super.key, required this.user});

  /// Null for a new account.
  final ManagedUser? user;

  @override
  ConsumerState<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends ConsumerState<_UserForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.displayName);
  late final _email = TextEditingController(text: widget.user?.email);
  late final _studentId = TextEditingController(text: widget.user?.studentId);
  final _password = TextEditingController();
  late UserRole _role = widget.user?.role ?? UserRole.student;
  late bool _verified = widget.user?.isEmailVerified ?? true;

  bool _submitted = false;
  bool _saving = false;
  bool _deleting = false;

  bool get _isNew => widget.user == null;

  /// Editing the signed-in admin's own account (never true for a new one).
  bool _isOwn(String? currentUserId) {
    final user = widget.user;
    return user != null && currentUserId != null && user.id == currentUserId;
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _studentId, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  void _generatePassword() {
    setState(() => _password.text = generatePassword(Random.secure()));
    showAppSnack(context, 'Password generated. You will see it after saving.');
  }

  /// Back to the list, with a message for the admin.
  void _leave(String message) {
    showAppSnack(context, message);
    context.canPop() ? context.pop() : context.go(RoutePaths.adminUsers);
  }

  Future<void> _save() async {
    if (_saving || _deleting) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(adminRepositoryProvider);
    final password = _password.text;
    final before = widget.user;

    if (before == null) {
      setState(() => _saving = true);
      final result = await repo.createUser(NewUser(
        displayName: _name.text,
        email: _email.text,
        password: password,
        role: _role,
        studentId: _studentId.text,
      ));
      if (!mounted) return;
      setState(() => _saving = false);
      switch (result.dataOrNull) {
        case final created?:
          refreshAdminData(ref);
          await showSignInDetailsDialog(
            context,
            title: 'Account created',
            name: created.displayName,
            email: created.email,
            studentId: created.studentId,
            password: password,
          );
          if (mounted) _leave('${created.displayName} has been added.');
        case null:
          result.when(success: (_) {}, failure: (f) => showAppSnack(context, f.message));
      }
      return;
    }

    final changes = UserChanges.between(
      before,
      displayName: _name.text,
      email: _email.text,
      studentId: _studentId.text,
      role: _role,
      password: password,
      isEmailVerified: _verified,
    );
    if (changes.isEmpty) {
      showAppSnack(context, "There's nothing to save.");
      return;
    }
    setState(() => _saving = true);
    final result = await repo.updateUser(before.id, changes);
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result.dataOrNull) {
      case final updated?:
        refreshAdminData(ref, userId: updated.id);
        if (_isOwn(ref.read(currentUserIdProvider))) {
          ref
              .read(authControllerProvider.notifier)
              .updateOwnAccount(displayName: updated.displayName, email: updated.email);
        }
        if (changes.password != null) {
          await showSignInDetailsDialog(
            context,
            title: 'New password',
            name: updated.displayName,
            email: updated.email,
            studentId: updated.studentId,
            password: password,
          );
        }
        if (mounted) _leave('${updated.displayName} has been updated.');
      case null:
        result.when(success: (_) {}, failure: (f) => showAppSnack(context, f.message));
    }
  }

  Future<void> _delete() async {
    final user = widget.user;
    if (user == null || _saving || _deleting) return;
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete ${user.displayName}?',
      message: "This account and its sessions will be removed. This can't be undone.",
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    final result = await ref.read(adminRepositoryProvider).deleteUser(user.id);
    if (!mounted) return;
    setState(() => _deleting = false);
    result.when(
      success: (_) {
        refreshAdminData(ref);
        _leave('${user.displayName} has been deleted.');
      },
      failure: (f) => showAppSnack(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final user = widget.user;
    final own = _isOwn(ref.watch(currentUserIdProvider));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                autovalidateMode:
                    _submitted ? AutovalidateMode.always : AutovalidateMode.disabled,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DetailTopBar(
                        backLabel: 'Users',
                        fallbackPath: RoutePaths.adminUsers,
                        trailing: [if (user != null) Flexible(child: RoleBadge(user.role))],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AdminTitle(
                        title: user == null ? 'Add user' : 'Edit ${user.displayName}',
                        subtitle: user == null
                            ? 'The account is ready at once: no verification email is sent.'
                            : 'Changes apply at once. A new password signs the user out everywhere.',
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppTextField(
                        controller: _name,
                        label: 'Name',
                        hint: 'Sarra Mansouri',
                        prefixIcon: Icons.person_outline,
                        validator: UserFormRules.name,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _email,
                        label: 'Email',
                        hint: 'sarra.mansouri@campus.test',
                        prefixIcon: Icons.alternate_email,
                        keyboardType: TextInputType.emailAddress,
                        validator: UserFormRules.email,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _studentId,
                        label: 'ENT ID (optional)',
                        hint: '221JMT0101',
                        prefixIcon: Icons.badge_outlined,
                        validator: UserFormRules.studentId,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (own)
                        const InfoBanner(
                          icon: Icons.shield_outlined,
                          title: 'This is your account',
                          message: 'You can change your name, email and ENT ID here. '
                              'Your role and password can only be changed by another admin, '
                              'so you can never lock yourself out.',
                        )
                      else ...[
                        _RolePicker(
                          selected: _role,
                          onChanged: (role) => setState(() => _role = role),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        AppTextField(
                          controller: _password,
                          label: _isNew ? 'Password' : 'New password (optional)',
                          hint: _isNew
                              ? 'At least 8 characters'
                              : 'Leave empty to keep the current password',
                          prefixIcon: Icons.lock_outline,
                          isPassword: true,
                          validator: (v) => UserFormRules.password(v, required: _isNew),
                          labelTrailing: TextButton(
                            onPressed: _generatePassword,
                            child: const Text('Generate'),
                          ),
                        ),
                        if (!_isNew) ...[
                          const SizedBox(height: AppSpacing.md),
                          _VerifiedSwitch(
                            value: _verified,
                            onChanged: (v) => setState(() => _verified = v),
                          ),
                        ],
                      ],
                      if (user != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Account created on ${_date(user.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ],
                      if (user != null && !own) ...[
                        const SizedBox(height: AppSpacing.xl),
                        OutlinedButton.icon(
                          onPressed: _deleting ? null : _delete,
                          icon: _deleting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.person_remove_outlined),
                          label: const Text('Delete this account'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            BottomActionBar(
              leading: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isNew ? 'NEW ACCOUNT' : 'ROLE',
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                  Text(
                    _role.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              action: AppButton(
                label: _isNew ? 'Create' : 'Save',
                icon: Icons.check_rounded,
                isLoading: _saving,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// The roles as selectable cards, two per row (the last one alone takes the
/// whole row).
class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.selected, required this.onChanged});

  final UserRole selected;
  final ValueChanged<UserRole> onChanged;

  static String _hint(UserRole role) => switch (role) {
        UserRole.student => 'Timetable, courses, grades',
        UserRole.teacher => 'Teaching staff',
        UserRole.admin => 'Manages every account',
        UserRole.alumni => 'Former student',
        UserRole.company => 'Recruiter / partner company',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Role',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final half = (constraints.maxWidth - AppSpacing.sm) / 2;
            const roles = UserRole.values;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (i, role) in roles.indexed)
                  SizedBox(
                    width: roles.length.isOdd && i == roles.length - 1
                        ? constraints.maxWidth
                        : half,
                    child: _RoleOption(
                      role: role,
                      hint: _hint(role),
                      selected: role == selected,
                      onTap: () => onChanged(role),
                    ),
                  ),
              ],
            );
          },
        ),
        if (selected == UserRole.admin) ...[
          const SizedBox(height: AppSpacing.sm),
          const InfoBanner(
            icon: Icons.admin_panel_settings_outlined,
            tone: BadgeTone.accent,
            message: 'Admins can create, change and delete every account, '
                'including other admins.',
          ),
        ],
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? scheme.primaryContainer.withValues(alpha: 0.6) : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(roleIcon(role), color: selected ? scheme.primary : scheme.onSurfaceVariant),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  role.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: selected ? scheme.primary : null,
                  ),
                ),
                Text(
                  hint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerifiedSwitch extends StatelessWidget {
  const _VerifiedSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A Material, not a coloured box: the tile paints its ink on it.
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: AppRadius.lgAll,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: const Text('Email verified'),
        subtitle: const Text('Unverified accounts must enter the emailed code before using the app.'),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
    );
  }
}
