import 'dart:convert';
import 'dart:io';

import 'package:campuspulse/core/l10n/app_language.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

void main() {
  test('fromCode reads fr and en, any case or region', () {
    expect(AppLanguage.fromCode('fr'), AppLanguage.fr);
    expect(AppLanguage.fromCode(' EN '), AppLanguage.en);
    expect(AppLanguage.fromCode('en-GB'), AppLanguage.en);
    expect(AppLanguage.fromCode('fr_TN'), AppLanguage.fr);
    expect(AppLanguage.fromCode('ar'), isNull);
    expect(AppLanguage.fromCode(null), isNull);
    expect(AppLanguage.fromCode(42), isNull);
  });

  test('each language has its code, locale and name in itself', () {
    expect(AppLanguage.fr.code, 'fr');
    expect(AppLanguage.en.locale, const Locale('en'));
    expect(AppLanguage.values.map((l) => l.nativeName), ['Français', 'English']);
  });

  group('resolveAppLanguage', () {
    test("the user's choice wins", () {
      expect(resolveAppLanguage('en', const [Locale('fr', 'FR')]), AppLanguage.en);
      expect(resolveAppLanguage('fr', const [Locale('en', 'US')]), AppLanguage.fr);
    });

    test("else the device's first language the app speaks", () {
      expect(resolveAppLanguage(null, const [Locale('en', 'US')]), AppLanguage.en);
      expect(resolveAppLanguage(null, const [Locale('ar', 'TN'), Locale('fr', 'TN')]), AppLanguage.fr);
      expect(resolveAppLanguage(null, const [Locale('de'), Locale('en'), Locale('fr')]), AppLanguage.en);
    });

    test('else French', () {
      expect(resolveAppLanguage(null, const [Locale('de', 'DE')]), AppLanguage.fr);
      expect(resolveAppLanguage(null, const []), AppLanguage.fr);
      expect(resolveAppLanguage('xx', const [Locale('es')]), AppLanguage.fr);
    });
  });

  test('both ARB files have the same keys (a key missing in French would show English)', () {
    Set<String> keysOf(String file) => (jsonDecode(File('lib/l10n/$file').readAsStringSync())
            as Map<String, dynamic>)
        .keys
        .where((key) => !key.startsWith('@'))
        .toSet();
    final en = keysOf('app_en.arb');
    expect(en, isNotEmpty);
    expect(keysOf('app_fr.arb'), en);
    // Every key starts with its feature (`common…`, `account…`, `forum…`...).
    expect(en.where((k) => !RegExp(r'^[a-z]+[A-Z]\w*$').hasMatch(k)), isEmpty);
  });

  test('the generated texts follow the ARB files', () {
    expect(l10nFor(AppLanguage.en).localeName, 'en');
    expect(l10nFor(AppLanguage.fr).accountLanguageTitle, 'Langue');
    expect(l10nFor(AppLanguage.en).accountLanguageTitle, 'Language');
  });
}
