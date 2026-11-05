import 'package:campuspulse/features/forum/domain/entities/lost_item.dart';
import 'package:campuspulse/features/forum/presentation/utils/lost_found_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

LostItem _item(LostItemKind kind, {String zone = 'Bloc C'}) => LostItem(
      id: 'x',
      kind: kind,
      title: 'Objet',
      category: LostItemCategory.other,
      zone: zone,
      location: 'Salle C12',
      place: LostItemPlace.classroom,
      reporterName: 'Meriem B.',
      reportedAt: DateTime(2026, 11, 5),
    );

void main() {
  group('formatLostItemTime', () {
    final now = DateTime(2026, 11, 5, 14);
    String fmt(DateTime d, [DateTime? at]) => formatLostItemTime(d, now: at ?? now);

    test('less than a minute ago, or in the future', () {
      expect(fmt(now.subtract(const Duration(seconds: 30))), "À l'instant");
      expect(fmt(now.add(const Duration(minutes: 5))), "À l'instant");
    });

    test('minutes ago within the last hour', () {
      expect(fmt(now.subtract(const Duration(minutes: 45))), 'Il y a 45 min');
      expect(fmt(now.subtract(const Duration(minutes: 59))), 'Il y a 59 min');
    });

    test('earlier today', () {
      expect(fmt(DateTime(2026, 11, 5, 11)), "Aujourd'hui, 11h");
      expect(fmt(DateTime(2026, 11, 5, 9, 5)), "Aujourd'hui, 9h05");
    });

    test('yesterday', () {
      expect(fmt(DateTime(2026, 11, 4, 16, 30)), 'Hier, 16h30');
      // Just after midnight: more than an hour ago, but on the previous day.
      expect(fmt(DateTime(2026, 11, 4, 23, 30), DateTime(2026, 11, 5, 0, 40)), 'Hier, 23h30');
    });

    test('older dates', () {
      expect(fmt(DateTime(2026, 11, 3, 8)), '03/11');
      expect(fmt(DateTime(2026, 9, 28, 8)), '28/09');
    });
  });

  test('lostItemStatusLabel', () {
    expect(lostItemStatusLabel(_item(LostItemKind.found)), 'Trouvé · Bloc C');
    expect(lostItemStatusLabel(_item(LostItemKind.lost, zone: 'Parking')), 'Perdu · Parking');
  });

  test('lostItemReporterPrefix', () {
    expect(lostItemReporterPrefix(_item(LostItemKind.found)), 'Déposé par');
    expect(lostItemReporterPrefix(_item(LostItemKind.lost)), 'Signalé par');
  });
}
