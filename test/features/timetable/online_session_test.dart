import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:campuspulse/features/home/presentation/widgets/today_schedule.dart';
import 'package:campuspulse/features/home/presentation/widgets/up_next_card.dart';
import 'package:campuspulse/features/timetable/domain/entities/class_session.dart';
import 'package:campuspulse/features/timetable/presentation/widgets/meet_link.dart';
import 'package:campuspulse/features/timetable/presentation/widgets/session_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _meet = 'https://meet.google.com/xqd-fkzw-pnb';

/// Friday 6 November 2026, 13:00: the online workshop starts at 13:30.
final _now = DateTime(2026, 11, 6, 13);

ClassSession _session({
  SessionMode mode = SessionMode.online,
  String? meetUrl = _meet,
  SessionKind kind = SessionKind.workshop,
  int startHour = 13,
}) =>
    ClassSession(
      id: 'entrepreneuriat-2026-11-6',
      course: 'Entrepreneuriat & Innovation',
      room: mode == SessionMode.online ? 'Online' : 'Espace Coworking',
      teacher: 'Mme. Karoui',
      start: DateTime(2026, 11, 6, startHour, 30),
      end: DateTime(2026, 11, 6, startHour + 2, 30),
      kind: kind,
      mode: mode,
      meetUrl: meetUrl,
    );

/// [child] with a launcher that records the links (answering [opens]).
Future<List<Uri>> _pump(WidgetTester tester, Widget child, {bool opens = true}) async {
  final opened = <Uri>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        meetLauncherProvider.overrideWithValue((url) async {
          opened.add(url);
          return opens;
        }),
      ],
      child: MaterialApp(
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary)),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
  return opened;
}

void main() {
  testWidgets('an online class shows "Online" and opens its Google Meet link', (tester) async {
    final opened = await _pump(
      tester,
      SessionCard(session: _session(), status: SessionStatus.next, now: _now),
    );

    expect(find.byType(OnlineChip), findsOneWidget);
    expect(find.text('Online'), findsWidgets);
    await tester.tap(find.text('Join Google Meet'));
    await tester.pump();

    expect(opened, [Uri.parse(_meet)]);
  });

  testWidgets('says so when the link could not be opened', (tester) async {
    await _pump(
      tester,
      SessionCard(session: _session(), status: SessionStatus.ongoing, now: _now),
      opens: false,
    );
    await tester.tap(find.text('Join Google Meet'));
    await tester.pump();
    expect(find.text('Could not open Google Meet. The link is $_meet'), findsOneWidget);
  });

  testWidgets('no link yet: the button says it is coming', (tester) async {
    await _pump(
      tester,
      SessionCard(session: _session(meetUrl: null), status: SessionStatus.next, now: _now),
    );
    expect(find.text('Google Meet link coming soon'), findsOneWidget);
    expect(find.text('Join Google Meet'), findsNothing);
  });

  testWidgets('online exams have the button, not the seat finder', (tester) async {
    await _pump(
      tester,
      SessionCard(
        session: _session(kind: SessionKind.exam),
        status: SessionStatus.next,
        now: _now,
        onFindSeat: () {},
      ),
    );
    expect(find.text('Join Google Meet'), findsOneWidget);
    expect(find.text('Find Seat'), findsNothing);
  });

  testWidgets('a past online class and on-site classes have no button', (tester) async {
    await _pump(
      tester,
      Column(
        children: [
          SessionCard(
            session: _session(startHour: 9),
            status: SessionStatus.done,
            now: _now,
          ),
          SessionCard(
            session: _session(mode: SessionMode.onsite, meetUrl: null),
            status: SessionStatus.next,
            now: _now,
          ),
        ],
      ),
    );
    expect(find.byType(OnlineChip), findsOneWidget);
    expect(find.text('Join Google Meet'), findsNothing);
    expect(find.text('Espace Coworking'), findsOneWidget);
  });

  testWidgets('Home: "Up next" joins the online class, the schedule says Online', (tester) async {
    final opened = await _pump(
      tester,
      Column(
        children: [
          UpNextCard(sessions: [_session()], now: _now),
          TodaySchedule(sessions: [_session()], now: _now),
        ],
      ),
    );

    expect(find.text('Online · Mme. Karoui'), findsNWidgets(2));
    await tester.tap(find.text('Join Google Meet'));
    await tester.pump();
    expect(opened, [Uri.parse(_meet)]);
  });
}
