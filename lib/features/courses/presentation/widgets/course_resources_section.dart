import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/course_resource.dart';
import '../utils/course_formatters.dart';

enum ResourceDownloadState { idle, downloading, done }

/// "Course Resources [3 files]  Select all" + one card per handout.
class CourseResourcesSection extends StatelessWidget {
  const CourseResourcesSection({
    super.key,
    required this.resources,
    required this.now,
    required this.downloads,
    required this.onDownload,
    required this.onStream,
    required this.onSubmit,
    required this.onSelectAll,
  });

  final List<CourseResource> resources;
  final DateTime now;

  /// Download state per document id (missing = idle).
  final Map<String, ResourceDownloadState> downloads;
  final ValueChanged<DocumentResource> onDownload;
  final ValueChanged<VideoResource> onStream;
  final ValueChanged<AssignmentResource> onSubmit;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Course Resources',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppBadge(filesCountLabel(resources.length), tone: BadgeTone.neutral),
                ],
              ),
            ),
            if (resources.isNotEmpty)
              Flexible(
                child: TextButton(
                  onPressed: onSelectAll,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    textStyle:
                        theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Select all', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (resources.isEmpty)
          AppCard(
            child: Text(
              'No resources shared for this course yet.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        for (final r in resources)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: switch (r) {
              DocumentResource() => _DocumentTile(
                  doc: r,
                  state: downloads[r.id] ?? ResourceDownloadState.idle,
                  onDownload: () => onDownload(r),
                ),
              VideoResource() => _VideoTile(video: r, onStream: () => onStream(r)),
              AssignmentResource() =>
                _AssignmentTile(lab: r, now: now, onSubmit: () => onSubmit(r)),
            },
          ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.doc, required this.state, required this.onDownload});

  final DocumentResource doc;
  final ResourceDownloadState state;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (successBg, successFg) = toneColors(scheme, BadgeTone.success, solid: true);
    final button = switch (state) {
      ResourceDownloadState.idle => _CompactButton(
          label: 'Get',
          icon: Icons.download,
          background: scheme.primary,
          foreground: scheme.onPrimary,
          onPressed: onDownload,
        ),
      ResourceDownloadState.downloading => _CompactButton(
          label: '...',
          background: scheme.primary,
          foreground: scheme.onPrimary,
          loading: true,
        ),
      ResourceDownloadState.done => _CompactButton(
          label: 'Done',
          icon: Icons.check,
          background: successBg,
          foreground: successFg,
        ),
    };
    return _ResourceCard(
      icon: Icons.description_outlined,
      iconColors: (scheme.surfaceContainerHigh, scheme.primary),
      title: doc.title,
      meta: _MetaLine(
        tag: doc.format,
        tagColors: (scheme.surfaceContainer, scheme.onSurfaceVariant),
        items: [formatFileSize(doc.sizeBytes), 'Updated ${formatMonthDay(doc.updatedAt)}'],
      ),
      trailing: button,
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.video, required this.onStream});

  final VideoResource video;
  final VoidCallback onStream;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = toneColors(scheme, BadgeTone.accent);
    return _ResourceCard(
      icon: Icons.play_circle,
      iconColors: accent,
      title: video.title,
      meta: _MetaLine(
        tag: 'Video',
        tagColors: accent,
        items: [formatVideoLength(video.duration), video.quality],
      ),
      trailing: _CompactButton(
        label: 'Stream',
        icon: Icons.stream,
        background: scheme.secondary,
        foreground: scheme.onSecondary,
        onPressed: onStream,
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({required this.lab, required this.now, required this.onSubmit});

  final AssignmentResource lab;
  final DateTime now;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final (_, accentFg) = toneColors(scheme, BadgeTone.accent);
    final badge = lab.isSubmitted
        ? const AppBadge('Submitted', tone: BadgeTone.success, icon: Icons.check_circle)
        : AppBadge(
            formatDueLabel(lab.dueAt, now),
            tone: BadgeTone.accent,
            icon: Icons.timer_outlined,
          );
    final button = _CompactButton(
      label: lab.isSubmitted ? 'Resubmit' : 'Submit Repo',
      background: scheme.surfaceContainer,
      foreground: scheme.primary,
      height: 36,
      onPressed: onSubmit,
    );
    final grading = Row(
      children: [
        Icon(
          lab.isMandatory ? Icons.warning_amber_rounded : Icons.star_outline_rounded,
          size: 16,
          color: accentFg,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${lab.isMandatory ? 'Mandatory for grading' : 'Bonus assignment'}'
            ' • ${lab.points} Pts',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );

    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = _stackActions(context, constraints);
          final texts = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lab.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 2),
              Text(
                lab.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              if (stacked) ...[const SizedBox(height: AppSpacing.sm), badge],
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ResourceIcon(
                    icon: Icons.terminal,
                    colors: toneColors(scheme, BadgeTone.success),
                  ),
                  const SizedBox(width: 14),
                  Expanded(flex: 3, child: texts),
                  if (!stacked) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(flex: 2, child: badge),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (stacked) ...[
                grading,
                const SizedBox(height: AppSpacing.sm),
                Align(alignment: Alignment.centerRight, child: button),
              ] else
                Row(
                  children: [
                    Expanded(child: grading),
                    const SizedBox(width: AppSpacing.sm),
                    button,
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

/// True when the action button should go under the texts instead of beside
/// them: narrow card or large accessibility font.
bool _stackActions(BuildContext context, BoxConstraints constraints) =>
    constraints.maxWidth < 260 || MediaQuery.textScalerOf(context).scale(1) > 1.3;

/// Icon box + title/meta + action, in an [AppCard].
class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.icon,
    required this.iconColors,
    required this.title,
    required this.meta,
    required this.trailing,
  });

  final IconData icon;
  final (Color, Color) iconColors;
  final String title;
  final Widget meta;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final info = Row(
      children: [
        _ResourceIcon(icon: icon, colors: iconColors),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              meta,
            ],
          ),
        ),
      ],
    );
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) => _stackActions(context, constraints)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  info,
                  const SizedBox(height: AppSpacing.md),
                  Align(alignment: Alignment.centerRight, child: trailing),
                ],
              )
            : Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: AppSpacing.md),
                  trailing,
                ],
              ),
      ),
    );
  }
}

class _ResourceIcon extends StatelessWidget {
  const _ResourceIcon({required this.icon, required this.colors});

  final IconData icon;

  /// (background, foreground)
  final (Color, Color) colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: colors.$1, borderRadius: AppRadius.lgAll),
      child: Icon(icon, size: 26, color: colors.$2),
    );
  }
}

/// "[PDF] • 4.2 MB • Updated Oct 12" (wraps on narrow screens).
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.tag, required this.tagColors, required this.items});

  final String tag;
  final (Color, Color) tagColors;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: tagColors.$1,
            borderRadius: BorderRadius.circular(AppRadius.sm / 2),
          ),
          child: Text(
            tag,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: tagColors.$2, fontWeight: FontWeight.w700),
          ),
        ),
        for (final item in items) Text('• $item', style: muted),
      ],
    );
  }
}

/// Small filled button sized to its content (the theme's buttons stretch to
/// the full width, which a Row can't lay out).
class _CompactButton extends StatelessWidget {
  const _CompactButton({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.height = 40,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;

  /// Null shows the button in its colors but not tappable (busy / done).
  final VoidCallback? onPressed;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background,
        disabledForegroundColor: foreground,
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
            )
          else if (icon != null)
            Icon(icon, size: 16),
          if (loading || icon != null) const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
