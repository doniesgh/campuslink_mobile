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

**Hot reload doesn't show my new screen or route**
- **Cause:** route and provider changes need a **hot restart**.
- **Fix:** press Ctrl+Shift+F5 in VS Code, or `R` in the terminal.

## Connecting the app to the API

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

**I registered but never got the verification email**
- **Cause:** without `SMTP_HOST`, emails are not sent. The code is printed in the backend terminal: `[mail] Verification code for …: 123456`.
- **Fix:** read the code there, or configure SMTP in `backend/.env`.

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

## Tests (app)

**A widget test fails with "A RenderFlex overflowed by N pixels"**
- **Cause:** a real layout bug on narrow screens or large fonts, often a `Row` holding long text or buttons.
- **Fix:** use `Expanded`/`Flexible` + ellipsis, or `Wrap`.

**A test passes today but fails tomorrow**
- **Cause:** it uses `DateTime.now()`.
- **Fix:** pass a fixed date, or override `clockProvider` and the repositories' `clock`.

**Google Fonts errors in widget tests**
- **Fix:** use a plain `ThemeData` in tests, not `AppTheme` (see [contributing](contributing.md#writing-widget-tests)).
