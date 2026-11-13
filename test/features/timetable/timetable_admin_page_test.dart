import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:campuspulse/features/timetable/data/repositories/mock_timetable_admin_repository.dart';
import 'package:campuspulse/features/timetable/data/repositories/mock_timetable_store.dart';
import 'package:campuspulse/features/timetable/domain/timetable_slot_rules.dart';
import 'package:campuspulse/features/timetable/presentation/admin/timetable_admin_page.dart';
import 'package:campuspulse/features/timetable/presentation/providers/timetable_admin_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Administration › Timetable on the mock repository (the demo week), at
/// [width] dp with [textScale] text.
Future<MockTimetableStore> _pump(
  WidgetTester tester, {
  double width = 390,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 900) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final store = MockTimetableStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        timetableAdminRepositoryProvider.overrideWithValue(
          MockTimetableAdminRepository(store: store, delay: Duration.zero),
        ),
      ],
      child: MaterialApp(
        // Plain theme: the app theme pulls Google Fonts from the network.
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary)),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const TimetableAdminPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Finder _field(String key) => find.byKey(Key('slot-$key'));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(_field(key));
  await tester.enterText(_field(key), text);
  await tester.pump();
}

Future<void> _save(WidgetTester tester) => _tap(tester, find.text('Add the class'));

/// Opens the form and fills a valid Saturday class (not saved yet).
Future<void> _fillSaturdayClass(WidgetTester tester) async {
  await tester.tap(find.text('Add a class'));
  await tester.pumpAndSettle();
  await _tap(tester, _field('weekday'));
  await tester.tap(find.text('Saturday').last);
  await tester.pumpAndSettle();
  await _enter(tester, 'start', '09:00');
  await _enter(tester, 'end', '11:00');
  await _enter(tester, 'course', 'Cloud Computing');
  await _enter(tester, 'teacher', 'Dr. Zribi');
  await _enter(tester, 'room', 'Salle C201');
}

void main() {
  testWidgets('lists the week by day, with the online class', (tester) async {
    await _pump(tester);

    expect(find.text('Timetable'), findsOneWidget);
    expect(find.text('Monday · 4 classes'), findsOneWidget);
    expect(find.text('Algorithmes & Complexité'), findsWidgets);
    expect(find.text('Lecture · Amphi A · Prof. Trabelsi'), findsOneWidget);

    final friday = find.text('Entrepreneuriat & Innovation');
    await tester.scrollUntilVisible(friday, 300, scrollable: find.byType(Scrollable).last);
    expect(find.text('Workshop · Online · Mme. Karoui'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adds a class: it shows under its day', (tester) async {
    final store = await _pump(tester);

    await _fillSaturdayClass(tester);
    await _save(tester);

    expect(find.text('Class added. Students and teachers are notified.'), findsOneWidget);
    expect(store.slots.where((s) => s.weekday == 6).map((s) => s.course), ['Cloud Computing']);
    final saturday = find.text('Saturday · 1 class');
    await tester.scrollUntilVisible(saturday, 300, scrollable: find.byType(Scrollable).last);
    expect(find.text('Lecture · Salle C201 · Dr. Zribi'), findsOneWidget);
  });

  testWidgets('the form checks the fields before sending', (tester) async {
    final store = await _pump(tester);
    await tester.tap(find.text('Add a class'));
    await tester.pumpAndSettle();

    await _save(tester);
    expect(find.text(SlotMessages.courseMissing), findsOneWidget);
    expect(find.text(SlotMessages.teacherMissing), findsOneWidget);
    expect(find.text(SlotMessages.roomMissing), findsOneWidget);

    await _enter(tester, 'end', '08:00');
    await _save(tester);
    expect(find.text(SlotMessages.endBeforeStart), findsOneWidget);

    // Online: the room becomes optional, the Meet link is required and checked.
    await _tap(tester, _field('online'));
    await _save(tester);
    expect(find.text(SlotMessages.roomMissing), findsNothing);
    expect(find.text(SlotMessages.meetUrlMissing), findsOneWidget);
    await _enter(tester, 'google', 'https://zoom.us/j/123');
    await _save(tester);
    expect(find.text(SlotMessages.meetUrlInvalid), findsOneWidget);

    expect(store.slots, hasLength(17));
  });

  testWidgets('an online class is saved with its Meet link', (tester) async {
    final store = await _pump(tester);
    await _fillSaturdayClass(tester);
    await _enter(tester, 'room', '');
    await _tap(tester, _field('online'));
    await _enter(tester, 'google', 'https://meet.google.com/abc-defg-hij');
    await _save(tester);

    final slot = store.slots.singleWhere((s) => s.weekday == 6);
    expect(slot.isOnline, isTrue);
    expect(slot.meetUrl, 'https://meet.google.com/abc-defg-hij');
    expect(slot.room, '');
  });

  testWidgets('a clash lists the classes in the way', (tester) async {
    final store = await _pump(tester);
    await _fillSaturdayClass(tester);
    // Monday 09:00–10:30 in Amphi A: Algorithmes is there 08:30–10:00.
    await _tap(tester, _field('weekday'));
    await tester.tap(find.text('Monday').last);
    await tester.pumpAndSettle();
    await _enter(tester, 'end', '10:30');
    await _enter(tester, 'room', 'Amphi A');
    await _save(tester);

    expect(find.byKey(const Key('slot-conflicts')), findsOneWidget);
    expect(find.text(SlotMessages.conflict), findsOneWidget);
    expect(
      find.text('Same room: Algorithmes & Complexité, Monday 08:30–10:00 (Amphi A)'),
      findsOneWidget,
    );
    // Still on the form, nothing saved.
    expect(find.widgetWithText(AppBar, 'Add a class'), findsOneWidget);
    expect(store.slots, hasLength(17));
  });

  testWidgets('edits a class', (tester) async {
    final store = await _pump(tester);
    await _tap(tester, find.text('Lecture · Amphi A · Prof. Trabelsi'));

    expect(find.text('Edit the class'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Algorithmes & Complexité'), findsOneWidget);
    await _enter(tester, 'room', 'Amphi B');
    await _tap(tester, find.text('Save changes'));

    expect(find.text('Changes saved. Students and teachers are notified.'), findsOneWidget);
    expect(find.text('Lecture · Amphi B · Prof. Trabelsi'), findsOneWidget);
    expect(store.slots.singleWhere((s) => s.id == 'algo-cm').room, 'Amphi B');
  });

  testWidgets('removes a class after confirmation', (tester) async {
    final store = await _pump(tester);
    final remove = find.byTooltip('Remove Algorithmes & Complexité').first;

    await _tap(tester, remove);
    expect(find.text('Remove this class?'), findsOneWidget);
    await _tap(tester, find.text('Cancel'));
    expect(store.slots, hasLength(17));

    await _tap(tester, remove);
    await _tap(tester, find.text('Remove'));
    expect(find.text('Class removed. Students and teachers are notified.'), findsOneWidget);
    expect(store.slots.any((s) => s.id == 'algo-cm'), isFalse);
    // (Scrolled above the screen by the tap.)
    expect(find.text('Monday · 3 classes', skipOffstage: false), findsOneWidget);
  });

  testWidgets('fits at 360 dp with large text', (tester) async {
    await _pump(tester, width: 360, textScale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Add a class'));
    await tester.pumpAndSettle();
    await _tap(tester, _field('online'));
    expect(tester.takeException(), isNull);
  });
}
