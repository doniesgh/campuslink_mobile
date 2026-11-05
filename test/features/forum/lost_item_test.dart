import 'package:campuspulse/features/forum/domain/entities/lost_item.dart';
import 'package:flutter_test/flutter_test.dart';

LostItem _item(
  String id, {
  LostItemKind kind = LostItemKind.found,
  String title = 'Objet',
  String zone = 'Bloc C',
  String location = 'Salle C12 (Ghazela)',
  String? reference,
  bool serialHidden = false,
}) =>
    LostItem(
      id: id,
      kind: kind,
      title: title,
      category: LostItemCategory.other,
      zone: zone,
      location: location,
      place: LostItemPlace.other,
      reporterName: 'Youssef M.',
      reportedAt: DateTime(2026, 11, 5, 10),
      reference: reference,
      isSerialHidden: serialHidden,
    );

void main() {
  group('foldForSearch', () {
    test('lowercases and strips French accents', () {
      expect(foldForSearch('Écouteurs Sony'), 'ecouteurs sony');
      expect(foldForSearch('Bibliothèque Étage 1'), 'bibliotheque etage 1');
      expect(foldForSearch('Ça Où Clés'), 'ca ou cles');
    });
  });

  group('LostItem.matches', () {
    final item = _item(
      'a',
      title: 'Écouteurs Sony WH-1000XM4',
      zone: 'Bibliothèque',
      location: 'Bibliothèque centrale (Étage 1)',
      reference: 'TF-411',
    );

    test('an empty or blank query matches everything', () {
      expect(item.matches(''), isTrue);
      expect(item.matches('   '), isTrue);
    });

    test('matches the title, case and accent insensitively', () {
      expect(item.matches('sony'), isTrue);
      expect(item.matches('ecouteurs'), isTrue);
      expect(item.matches('ÉCOUTEURS'), isTrue);
      expect(_item('b', title: 'Ecouteurs').matches('Écouteurs'), isTrue);
    });

    test('matches the location, zone and reference', () {
      expect(item.matches('etage 1'), isTrue);
      expect(_item('c').matches('c12'), isTrue);
      expect(_item('c').matches('bloc c'), isTrue);
      expect(item.matches('tf-411'), isTrue);
    });

    test('trims the query', () {
      expect(item.matches('  sony  '), isTrue);
    });

    test('does not match unrelated text', () {
      expect(item.matches('parking'), isFalse);
      expect(_item('d').matches('tf-'), isFalse); // no reference
    });
  });

  group('LostItem.action', () {
    test('a lost item can be reported as found', () {
      expect(_item('a', kind: LostItemKind.lost).action, LostItemAction.reportFound);
      expect(
        _item('b', kind: LostItemKind.lost, serialHidden: true).action,
        LostItemAction.reportFound,
      );
    });

    test('a found item can be claimed', () {
      expect(_item('a').action, LostItemAction.claim);
    });

    test('a found item with a hidden serial number asks for a serial check', () {
      expect(_item('a', serialHidden: true).action, LostItemAction.verifySerial);
    });
  });

  group('filterLostItems', () {
    final items = [
      _item('found-calc', title: 'Calculatrice TI-84'),
      _item('lost-keys', kind: LostItemKind.lost, title: 'Clés Peugeot', zone: 'Parking'),
      _item('found-sony', title: 'Sony WH-1000XM4'),
      _item('lost-card', kind: LostItemKind.lost, title: "Carte d'étudiant"),
    ];
    List<String> ids(List<LostItem> list) => [for (final i in list) i.id];

    test('keeps everything, in order, without kind or query', () {
      expect(ids(filterLostItems(items)), ['found-calc', 'lost-keys', 'found-sony', 'lost-card']);
    });

    test('filters by kind', () {
      expect(ids(filterLostItems(items, kind: LostItemKind.lost)), ['lost-keys', 'lost-card']);
      expect(ids(filterLostItems(items, kind: LostItemKind.found)), ['found-calc', 'found-sony']);
    });

    test('filters by query', () {
      expect(ids(filterLostItems(items, query: 'parking')), ['lost-keys']);
      expect(ids(filterLostItems(items, query: 'etudiant')), ['lost-card']);
    });

    test('combines kind and query', () {
      expect(ids(filterLostItems(items, kind: LostItemKind.found, query: 'cl')), isEmpty);
      expect(ids(filterLostItems(items, kind: LostItemKind.lost, query: 'cl')), ['lost-keys']);
    });

    test('returns an empty list when nothing matches', () {
      expect(filterLostItems(items, query: 'parapluie'), isEmpty);
      expect(filterLostItems(const [], kind: LostItemKind.lost), isEmpty);
    });
  });

  group('countLostItems', () {
    test('counts all, lost and found items', () {
      final counts = countLostItems([
        _item('a'),
        _item('b', kind: LostItemKind.lost),
        _item('c'),
      ]);
      expect(counts, (all: 3, lost: 1, found: 2));
    });

    test('is all zeros for an empty list', () {
      expect(countLostItems(const []), (all: 0, lost: 0, found: 0));
    });
  });
}
