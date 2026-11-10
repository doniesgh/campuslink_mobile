# Getting started

From a fresh machine to the app running on an emulator, first with demo data and then against the real API. If something goes wrong, check [troubleshooting.md](troubleshooting.md).

Just want the commands? [how-to-run.md](how-to-run.md) is the step-by-step version.

## 1. What you need

| Tool | Version | Needed for |
|---|---|---|
| Git | any recent | cloning |
| Flutter SDK | 3.27 or newer (we use 3.47) | the app |
| Android SDK + emulator | API 34+ image | running the app on Windows or Linux |
| Xcode (macOS only) | recent | running on an iPhone or the iOS simulator |
| VS Code + the **Flutter** and **Dart** extensions | — | recommended editor (launch configurations included) |
| Node.js | 20 or newer (we use 22) | the backend |
| MongoDB | 7 or newer (we use 8), or Docker | the backend's database |

You only need Node and MongoDB if you work on, or with, the backend. The app runs fully on demo data without them.

## 2. Clone and install

```bash
git clone https://github.com/doniesgh/campuslink_mobile.git
cd campuslink_mobile
flutter pub get                 # app dependencies
cd backend && npm install       # backend dependencies (optional)
```

## 3. Run the app with demo data (no server)

1. Start an emulator. In VS Code, click the device name in the bottom-right corner and pick one.
2. Press **F5** with the launch configuration **"CampusPulse (dev, mock data)"**. Or from a terminal:

   ```bash
   flutter run --dart-define-from-file=env/dev.json
   ```

3. Sign in with **any** ENT ID and password, e.g. `211JMT0428` / `password`. To try the admin screens, use an identifier containing "admin", e.g. `admin@campus.test`.

In this mode every screen uses its in-memory demo data (`USE_MOCK=true`). The emulator's first boot can take a while, so if VS Code says "Emulator didn't connect within 60 seconds", wait for the Android home screen and press F5 again.

### Setting up the Android emulator on Windows

If you have never run an Android emulator on this PC:

1. **Install the Android SDK.** Install Android Studio and use its *Device Manager*, or use the command-line tools, then point Flutter at the SDK with `flutter config --android-sdk <path>`.
2. **Accept the Android licenses.** In a terminal, run `flutter doctor --android-licenses` and answer `y` to each. If it says "Unable to locate Android SDK", run `sdkmanager --licenses` from `<sdk>\cmdline-tools\latest\bin` instead.
3. **Turn on Developer Mode.** Run `start ms-settings:developers` and switch it on. Flutter needs it to build apps that use plugins.
4. **Turn on Windows Hypervisor Platform.** Open "Turn Windows features on or off", tick it, and reboot. The emulator needs it for hardware acceleration.
5. **Create an emulator:** a Pixel device with a recent `google_apis` x86_64 image.
6. **Check everything** with `flutter doctor`. The Android toolchain line should be ✓.

Steps 3 and 4 need administrator rights. On a school or work laptop, you may have to ask IT.

**iPhone:** iOS apps can only be built on a Mac with Xcode. Open the project on a Mac and run it on the simulator or a cable-connected iPhone. A free Apple ID is enough for your own device.

## 4. Run the backend

The backend needs a MongoDB on `localhost:27017`. Either install MongoDB Community Server (it runs as a service), or start one with Docker:

```bash
cd backend
docker compose up -d
```

Then:

```bash
cd backend
cp .env.example .env      # Windows PowerShell: copy .env.example .env
```

Open `.env` and set `JWT_ACCESS_SECRET` to a long random string. This command prints one:

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
```

```bash
npm run seed              # demo student + demo data for every screen
npm run dev               # API on http://127.0.0.1:3000/api, restarts when you save
```

Check it works:

```bash
curl http://127.0.0.1:3000/api/health      # {"status":"ok"}
```

## 5. Run the app against the backend

With `npm run dev` running, press **F5** with **"CampusPulse (local backend)"**, or run:

```bash
flutter run --dart-define-from-file=env/local.json
```

Sign in with a demo account:

| Account | ENT ID | Email | Password |
|---|---|---|---|
| Demo student | `211JMT0428` | `dony.mansour@campus.test` | `CampusPulse2026!` |
| Demo admin | — | `admin@campus.test` | `CampusPulseAdmin2026!` |

The admin finds **Administration** on the Profile tab. The seed also creates nine more accounts (teachers, students, an alumnus) so the user list isn't empty; they all use `CampusPulse2026!`.

**An admin on a real server:** there is no default admin outside the demo seed. Create one with `npm run create-admin -- <email> <password> [display name]`; for an existing account, it promotes it to admin, sets the new password and signs it out everywhere.

**Creating your own account:** Register in the app. The verification code is printed in the backend terminal (`[mail] Verification code for …: 042917`), unless you configured SMTP (see below).

**A real phone instead of the emulator:** the emulator reaches your PC as `10.0.2.2`, but a phone on the same Wi-Fi needs your PC's IP address.
1. Set `HOST=0.0.0.0` in `backend/.env` and restart the API.
2. Copy `env/local.json` to `env/phone.json` and set `API_BASE_URL` to `http://<your-PC-IP>:3000/api`.
3. Run with `--dart-define-from-file=env/phone.json`. Windows may ask to allow Node through the firewall.

**Resetting the demo:** `npm run seed` resets the demo student's actions and refreshes dates such as "today 13:15" or "15 min ago". Run it again on another day so the rides and notifications look current.

### Push notifications (optional)

Push notifications need a Firebase project (free). Without one, the app works the same with push off. One person creates the project and shares its two files with the team **privately**. Both files are gitignored because they hold keys.

**Our project already exists** (`com-example-campuspulse`): ask Raed for `google-services.json` and `firebase-service-account.json`, then follow the "C" part of [how-to-run.md](how-to-run.md#c-turn-on-push-notifications). The steps below are for creating a project from scratch.

1. **Create the project** on [console.firebase.google.com](https://console.firebase.google.com) with **Add project**. Analytics isn't needed.
2. **The app's file:**
   - Choose **Add app › Android** with the package name **`com.example.campuspulse`**.
   - Download **`google-services.json`** and put it in **`android/app/`**.
3. **The API's key:**
   - Go to **Project settings › Service accounts › Generate new private key**.
   - Save the file as `backend/firebase-service-account.json`, and add this line to `backend/.env`:
     ```
     FIREBASE_SERVICE_ACCOUNT_FILE=firebase-service-account.json
     ```
   - Restart the API. It no longer logs `[push] Off`.
4. **Stop and run the app again.** A hot restart isn't enough, because the Android build changes. Sign in and **allow notifications**.
5. **Test:** put the app in the background and run `cd backend && npm run push:test -- 211JMT0428`. The notification appears on the phone.

**iPhone (on a Mac):**
- Add an iOS app to the same project with the bundle ID `com.example.campuspulse`, and put its `GoogleService-Info.plist` in `ios/Runner/`.
- Upload an APNs key in **Project settings › Cloud Messaging**.
- In Xcode, add the **Push Notifications** capability and **Background Modes › Remote notifications**.

## 6. Configuration reference

### App: `env/*.json`

| Key | Example | Meaning |
|---|---|---|
| `ENV` | `dev` | `dev` or `prod`. Request logging is off in `prod` |
| `API_BASE_URL` | `http://10.0.2.2:3000/api` | Where the API is |
| `USE_MOCK` | `true` | `true` uses the in-memory demo data; `false` uses the API |

### Backend: `backend/.env`

| Key | Default | Meaning |
|---|---|---|
| `NODE_ENV` | `development` | `development`, `test` or `production` (production makes the rate limits strict) |
| `PORT` / `HOST` | `3000` / `127.0.0.1` | Where the API listens. Use `0.0.0.0` for real phones |
| `MONGO_URL` | `mongodb://127.0.0.1:27017/campuspulse` | Database |
| `JWT_ACCESS_SECRET` | — (required, ≥ 32 chars) | Signs access tokens |
| `ACCESS_TOKEN_TTL_SECONDS` | `900` | Access token lifetime |
| `REFRESH_TOKEN_TTL_DAYS` | `30` | Session lifetime |
| `CORS_ORIGIN` | `*` | Allowed web origins (the mobile app doesn't need CORS) |
| `TRUST_PROXY` | `0` | Proxies in front of the API (`1` on Render). Gives the real client IP to the rate limits and the audit log |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM` | empty / `587` | Real email sending. Leave `SMTP_HOST` empty to print the emails in the console |
| `MAIL_RELAY_URL`, `MAIL_RELAY_SECRET` | empty | Gmail through the Apps Script relay (HTTPS), for Render. Used instead of SMTP when set |
| `FIREBASE_SERVICE_ACCOUNT_FILE` | empty | The Firebase service-account JSON (path from `backend/`). Empty turns push notifications off |

**Sending real emails:** fill in the `SMTP_*` keys and restart, then check them with `npm run mail:test -- <your address>`. Any provider works locally:
- Gmail with an *app password* (`smtp.gmail.com`, port 587). It works on your PC. On Render, whose free plan blocks ports 25, 465 and 587, the same Gmail sends through the Apps Script relay (`MAIL_RELAY_URL`) instead: see [deploy.md](deploy.md#emails-sign-up-codes-and-password-resets).
- Brevo (`smtp-relay.brevo.com`, port 2525), which also works on Render
- Mailtrap, to catch test emails without delivering them

## 7. Everyday commands

| Task | Command |
|---|---|
| Run the app (demo data) | `flutter run --dart-define-from-file=env/dev.json` |
| Run the app (local API) | `flutter run --dart-define-from-file=env/local.json` |
| Hot reload / hot restart | `r` / `R` in the terminal (VS Code: save the file / Ctrl+Shift+F5) |
| App checks | `flutter analyze` and `flutter test` |
| Start the API | `cd backend && npm run dev` |
| Reset the demo data | `cd backend && npm run seed` |
| Create or promote an admin | `cd backend && npm run create-admin -- <email> <password>` |
| Test the email settings | `cd backend && npm run mail:test -- <your address>` |
| Send a test push notification | `cd backend && npm run push:test -- <email or ENT ID>` |
| Preview a class reminder | `cd backend && npm run push:test -- <email or ENT ID> --class` |
| Backend checks | `cd backend && npm run typecheck && npm test` |
| Build a debug APK | `flutter build apk --debug --dart-define-from-file=env/dev.json` |

Next: [architecture.md](architecture.md) explains how the code is organised, and [contributing.md](contributing.md) explains how to add to it.
