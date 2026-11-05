import 'package:campuspulse/features/notifications/presentation/widgets/rich_body_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseBodyMarkup', () {
    test('plain text is a single segment', () {
      expect(parseBodyMarkup('Hello'), [(text: 'Hello', emphasis: BodyEmphasis.none)]);
    });

    test('strong, struck and highlight', () {
      expect(
        parseBodyMarkup('At **10:15** from ~~Amphi 3B~~ to ==Grand Amphi C== today.'),
        [
          (text: 'At ', emphasis: BodyEmphasis.none),
          (text: '10:15', emphasis: BodyEmphasis.strong),
          (text: ' from ', emphasis: BodyEmphasis.none),
          (text: 'Amphi 3B', emphasis: BodyEmphasis.struck),
          (text: ' to ', emphasis: BodyEmphasis.none),
          (text: 'Grand Amphi C', emphasis: BodyEmphasis.highlight),
          (text: ' today.', emphasis: BodyEmphasis.none),
        ],
      );
    });

    test('markup at both ends, back to back', () {
      expect(parseBodyMarkup('**a**==b=='), [
        (text: 'a', emphasis: BodyEmphasis.strong),
        (text: 'b', emphasis: BodyEmphasis.highlight),
      ]);
    });

    test('unclosed markers stay literal', () {
      expect(parseBodyMarkup('Price **12 TND'), [
        (text: 'Price **12 TND', emphasis: BodyEmphasis.none),
      ]);
    });

    test('empty body', () {
      expect(parseBodyMarkup(''), isEmpty);
    });
  });

  test('bodyPlainText strips the markup', () {
    expect(
      bodyPlainText('Lecture at **10:15** moved from ~~Amphi 3B~~ to ==Grand Amphi C==.'),
      'Lecture at 10:15 moved from Amphi 3B to Grand Amphi C.',
    );
  });
}
