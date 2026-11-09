# How to run CampusPulse

The short version: the exact steps and commands to get the app running on your machine. For explanations, see [getting-started.md](getting-started.md). When something breaks, check [troubleshooting.md](troubleshooting.md).

**Just want the app on your phone?** Download the latest APK from the repository's **Releases** page on GitHub. It uses the online API, so no setup is needed. The install steps are in [deploy.md](deploy.md#installing-it-for-teammates).

To work on the code, there are three ways to run it. Start with **A**: it takes two minutes and needs no server.

| | What you get | Needs |
|---|---|---|
| **A. Demo data** | Every screen, with built-in fake data | Flutter and an emulator |
| **B. Real API** | Real accounts, data saved in MongoDB, admin screens on real users | A + Node.js + MongoDB |
| **C. Push notifications** | Notifications on the phone, class reminders | B + the two Firebase files (ask Raed) |

---

## 0. Once per machine

Install these (Windows commands; macOS works the same):

| Tool | Version | Check with |
|---|---|---|
| Git | any | `git --version` |
| Flutter SDK | 3.27+ (we use 3.47) | `flutter --version` |
| Android Studio, for the Android SDK and emulator | recent | `flutter doctor` |
| VS Code with the **Flutter** extension | recent | — |
| Node.js (only for B and C) | 20+ (we use 22) | `node --version` |
| MongoDB Community Server (only for B and C), or Docker Desktop | 7+ (we use 8) | the **MongoDB** service runs (Windows *Services* app), or `docker ps` |

**On Windows**, once:
1. Accept the Android licenses: `flutter doctor --android-licenses`, answering `y` each time.
2. Turn on **Developer Mode**: run `start ms-settings:developers` and switch it on.
3. Turn on **Windows Hypervisor Platform** in "Turn Windows features on or off", then reboot.
4. In Android Studio's **Device Manager**, create a **Pixel** emulator with a recent **Google APIs** x86_64 image. Google APIs is needed for push notifications.
5. Run `flutter doctor`. Every line you need (Flutter, Android toolchain, VS Code) should be ✓.

Steps 2 and 3 need administrator rights.

---

## 1. Get the code

```bash
git clone https://github.com/doniesgh/campuslink_mobile.git
cd campuslink_mobile
flutter pub get
```

---

## A. Run with demo data (no server)

1. Open the `campuslink_mobile` folder in VS Code.
2. Start the emulator: click the device name in the bottom-right corner and pick your Pixel. Wait for the Android home screen. The first boot is slow.
3. Open the **Run and Debug** panel, choose **"CampusPulse (dev, mock data)"** and press **F5**. From a terminal instead:
   ```bash
   flutter run --dart-define-from-file=env/dev.json
   ```
4. Sign in with **any** ENT ID and password, e.g. `211JMT0428` / `password`. An identifier containing "admin" (e.g. `admin@campus.test`) signs you in as an admin.

Done. Nothing you do is saved: the demo data resets when the app restarts.

---

## B. Run with the real API

### First time

**1. Start MongoDB.** If you installed MongoDB Community Server, it already runs as a Windows service. Otherwise, with Docker:
```bash
cd backend
docker compose up -d
```

**2. Install and configure the API:**
```bash
cd backend
npm install
copy .env.example .env          # macOS / Git Bash: cp .env.example .env
```
Open `backend/.env` and replace the `JWT_ACCESS_SECRET` value with a long random string. This prints one:
```bash
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
```

**3. Load the demo data:**
```bash
npm run seed
```

### Every time

**1. Start the API** in its own terminal, and keep it open:
```bash
cd backend
npm run dev
```
Wait for `CampusPulse API listening on http://127.0.0.1:3000/api`. It restarts by itself when you save a backend file.

**2. Run the app** with **"CampusPulse (local backend)"** and **F5**. From a terminal instead:
```bash
flutter run --dart-define-from-file=env/local.json
```

**3. Sign in** with a demo account:

| Account | Sign in with | Password | Sees |
|---|---|---|---|
| Student | `211JMT0428` | `CampusPulse2026!` | everything: timetable, courses, grades, rides, jobs… |
| Admin | `admin@campus.test` | `CampusPulseAdmin2026!` | Administration (Profile tab, and a card on Home); no timetable |
| Teacher | `amira.bensalah@campus.test` | `CampusPulse2026!` | the timetable, no student card |
| Alumni | `selim.rekik@campus.test` | `CampusPulse2026!` | no timetable |

Run `npm run seed` again whenever you want the demo data fresh: today's rides, recent notifications, and none of your test changes.

> **The emulator reaches your PC as `10.0.2.2`.** Leave `API_BASE_URL` in `env/local.json` as `http://10.0.2.2:3000/api`. With `127.0.0.1` or a typo, every request fails with **"No internet connection"**.

---

## C. Turn on push notifications

Push needs our Firebase project. Its two key files are **not in Git**, because they hold keys. **Ask Raed for them** and never commit them.

1. Put **`google-services.json`** in **`android/app/`**.
2. Put **`firebase-service-account.json`** in **`backend/`**, and add this line to `backend/.env`:
   ```
   FIREBASE_SERVICE_ACCOUNT_FILE=firebase-service-account.json
   ```
3. **Restart the API** (Ctrl+C, then `npm run dev`). It must log `[push] On: sending through the Firebase project com-example-campuspulse.`
4. **Stop the app and run it again.** A hot restart isn't enough when native files change.
5. Sign in as `211JMT0428`, and tap **Allow** when Android asks about notifications.
6. Put the app in the background (Home button) and send a test:
   ```bash
   cd backend
   npm run push:test -- 211JMT0428            # a "Push test" notification
   npm run push:test -- 211JMT0428 --class    # the reminder of your next class
   ```
   The notification appears on the emulator. Tap it to open the app on the right screen.

With push on, **class reminders** go out by themselves while the API runs: 15 minutes before each class, to students and teachers.

---

## Everyday commands

| I want to… | Run |
|---|---|
| Run the app (demo data) | F5 with **"CampusPulse (dev, mock data)"** |
| Run the app (real API) | `cd backend && npm run dev`, then F5 with **"CampusPulse (local backend)"** |
| See a code change | Save the file (hot reload). For new routes or providers: **Ctrl+Shift+F5** (hot restart) |
| Pick up a new package, an `env/*.json` change or the Firebase file | **Stop the app and run it again** |
| Reset the demo data | `cd backend && npm run seed` |
| Make someone an admin | `cd backend && npm run create-admin -- <email> <password>` |
| Check my work before pushing | `flutter analyze` and `flutter test`; for the API, `cd backend && npm run typecheck && npm test` |

If `npm test` fails with many timeouts in `beforeAll`, your PC is busy: run `npx jest --maxWorkers=4`.

---

## On a real Android phone

1. On the phone, turn on **Developer options › USB debugging**, then plug it in. It appears in VS Code's device list.
2. With the cable, the simplest is to forward the API port. Run `adb reverse tcp:3000 tcp:3000` (again after each reconnection), and use a copy of `env/local.json` with `"API_BASE_URL": "http://127.0.0.1:3000/api"`. `adb` is in the Android SDK's `platform-tools` folder, by default `%LOCALAPPDATA%\Android\Sdk\platform-tools` on Windows.
3. Over Wi-Fi instead, see [getting-started.md](getting-started.md#5-run-the-app-against-the-backend) (`HOST=0.0.0.0` and your PC's IP address).

iPhone apps can only be built on a Mac with Xcode.

---

## If it doesn't work

| You see | Do this |
|---|---|
| **"No internet connection"** at sign-in | Is `npm run dev` running? Does `env/local.json` say `http://10.0.2.2:3000/api`? After editing it, stop and run the app again |
| **"Emulator didn't connect within 60 seconds"** | Wait for the Android home screen, then press F5 again |
| Every `flutter` command hangs on **"Waiting for another flutter command to release the startup lock"** | Stop the running debug session (red square in VS Code) |
| **`MissingPluginException`** | A package was added: stop the app and run it again |
| The API exits with **"Invalid environment variables"** | `backend/.env` is missing, or `JWT_ACCESS_SECRET` is shorter than 32 characters |
| **`ECONNREFUSED 127.0.0.1:27017`** | MongoDB isn't running: start the service, or `docker compose up -d` in `backend/` |
| **"WARNING: … plugins that apply Kotlin Gradle Plugin: file_picker, firebase_core"** | Harmless, ignore it |
| No push notification | See [troubleshooting.md › Push notifications](troubleshooting.md#push-notifications) |

Everything else is in [troubleshooting.md](troubleshooting.md).
