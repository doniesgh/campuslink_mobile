# Contributing

How we work on CampusPulse: Git, code conventions, adding a feature end to end, and testing. Read [architecture.md](architecture.md) first: this guide assumes you know where things go.

## 1. Git workflow

- **`main` always works.** It builds, and every test passes.
- **Work on a branch:** `feature/<short-name>` (e.g. `feature/messaging`) or `fix/<short-name>`.
- **Commit messages:** one imperative summary line ("Add ride publishing", "Fix overflow in the auth footer"). Then, if useful, a few lines on *what* and *why*.
- **Merge through a pull request** once the checks below pass. Another teammate reviews it.
- **Never commit secrets:**
  - `backend/.env` holds your JWT secret and SMTP password.
  - `.mcp.json` holds a personal Stitch API key.

  Both are gitignored; keep it that way.

Before opening a pull request, run:

```bash
flutter analyze            # must print "No issues found!"
flutter test               # all green
cd backend
npm run typecheck          # no output
npm test                   # all green
```

## 2. Code conventions

### Flutter (lib/)

- **Put code in its layer** (see [architecture 3.1](architecture.md#31-folder-structure)):
  - Entities and repository interfaces go in `domain/`.
  - JSON parsing and repositories go in `data/`.
  - Pages, widgets and providers go in `presentation/`.
- **Pure logic goes in plain Dart functions** in `domain/` (e.g. `grading.dart`, `schedule_logic.dart`), so it can be unit-tested without widgets.
- **No hard-coded paths, colours or sizes:**
  - Routes: `RoutePaths.*`.
  - API paths: `ApiEndpoints.*`.
  - Colours: `Theme.of(context).colorScheme` or `AppColors`.
  - Spacing, corners and shadows: `AppSpacing`, `AppRadius`, `AppShadows`.
- **Reuse `lib/shared/widgets/`** before writing a new button, card, badge, text field or header.
- **Every screen works in dark mode and on narrow phones.** Wrap long texts in `Expanded`/`Flexible` with an ellipsis. Never put an `AppButton` in a `Row` without `Expanded`: the theme gives buttons an infinite minimum width.
- **Errors are `Failure`s.** Repositories return `Result`, and the UI shows `failure.message`.
- **Features without a backend yet:** show `showAppSnack(context, '… is coming soon.')` and leave a `// TODO:` comment.
- **Text:**
  - Comments in English.
  - **New on-screen text goes through `AppLocalizations`**, in French and English (see [5. Translations](#5-translations-french--english)). Older screens still have hard-coded text (the forum and carpool screens in French, the others mostly in English) until they are moved.

### Backend (backend/src/)

- **Module anatomy:** `<m>.routes.ts`, `<m>.schemas.ts`, `<m>.service.ts`, `<m>.model.ts`, `<m>.seed.ts` (see [architecture 4.3](architecture.md#43-module-anatomy)).
- **Thin route handlers:** validate with `validateBody(schema)`, call one service function, send the result. Handlers use block bodies.
- **Errors:**
  - Throw `HttpError` (`notFound()`, `conflict()`, `badRequest()`…) with a message a student can read.
  - Give it a machine-readable `code` when the app may react to it or translate it: `new HttpError(status, message, details?, code?)`, or the last argument of the helpers (`conflict('…', 'EMAIL_TAKEN')`). The body is `{ message, code?, ...details }`. Validation 422s get `VALIDATION_ERROR` by themselves. List new codes in `lib/http-error.ts` and [api.md](api.md#conventions).
  - Never leak stack traces or ids of other users.
- **Rate limits** (`middleware/rate-limit.ts`): `authLimit('<route>')` + `authIpLimit` on a signed-out route, `userLimit({ name, limit, windowMs })` after `requireAuth` on an expensive signed-in one (AI, uploads), or `createLimiter({ name, limit, windowMs, key })`. They answer `429 TOO_MANY_REQUESTS` with `retryAfter`. They are off in tests; a test of a limit calls `enforceRateLimitsInTests()` (and `enforceRateLimitsInTests(false)` after).
- **Audit:** `recordAudit({ ...requestContext(req, res), action, summary, targetType?, targetId?, metadata? })` (`lib/request-context.ts` gives the actor, IP and User-Agent). Add new actions to `AUDIT_ACTIONS` and a label in the app's `audit_log_page.dart`.
- **AI:** only through `lib/openrouter.ts` (`isAiConfigured()`, `chatJson()`); every AI feature must work, or say "not available", without `OPENROUTER_API_KEY`. Tests use `useFakeOpenRouter()` (`test/fake-openrouter.ts`), never the real service.
- **Language:** a user's emails and notifications use their `user.locale` (`localeOfUser(user)`); before the account exists, `localeOf(req)` (`lib/i18n.ts`).
- **Personal data** is always filtered by `currentUserId(res)`.
- **Responses** are built by a `toXxxJson()` function that sends `id` (never `_id`) and follows the [API conventions](architecture.md#45-api-conventions).
- **Seeds** are idempotent and reset only the demo student's own actions.

## 3. Adding a feature end to end

Example: a hypothetical **Events** feature (campus events, with "I'm going").

### Backend

1. **Create the module** in `backend/src/modules/events/`:
   - `events.model.ts`: `EventModel`, plus `EventAttendanceModel` with a unique index on `{ eventId, userId }`.
   - `events.schemas.ts`: the Zod schemas of the bodies. Their messages are shown in the app.
   - `events.service.ts`: `listEvents(userId)`, `attend(eventId, userId)`, `toEventJson()`.
   - `events.routes.ts`:

     ```ts
     export const eventsRouter = Router();
     eventsRouter.use(requireAuth);
     eventsRouter.get('/', async (_req, res) => {
       res.json(await events.listEvents(currentUserId(res)));
     });
     eventsRouter.post('/:id/attendance', async (req, res) => {
       res.status(201).json(await events.attend(req.params.id, currentUserId(res)));
     });
     ```

   - `events.seed.ts`: `seedEvents(demoUserId)` with a few demo events.
2. **Mount the router** in `src/app.ts` with `api.use('/events', eventsRouter)`. Then add `events: seedEvents` to `moduleSeeds` in `src/scripts/seed.ts`.
3. **Test it** in `test/events.test.ts`. Use `connectTestDb`, `clearTestDb`, `closeTestDb` and `createStudent()` from `test/helpers.ts`. Cover:
   - each endpoint
   - 401 without a token
   - 404, 409 and 422
   - two students' data staying separate
   - the seed
4. **Document the endpoints** in [api.md](api.md).

### App

1. **Domain** (`lib/features/events/domain/`):
   - `entities/event.dart`
   - `repositories/event_repository.dart`, with `getEvents()` and `attend(id)` returning `Result`.
2. **Data** (`lib/features/events/data/`):
   - `repositories/mock_event_repository.dart`: in-memory data that behaves like the API, refusals included.
   - `models/event_models.dart`: `fromJson` → entity.
   - `repositories/event_repository_impl.dart`: Dio calls wrapped in `guard()`.
3. **API paths:** add them to `lib/core/network/api_endpoints.dart`.
4. **Providers** (`presentation/providers/event_providers.dart`):

   ```dart
   final eventRepositoryProvider = Provider<EventRepository>((ref) =>
       Env.useMock ? MockEventRepository() : EventRepositoryImpl(ref.watch(dioProvider)));

   final eventsProvider = FutureProvider.autoDispose<List<Event>>(
     (ref) async => (await ref.watch(eventRepositoryProvider).getEvents()).unwrap(),
   );
   ```

5. **UI:** pages and widgets in `presentation/`. Add the route to `RoutePaths` and to `app_router.dart`.
6. **Tests** in `test/features/events/`:
   - unit tests for any pure logic
   - a **contract test**: paste a real response printed by your backend test as a fixture, and parse it into the entity
   - a widget test of the page with the repository provider overridden by a fake

## 4. Testing

### What we test

| Kind | Where | Example |
|---|---|---|
| Pure logic | `test/features/<f>/`, `test/core/` | Grading maths, schedule statuses, validators, formatters |
| Contract (JSON) | `test/features/<f>/…fixtures…` | Real API responses parsed into entities |
| Repositories | `test/features/<f>/…_repository_impl_test.dart` | Remote repository with a fake Dio adapter, plus the mock repository |
| Widgets / pages | `test/features/<f>/…_page_test.dart` | Fill a form, tap, check navigation and snackbars |
| API | `backend/test/<module>.test.ts` | Supertest on the real Express app with a real (test) MongoDB |

### Writing widget tests

The existing page tests follow these rules; copy them (e.g. `test/features/auth/reset_password_page_test.dart`):

- **Theme:** use a **plain `ThemeData`**. The app theme downloads Google Fonts, which doesn't work in tests.
- **Routing:** build a small `GoRouter` with only the routes the page needs.
- **Providers:** override them with fakes in `ProviderScope(overrides: […])`. This includes `authControllerProvider` and any `…RepositoryProvider`, and `clockProvider` when the page depends on today's date.
- **Screen size and text scale:** test at **360 dp wide with 1.3× text**, in light and dark. Overflows are caught as test failures.

```dart
tester.view.physicalSize = const Size(360, 800) * 3;
tester.view.devicePixelRatio = 3;
addTearDown(tester.view.reset);
```

- **Fix the date:** tests must pass on any day, so pass a fixed `DateTime` (or override `clockProvider`) instead of using `DateTime.now()`.
- **Texts:** a screen that uses `AppLocalizations` needs the delegates. Use `test/helpers/localized_app.dart`: `localizedApp(page)` for a plain `MaterialApp`, or pass `localizationsDelegates: testLocalizationsDelegates, supportedLocales: testSupportedLocales, locale: const Locale('en')` to your `MaterialApp.router`, and add `localeOverride()` to the overrides when something watches `localeProvider`. Tests run in English unless they ask for `AppLanguage.fr`.

### Backend tests

- **The database:** tests run against the local MongoDB and never touch your dev data. Each Jest worker gets a throwaway database, `campuspulse_test_<n>`.
- **Running two test sessions at once** (e.g. two terminals): set a different prefix in each so they don't share a database, e.g. `TEST_DB_PREFIX=cp_me npx jest test/events.test.ts`.
- **Emails:** `captureMail()` (in `test/helpers.ts`) catches them instead of sending them, so tests can read the codes.

### Current numbers

**611 backend tests** (28 suites) and **696 app tests** (72 files). Keep them all green.

## 5. Translations (French / English)

The app speaks French and English. Its texts live in two ARB files, turned into Dart by Flutter's **gen-l10n**:

- `lib/l10n/app_en.arb`: the **template**, with a `@key` description for each text.
- `lib/l10n/app_fr.arb`: the same keys in French. French says **"tu"**, warm and simple.
- `lib/l10n/app_localizations*.dart`: **generated, and committed** (`flutter analyze` and `flutter test` don't generate them, so a fresh clone works at once). Never edit them by hand.
- `l10n.yaml` sets this up; `pubspec.yaml` has `generate: true`.

**To add a text:**

1. Add the key to **both** ARB files, in your feature's block. Prefix it with the feature, camelCase: `common…` (shared: errors, buttons), `account…`, `admin…`, `forum…`, `jobs…`, `timetable…`, `auth…`… Each feature keeps its keys together, so merging two branches' ARB files is just keeping both blocks.

   ```json
   "accountLanguageTitle": "Language",
   "@accountLanguageTitle": { "description": "Settings row to choose the app's language." },
   ```

   Values with data use placeholders: `"jobsApplicants": "{count, plural, =1{1 applicant} other{{count} applicants}}"` with `"@jobsApplicants": { "placeholders": { "count": { "type": "int" } } }`.
2. Run `flutter gen-l10n` (or `flutter pub get`, or just run the app): it rewrites the generated files. Commit the ARB files and the generated files together. On a merge conflict in the generated files, merge the ARB files, then run `flutter gen-l10n`.
3. Use it in a widget: `context.l10n.accountLanguageTitle` (`import 'core/l10n/l10n.dart'`), the same as `AppLocalizations.of(context).accountLanguageTitle`.

`test/core/l10n/app_language_test.dart` fails when a key is missing from one of the files.

**The language:** `ref.watch(localeProvider)` gives the `AppLanguage` on screen (`fr` or `en`); `ref.read(localeProvider.notifier).set(AppLanguage.en)` changes it, saves it and updates the signed-in account. Error messages: show `failureText(context, failure)` to translate the error codes the app knows (`core/error/failure_text.dart`), else the server's message.
