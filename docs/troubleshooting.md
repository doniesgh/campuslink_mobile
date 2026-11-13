# Troubleshooting

Problems we actually hit while building CampusPulse, and how to fix them.

## App and emulator

**"Emulator didn't connect within 60 seconds"**
- **Cause:** the emulator's first (cold) boot is slow. VS Code gives up, but the emulator keeps starting.
- **Fix:** wait for the Android home screen, then press F5 again. Later boots are faster.

**"x86_64 emulation currently requires hardware acceleration" / the emulator won't start**
- **Fix:** turn on **Windows Hypervisor Platform** (Turn Windows features on or off), then reboot.
- **Check:** `<sdk>\emulator\emulator.exe -accel-check` should say *WHPX … is installed and usable*.

**"Building with plugins requires symlink support"**
- **Fix:** turn on Windows **Developer Mode**. Run `start ms-settings:developers`.

**Android licenses not accepted / "Unable to locate Android SDK"**
- **Fix:** run `flutter doctor --android-licenses`.
- If Flutter can't find the SDK yet, run `<sdk>\cmdline-tools\latest\bin\sdkmanager.bat --licenses` instead, or point Flutter at the SDK: `flutter config --android-sdk <path>`.

**Every `flutter` command hangs ("Waiting for another flutter command to release the startup lock")**
- **Cause:** another Flutter process holds the lock. Usually it's a VS Code debug session stuck on the emulator.
- **Fix:** stop the debug session (or restart the emulator), and the commands go through.
- **Workaround for read-only commands** such as `analyze` and `test`: set `FLUTTER_ALREADY_LOCKED=true`.

**I can't build for iPhone on Windows**
- **Cause:** iOS builds need a Mac with Xcode. There is no way around it on Windows.
- **Fix:** use the Android emulator, or open the project on a Mac.

**After switching from demo data to the local API, the app shows the login screen**
- **This is expected.** The token saved in demo mode isn't valid on the real server, so the app signs you out.
- **Fix:** sign in with `211JMT0428` / `CampusPulse2026!`.

**I don't see Administration on the Profile tab**
- **Cause:** only admins see it, and the app reads your role when you sign in (or when it starts).
- **Fix:** sign in as `admin@campus.test` / `CampusPulseAdmin2026!` (after `npm run seed`). If an admin has just promoted you, sign out and in again.

**There's no Timetable tab**
- **This is expected for admins, alumni and companies.** They follow no classes, so they get four tabs and no class sections on Home. The API refuses them the timetable and courses (403).
- **Fix:** if the account should have classes, an admin changes its role to Student or Teacher. The user then signs out and in again.

**An admin screen says "Only administrators can do this."**
- **Cause:** the API checks the role on every request. Your account isn't an admin any more (another admin changed it), or the app is pointed at a different database.
- **Fix:** sign out and in again; ask another admin, or run `npm run create-admin`.

**Hot reload doesn't show my new screen or route**
- **Cause:** route and provider changes need a **hot restart**.
- **Fix:** press Ctrl+Shift+F5 in VS Code, or `R` in the terminal.

**After adding a package, the app crashes with `MissingPluginException`**
- **Cause:** the package has native code, and a hot restart doesn't rebuild it.
- **Fix:** stop the app and run it again.

**"WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): file_picker, firebase_core"**
- **This is expected and harmless.** Flutter flags these plugins because their build files mention Kotlin. `firebase_core` applies Kotlin itself when `android.builtInKotlin=false`.
- **Background:** `file_picker` 11 doesn't compile its Kotlin code on Android Gradle Plugin 9 when `android.builtInKotlin=false`. The build then failed with *"cannot find symbol FilePickerPlugin"*. `android/build.gradle.kts` applies Kotlin to it, so it builds.
- **Why not upgrade:** `file_picker` 13 needs `win32` 6, and `flutter_secure_storage` 9 still needs `win32` 5. Upgrade both together, then remove the block from `android/build.gradle.kts`.

## Connecting the app to the API

**With the APK, the first sign-in takes up to a minute, or class reminders don't arrive**
- **Cause:** the online API (Render free plan) went to sleep after 15 minutes without requests. It wakes on the next one, slowly, and sends no reminders while asleep.
- **Fix:** the UptimeRobot monitor keeps it awake ([deploy.md](deploy.md#the-free-plan-sleeps-uptimerobot-keeps-it-awake)). Check it still shows **Up**, and that Render's free hours aren't used up for the month.

**The app can't reach the API from the emulator**
- **Check the API:** it must be running (`curl http://127.0.0.1:3000/api/health`).
- **Check the configuration:** use `env/local.json`, with `USE_MOCK=false` and `API_BASE_URL=http://10.0.2.2:3000/api`. `10.0.2.2` is how the emulator reaches your PC.

**The app can't reach the API from a real phone**
- **Fix:**
  1. Set `HOST=0.0.0.0` in `backend/.env` and restart the API.
  2. Use your PC's IP address in `API_BASE_URL`.
  3. Allow Node through the Windows firewall.
  4. Put the phone and the PC on the same Wi-Fi.

**Rides say "yesterday", notifications are days old**
- **Cause:** demo dates are computed when the seed runs.
- **Fix:** run `cd backend && npm run seed` again.

**"You already applied" / a seat is already booked in the demo**
- **Fix:** `npm run seed` resets the demo student's own actions.

**I asked for a password reset but never got the email**
- **Cause:** without `SMTP_HOST` (or `MAIL_RELAY_URL`), emails are not sent. The code is printed in the backend terminal: `[mail] Password reset code for …: 123456`. (Sign-up sends no email at all: a new account is signed in at once.)
- **Fix:** read the code there, or configure SMTP in `backend/.env`.

## Push notifications

**No push arrives on the phone.** Check in this order:
1. **The app:** does the debug console say `[push] Off: no Firebase configuration`? Then `android/app/google-services.json` is missing. Add it, then **stop and run the app again**: a hot restart doesn't rebuild the Android part.
2. **The API:** does it log `[push] Off: set FIREBASE_SERVICE_ACCOUNT_FILE…` at start? Then set that key in `backend/.env` and restart the API.
3. **The permission:** you may have refused it. Turn it on in **Settings › Apps › CampusPulse › Notifications**, then sign out and in again.
4. **Test:** run `npm run push:test -- <your email or ENT ID>`. "No registered device" means the phone never registered: sign out and in again, and watch the debug console for `[push]` lines.
5. **On an emulator**, the system image must include Google APIs (ours, `google_apis`, does).

**No class reminder arrives.**
- **Check the account:** reminders go to students and teachers only, never to admins, alumni or companies.
- **Check the timing:** they go out 15 minutes before a session of today's timetable (campus time, UTC+1), only while the API runs with push on. At start it logs `[push] Class reminders on`.
- **Check the channel:** you may have muted **Class reminders** in Android's settings for CampusPulse.
- **Test now:** `npm run push:test -- <you> --class` sends the next one.

**The app is open and no notification pops up.** This is expected. Android doesn't show pushes for the app on screen, so CampusPulse shows a banner with **View** instead.

**`flutter run` fails with "File google-services.json is missing".** The plugin is applied only when the file exists, so this means an old build. Run `flutter clean`, then run again.

## Backend

**The server exits at start with "Invalid environment variables"**
- **Cause:** `backend/.env` is missing a required value. Usually `JWT_ACCESS_SECRET` is missing or shorter than 32 characters.
- **Fix:** copy `.env.example` again and generate a secret (see [getting started](getting-started.md#4-run-the-backend)).

**"MongooseServerSelectionError" / ECONNREFUSED 127.0.0.1:27017**
- **Cause:** MongoDB isn't running.
- **Fix:** start the MongoDB service, or run `docker compose up -d` in `backend/`.

**"EADDRINUSE: address already in use :::3000"**
- **Cause:** another API instance is still running.
- **Fix:** stop it (Ctrl+C in its terminal, or end the `node` process), or change `PORT`.

**"Missing required sub-document 'driver' in the client metadata document" in Jest**
- **Cause:** the MongoDB driver loads Node's `os` module with a dynamic `import()`, which fails inside Jest's sandbox.
- **Already handled:** `connectMongo()` (`src/db/mongo.ts`) passes `runtimeAdapters: { os }`. Always connect through `connectMongo()`, including in tests (`connectTestDb()` does).

**ts-jest complains about the TypeScript version**
- **Cause:** ts-jest supports TypeScript below 7 only.
- **Fix:** keep `typescript` pinned to `^6` in `backend/package.json`.

**Two test runs interfere with each other**
- **Cause:** test runs at the same moment share a test database.
- **Fix:** give each a different `TEST_DB_PREFIX`, e.g. `TEST_DB_PREFIX=cp_me npx jest`.

**Many suites fail at once with a timeout in `beforeAll(connectTestDb)`**
- **Cause:** the PC is busy (a `flutter test` or a build at the same time), and connecting to MongoDB takes longer than the hook allows.
- **Fix:** run with fewer workers, `npx jest --maxWorkers=4`, or wait until the other job ends.

## Tests (app)

**A widget test fails with "A RenderFlex overflowed by N pixels"**
- **Cause:** a real layout bug on narrow screens or large fonts, often a `Row` holding long text or buttons.
- **Fix:** use `Expanded`/`Flexible` + ellipsis, or `Wrap`.

**A test passes today but fails tomorrow**
- **Cause:** it uses `DateTime.now()`.
- **Fix:** pass a fixed date, or override `clockProvider` and the repositories' `clock`.

**Google Fonts errors in widget tests**
- **Fix:** use a plain `ThemeData` in tests, not `AppTheme` (see [contributing](contributing.md#writing-widget-tests)).
