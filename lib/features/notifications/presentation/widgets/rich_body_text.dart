import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_badge.dart';

enum BodyEmphasis { none, strong, struck, highlight }

typedef BodySegment = ({String text, BodyEmphasis emphasis});

final _markup = RegExp(r'\*\*(.+?)\*\*|~~(.+?)~~|==(.+?)==');

/// Splits a notification body on `**strong**`, `~~struck~~` and `==highlight==`.
/// Unclosed markers are kept as plain text.
List<BodySegment> parseBodyMarkup(String body) {
  final segments = <BodySegment>[];
  var start = 0;
  for (final m in _markup.allMatches(body)) {
    if (m.start > start) {
      segments.add((text: body.substring(start, m.start), emphasis: BodyEmphasis.none));
    }
    final (text, emphasis) = m.group(1) != null
        ? (m.group(1)!, BodyEmphasis.strong)
        : m.group(2) != null
            ? (m.group(2)!, BodyEmphasis.struck)
            : (m.group(3)!, BodyEmphasis.highlight);
    segments.add((text: text, emphasis: emphasis));
    start = m.end;
  }
  if (start < body.length) {
    segments.add((text: body.substring(start), emphasis: BodyEmphasis.none));
  }
  return segments;
}

/// The body without its markup (for screen readers and search).
String bodyPlainText(String body) => parseBodyMarkup(body).map((s) => s.text).join();

/// Notification body: muted text with emphasized times, rooms and places.
class RichBodyText extends StatelessWidget {
  const RichBodyText(this.body, {super.key});

  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (_, accent) = toneColors(scheme, BadgeTone.accent);
    final base = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (final s in parseBodyMarkup(body))
            TextSpan(
              text: s.text,
              style: switch (s.emphasis) {
                BodyEmphasis.none => null,
                BodyEmphasis.strong =>
                  TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
                BodyEmphasis.struck => TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                BodyEmphasis.highlight => TextStyle(color: accent, fontWeight: FontWeight.w600),
              },
            ),
        ],
      ),
    );
  }
}
