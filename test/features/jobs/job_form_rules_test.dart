import 'package:campuspulse/features/jobs/domain/job_form_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// The same rules and messages as backend/src/modules/jobs/jobs.schemas.ts.
void main() {
  test('title and description are required, with a minimum length', () {
    expect(JobFormRules.title(''), 'Enter a title.');
    expect(JobFormRules.title(' ab '), 'The title needs at least 3 characters.');
    expect(JobFormRules.title('x' * 121), 'The title can have at most 120 characters.');
    expect(JobFormRules.title('Flutter Intern'), isNull);

    expect(JobFormRules.description('  '), 'Enter a description.');
    expect(JobFormRules.description('Too short.'), 'The description needs at least 20 characters.');
    expect(JobFormRules.description('x' * 20), isNull);
  });

  test('company is required in the form; location and period are optional', () {
    expect(JobFormRules.company(''), 'The company name needs at least 2 characters.');
    expect(JobFormRules.company('Medina Soft'), isNull);
    expect(JobFormRules.location(''), isNull);
    expect(JobFormRules.location('x' * 101), 'The location can have at most 100 characters.');
    expect(JobFormRules.period('x' * 61), 'The period can have at most 60 characters.');
  });

  test('duration and stipend are optional whole numbers in range', () {
    expect(JobFormRules.durationMonths(''), isNull);
    expect(JobFormRules.durationMonths('6'), isNull);
    for (final bad in ['0', '37', '2.5', 'six']) {
      expect(JobFormRules.durationMonths(bad), JobFormRules.durationMessage, reason: bad);
    }
    expect(JobFormRules.stipendTnd('0'), isNull);
    expect(JobFormRules.stipendTnd('-1'), JobFormRules.stipendMessage);
    expect(JobFormRules.parseNumber(' 800 '), 800);
    expect(JobFormRules.parseNumber(''), isNull);
  });

  test('skills and tags are comma-separated, trimmed and deduplicated', () {
    expect(JobFormRules.splitList(' Flutter, Dart, , Flutter '), ['Flutter', 'Dart']);
    expect(JobFormRules.splitList(''), isEmpty);
    expect(JobFormRules.skills(List.generate(15, (i) => 's$i').join(',')), isNull);
    expect(JobFormRules.skills(List.generate(16, (i) => 's$i').join(',')), JobFormRules.skillsMessage);
    expect(JobFormRules.tags('a,b,c,d,e,f,g'), JobFormRules.tagsMessage);
    expect(JobFormRules.tags('x' * 41), JobFormRules.tagsMessage);
  });
}
