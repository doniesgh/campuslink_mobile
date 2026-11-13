import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_badge.dart';
import '../../domain/entities/job_application.dart';

/// "Pending" / "Accepted" / "Refused" pill of an application.
class ApplicationStatusBadge extends StatelessWidget {
  const ApplicationStatusBadge(this.status, {super.key});

  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) => switch (status) {
        ApplicationStatus.pending =>
          AppBadge(status.label, tone: BadgeTone.accent, icon: Icons.schedule),
        ApplicationStatus.accepted =>
          AppBadge(status.label, tone: BadgeTone.success, icon: Icons.check, solid: true),
        // Swap for a danger tone if your AppBadge has one.
        ApplicationStatus.rejected =>
          AppBadge(status.label, tone: BadgeTone.neutral, icon: Icons.close),
      };
}
