# Kinex

Kinex is a physiotherapy rehabilitation app. Clinics manage their physiotherapists and patients, physiotherapists assign exercises and follow progress, and patients do their exercises at home — following a video, reporting their reps and pain level, and (with a clinic subscription) recording themselves for AI pose analysis.

The project has two parts:

| Part | Technology | Location |
|---|---|---|
| Mobile app | Flutter (Dart) | `lib/` |
| Backend API | PHP 8 + MySQL, served by WAMP (Apache) | `reed/` |

The app talks to the backend over HTTP. In development, the backend runs on your Windows PC with WampServer and the app runs on an Android phone connected by USB.

---

## ⚡ Quick Start for Hosting & Running (Friend's Setup Guide)

### 📦 Option 1: Docker (Fastest — 1 Command)
If you have **Docker Desktop** installed, start everything with:
```bash
docker compose up -d
```
This automatically runs:
* **MySQL 8.0** on port `3306` with the complete database (`database/physio_clinic.sql`) pre-imported.
* **PHP 8.3 + Apache** backend serving `http://localhost/reed/` on port 80.
* **phpMyAdmin** on `http://localhost:8081` (Username: `root`, password empty).

---

### 💻 Option 2: Local Server (WAMP / XAMPP / Laragon)
1. **Import the Database:**
   * Open phpMyAdmin (`http://localhost/phpmyadmin`).
   * Create database **`physio_clinic`** with collation **`utf8mb4_0900_ai_ci`**.
   * Import [`database/physio_clinic.sql`](./database/physio_clinic.sql).
2. **Deploy the PHP API:**
   * Copy the `reed/` folder to your web server document root:
     * WAMP: `C:\wamp64\www\reed\`
     * XAMPP: `C:\xampp\htdocs\reed\`
     * Linux/Mac Apache: `/var/www/html/reed/`
3. **Database Credentials:**
   * `reed/db.php` defaults to `localhost`, user `root`, no password, port `3306`.
   * If your MySQL port differs (e.g. 3308), copy `reed/db.local.example.php` to `reed/db.local.php` and specify `$port = 3308;`.

---

### 🚀 Option 3: PHP Built-in Server (Zero Installation)
If you have PHP installed:
```bash
cd reed
php -S 0.0.0.0:80
```
Make sure MySQL is running on `localhost:3306` with `physio_clinic` imported.

---

### 📱 Launching the Flutter App

1. **Install Flutter packages:**
   ```bash
   flutter pub get
   ```
2. **Run on your device / emulator:**
   * **Android over USB (with ADB tunnel):**
     ```bash
     adb reverse tcp:8080 tcp:80
     flutter run
     ```
   * **Over Wi-Fi / Custom IP (Phone and PC on same network):**
     ```bash
     flutter run --dart-define=SERVER_URL=http://<YOUR_PC_IP>/reed/
     ```
   * **Windows Desktop Program:**
     ```bash
     flutter run -d windows
     ```

---

### 🔑 Pre-Configured Test Accounts & Logins
The database in `database/physio_clinic.sql` comes with active demo accounts ready for testing:

| Role | Email | Password |
|---|---|---|
| **Patient** | `ouissal@gmail.com` or `patient1@gmail.com` | `123456` |
| **Physiotherapist** | `sirine@gmail.com` or `physio2@gmail.com` | `123456` |
| **Clinic** | `clinicouissal@gmail.com` or `clinique1@gmail.com` | `123456` |
| **Admin** | `admin2@gmail.com` or `admin1@gmail.com` | `123456` |

*(To create a fresh Admin: run `POST http://localhost/reed/seed_admin_account.php` with `seed_key=kinex-admin-seed-2026`, `email=admin@kinex.app`, `password=Admin@123`)*

---

## Contents

1. [What to download and install](#1-what-to-download-and-install)
2. [Get the project](#2-get-the-project)
3. [Set up the backend (WAMP + database)](#3-set-up-the-backend-wamp--database)
4. [Set up Flutter](#4-set-up-flutter)
5. [Prepare the Android phone](#5-prepare-the-android-phone)
6. [Run the app on the phone](#6-run-the-app-on-the-phone)
7. [Using the app](#7-using-the-app)
8. [Other ways to run it](#8-other-ways-to-run-it)
9. [Troubleshooting](#9-troubleshooting)
10. [Project structure](#10-project-structure)

---

## 1. What to download and install

Everything below is for **Windows 10/11 (64-bit)**.

| # | Software | Version used | Why | Download |
|---|---|---|---|---|
| 1 | **WampServer 64-bit** | 3.3.x (Apache 2.4, PHP 8.3, MySQL 9.1) | Runs the PHP backend and the MySQL database | https://www.wampserver.com/en/ |
| 2 | **Visual C++ Redistributables** (all of them, x86 and x64) | latest | Required by WampServer — install **before** WAMP | Linked from the WampServer download page |
| 3 | **Git** | any recent | Clone the repository | https://git-scm.com/download/win |
| 4 | **Flutter SDK** (stable channel) | 3.47.x (Dart 3.13) — the project needs Dart ≥ 3.11 | Builds the app | https://docs.flutter.dev/get-started/install/windows |
| 5 | **Android Studio** | latest | Provides the Android SDK, platform-tools (`adb`) and build tools | https://developer.android.com/studio |
| 6 | **Java JDK 21** | 21 (LTS) | Gradle 8.14 (used by this project) **does not run on Java 25**, which recent Android Studio versions bundle | https://adoptium.net/temurin/releases/?version=21 |
| 7 | **VS Code** + the *Flutter* extension *(optional)* | latest | Editing and running the app | https://code.visualstudio.com |
| 8 | **Samsung USB driver** *(Samsung phones only, if the phone isn't detected)* | latest | Lets Windows talk to the phone over `adb` | https://developer.samsung.com/android-usb-driver |

Only needed if you also want to run the app as a **Windows desktop** program (not required for the phone):

| Software | Why |
|---|---|
| **Visual Studio 2022** (or Build Tools) with the *Desktop development with C++* workload | Compiles the Windows runner |
| **NuGet CLI** — `winget install Microsoft.NuGet` | Needed by the `flutter_inappwebview_windows` plugin |

You also need a **USB data cable** and an **Android phone running Android 5.0 (API 21) or newer**. The project has been tested on a Samsung Galaxy A21s (Android 12).

---

## 2. Get the project

```powershell
git clone https://github.com/Akram-Seghiri/Kinex.git
cd Kinex
```

---

## 3. Set up the backend (WAMP + database)

### 3.1 Install and start WampServer

1. Install the Visual C++ Redistributables, then WampServer 64-bit (default folder `C:\wamp64`).
2. Start WampServer. Wait until its tray icon turns **green** (Apache and MySQL both running).
3. Check it works: open http://localhost in a browser — you should see the WampServer home page.

Make sure WAMP uses **PHP 8.x** (tray icon → *PHP* → *Version*). This project was tested with **PHP 8.3** and **MySQL 9.1** on port **3306**.

### 3.2 Copy the backend into WAMP

Apache serves files from `C:\wamp64\www`. The app expects the API at `http://<server>/reed/`, so copy the project's `reed` folder there:

```powershell
robocopy .\reed C:\wamp64\www\reed /E
```

You should now have `C:\wamp64\www\reed\login.php`, etc.

> **Important:** `C:\wamp64\www\reed` is a **copy**. Every time you change or pull PHP files in the project, run the `robocopy` command again, otherwise the server keeps running the old code.

### 3.3 Create the database

1. Open **phpMyAdmin**: http://localhost/phpmyadmin (user `root`, empty password, server *MySQL*).
2. Click **New**, create a database named **`physio_clinic`** with collation **`utf8mb4_0900_ai_ci`**.
3. Select it → **Import** → choose `reed/physio_clinic.sql` → **Import**.

This creates all tables (`account`, `clinic`, `physiotherapist`, `patient`, `exercise`, `patientexercise`, `progressreport`, `aifeedback`, `message`, `complaintform`, `subscription`) plus a few demo exercises.

> Importing `physio_clinic.sql` **drops and recreates** every table. Don't re-import it on a database that holds data you want to keep.

### 3.4 Configure the database connection

The backend reads its connection settings from `reed/db.php`. If the file is missing, create `C:\wamp64\www\reed\db.php` (and `reed/db.php` in the project) with:

```php
<?php
$servername = "localhost";
$username = "root";
$password = "";              // WAMP's default root password is empty
$dbname = "physio_clinic";

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}
?>
```

Change `$username` / `$password` if your MySQL root account has a password.

### 3.5 Create the first admin account

Only an admin can approve new clinics, so create one. In PowerShell:

```powershell
Invoke-RestMethod -Method POST -Uri http://localhost/reed/seed_admin_account.php `
  -Body @{ seed_key = 'kinex-admin-seed-2026'; email = 'admin@kinex.app'; password = 'Admin@123' }
```

Expected answer: `"message": "Admin account created"`. Use your own email/password if you like (the password must be typed as plain text when logging in — the database only stores its hash).

### 3.6 Check the API

```powershell
Invoke-RestMethod -Method POST -Uri http://localhost/reed/login.php -Body @{ email = 'admin@kinex.app'; password = 'Admin@123' }
```

You should get `"message": "Login successful"` and `"role": "admin"`. If you do, the backend and database are ready.

### 3.7 (Optional) Larger video uploads

Patients upload exercise videos for AI feedback. WAMP's default PHP limits are small (`upload_max_filesize = 2M`, `post_max_size = 8M`). To allow longer videos, open tray icon → *PHP* → *php.ini* and set, for example:

```ini
upload_max_filesize = 64M
post_max_size = 64M
```

then tray icon → *Restart All Services*.

### 3.8 (Optional) Stripe payments

Clinic subscriptions are paid through Stripe Checkout in **test mode**. Keys are read from `reed/stripe_config.php`, or from the environment variables `STRIPE_SECRET_KEY` and `STRIPE_PUBLISHABLE_KEY`. Get test keys from https://dashboard.stripe.com/test/apikeys. Use test card `4242 4242 4242 4242`, any future date, any CVC.

Pricing (in `create_subscription.php`): monthly = 5 + 0.1 × number of patients; yearly = 50 + 0.1 × number of patients (currency set by `STRIPE_CURRENCY`, default EUR).

---

## 4. Set up Flutter

### 4.1 Install Flutter and Android tools

1. Extract the Flutter SDK, e.g. to `C:\src\flutter`, and add `C:\src\flutter\bin` to your **PATH**.
2. Install **Android Studio**, open it once and let it install the Android SDK. Then in *More Actions → SDK Manager*:
   - *SDK Platforms*: install the latest Android version.
   - *SDK Tools*: tick **Android SDK Command-line Tools**, **Android SDK Platform-Tools**, **Android SDK Build-Tools**.
3. Accept the Android licenses:
   ```powershell
   flutter doctor --android-licenses
   ```

### 4.2 Use JDK 21

Recent Android Studio versions bundle **Java 25**, which makes the Android build fail with a message that is just `25.0.x`. Point Flutter at JDK 21 instead:

```powershell
flutter config --jdk-dir="C:\Program Files\Java\jdk-21"
```

(Adjust the path to where JDK 21 is installed, e.g. `C:\Program Files\Eclipse Adoptium\jdk-21...`.)

### 4.3 Check everything

```powershell
flutter doctor -v
```

You want green ticks for **Flutter** and **Android toolchain**, and the *Java version* line should say **21**. (*Visual Studio* only matters for the Windows desktop build; *Chrome* is not needed.)

### 4.4 Get the app's packages

From the project folder:

```powershell
flutter pub get
```

---

## 5. Prepare the Android phone

### 5.1 Turn on USB debugging (once per phone)

1. **Settings → About phone → Software information** → tap **Build number** **7 times** until it says *Developer mode has been turned on*.
   (On non-Samsung phones *Build number* is usually directly under *About phone*.)
2. **Settings → Developer options** → turn on **USB debugging**.
3. Connect the phone with a USB **data** cable. On the phone, accept **"Allow USB debugging?"** (tick *Always allow from this computer*).

> A phone that only shows up in File Explorer (e.g. *This PC → Galaxy A21s → Internal storage*) is in file-transfer mode only. Flutter can't use it until USB debugging is on.

### 5.2 Check the phone is detected

```powershell
flutter devices
```

You should see a line like:

```
SM A217F (mobile) • RF8R70RZM2W • android-arm64 • Android 12 (API 31)
```

The second column is the **device ID**.

---

## 6. Run the app on the phone

### 6.1 How the phone reaches the server

On the phone, `localhost` means the phone itself, not your PC. Kinex solves this with an **ADB reverse tunnel** over the USB cable: the phone's address `127.0.0.1:8080` is forwarded to port 80 on your PC, where WAMP is listening. No firewall or WAMP network changes are needed.

The app picks the server address automatically (`lib/config.dart`):

| Platform | Server address used |
|---|---|
| Android | `http://127.0.0.1:8080/reed/` (through the USB tunnel) |
| Windows / web | `http://localhost/reed/` |
| Any, with `--dart-define=SERVER_URL=...` | the URL you pass |

(Port 8080 is used on the phone because Android doesn't allow normal apps to use ports below 1024.)

### 6.2 Start it

With WAMP green and the phone plugged in:

```powershell
# 1. Open the tunnel (repeat every time you re-plug the phone)
adb reverse tcp:8080 tcp:80

# 2. Build, install and launch the app
flutter run -d <device-id>        # e.g. flutter run -d RF8R70RZM2W
```

If `adb` isn't recognised, use its full path: `"$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:8080 tcp:80`, or add that folder to your PATH.

The **first build takes several minutes** (Gradle downloads its dependencies, including Google ML Kit). Later builds are much faster. When you see `Flutter run key commands.`, the app is open on the phone. While it runs, press `r` for hot reload, `R` for hot restart, `q` to quit.

The app stays installed on the phone as **Kinex**. You can reopen it from the phone's app drawer later — just make sure WAMP is running and the tunnel is open (`adb reverse tcp:8080 tcp:80`) whenever the phone is reconnected.

### 6.3 Install a standalone APK (optional)

```powershell
flutter build apk --release
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

---

## 7. Using the app

### 7.1 Roles and how accounts are created

| Role | How the account is created | Main screens |
|---|---|---|
| **Admin** | `seed_admin_account.php` (section 3.5) | Approve/reject clinics, manage accounts |
| **Clinic** | Self sign-up in the app, then approved by an admin | Dashboard, register physios & patients, subscription, complaints |
| **Physiotherapist** | Created by their clinic | Patient list, assign exercises, follow progress, messages, AI feedback |
| **Patient** | Created by their clinic (and assigned a physiotherapist) | Today's exercises, video + progress reports, messages, profile |

Only clinics can sign up directly. Physiotherapists and patients **cannot** register themselves; their clinic creates them and gives them their email and password.

### 7.2 First-time walkthrough

1. **Open Kinex.** Swipe through the introduction screens to reach the login screen.
2. **Register a clinic.** Tap **Register your clinic**, fill in the clinic name, email, password, address and phone, and attach a justification document (PDF or image, max 8 MB). Submit. The account is created but **inactive** — logging in now shows *"Waiting for approval"*.
3. **Approve the clinic.** Log in as the **admin**, open the pending clinics list, view the justification document and tap **Approve**. Log out.
4. **Log in as the clinic.** From the clinic dashboard:
   - **Register a physiotherapist** (name, email, password, specialization, phone).
   - **Register a patient** (name, email, password, phone, birth date) and **assign** them to a physiotherapist.
   - **Subscribe** (monthly or yearly) to unlock premium features (video recording + AI feedback) for the clinic's patients and physiotherapists. Payment opens Stripe Checkout in the browser.
5. **Log in as the physiotherapist.** Open a patient and **assign exercises** from the exercise catalogue, choosing sets and reps. You can follow the patient's completion, reports and pain levels, read AI feedback (premium) and **message** the patient.
6. **Log in as the patient.**
   - The **home** tab lists the assigned exercises (filter: today / all / completed) and a weekly completion chart.
   - Open an exercise to watch its **YouTube video** and instructions.
   - After doing it, **submit a progress report**: reps done, pain level (1–10) and notes. The exercise is marked completed.
   - **Premium:** record yourself with the phone camera. The app runs **Google ML Kit pose detection** on the phone, then uploads the video and the analysis so the physiotherapist can review it.
   - **Messages:** chat with your assigned physiotherapist.
   - **Profile:** update name, phone, password and profile photo, and see your physiotherapist.
   - **Complaint form:** report symptoms or problems to the clinic and physiotherapist.

### 7.3 Adding exercises to the catalogue

There is no "add exercise" screen. Add rows to the `exercise` table in phpMyAdmin (or SQL). The catalogue is shared — every physiotherapist can assign every exercise.

```sql
INSERT INTO exercise (therapist_id, name, description, video_url, difficulty)
VALUES (2, 'Standing Hip Abduction',
        'Stand upright and slowly lift one leg out to the side, then return.',
        'https://www.youtube.com/watch?v=zuPfEhL_2qU', 'Easy');
```

`therapist_id` must be the `id` of an existing row in `physiotherapist`.

---

## 8. Other ways to run it

### Over Wi-Fi (no cable)

1. Find your PC's IPv4 address: `ipconfig` → *Wireless LAN adapter Wi-Fi → IPv4 Address* (e.g. `192.168.1.20`).
2. Allow other devices to reach WAMP: tray icon → **Put Online** (or in `C:\wamp64\bin\apache\apache2.4.x\conf\extra\httpd-vhosts.conf` replace `Require local` with `Require all granted`, then restart Apache).
3. Allow Apache through Windows Firewall on port 80 (private networks).
4. Phone and PC must be on the **same Wi-Fi**. Then:
   ```powershell
   flutter run -d <device-id> --dart-define=SERVER_URL=http://192.168.1.20/reed/
   ```
   The IP can change when you reconnect to Wi-Fi — check `ipconfig` again if the app stops connecting.

### Android emulator

Create an emulator in Android Studio (*Device Manager*), start it, then run `adb reverse tcp:8080 tcp:80` and `flutter run`, exactly as for a phone. (Alternatively: `--dart-define=SERVER_URL=http://10.0.2.2/reed/`.) Camera-based features need a webcam configured for the emulator.

### Windows desktop

```powershell
flutter run -d windows
```

Requires Visual Studio C++ tools and NuGet (see section 1). The app uses `http://localhost/reed/` directly. Camera recording and ML Kit pose detection are **mobile-only** and don't work on Windows.

---

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Phone missing from `flutter devices` | USB debugging off, prompt not accepted, charge-only cable, or missing driver | Section 5.1; try another cable/port; install the Samsung USB driver; run `adb devices` — `unauthorized` means accept the prompt on the phone |
| Android build fails and only prints `25.0.x` | Gradle running on Java 25 | `flutter config --jdk-dir="<path to JDK 21>"`, then `cd android; .\gradlew --stop` and run again |
| *"Unable to reach server"* / timeouts on the phone | Tunnel not open (closes when the phone is unplugged) or WAMP not green | `adb reverse tcp:8080 tcp:80`; check WAMP's tray icon; check `adb reverse --list` shows `tcp:8080 tcp:80` |
| `adb reverse tcp:80 ...` → *cannot bind listener: Permission denied* | Android blocks ports below 1024 | Use `tcp:8080 tcp:80` as documented |
| *Server error 404* on a screen | That PHP file isn't in `C:\wamp64\www\reed` | Re-run the `robocopy` from section 3.2 |
| *"Connection failed"* / database errors | Wrong settings in `db.php`, MySQL stopped, or database not imported | Check `db.php` (section 3.4), WAMP green, `physio_clinic` exists |
| *"Invalid password"* with correct-looking credentials | You typed the stored **hash** (`$2y$10$...`) instead of the password | Type the plain password. Lost it? Create a new admin (3.5) or set a new one from the profile screen |
| *"Waiting for approval"* | Clinic not yet approved | Log in as admin and approve it |
| Video upload fails | PHP upload limit (2 MB by default) | Section 3.7 |
| Windows build: *Nuget is not installed* | NuGet missing | `winget install Microsoft.NuGet`, delete `build\windows`, rebuild |
| A port conflict stops WAMP turning green | Another program uses port 80 or 3306 (IIS, Skype, another MySQL) | Stop that program, or change WAMP's port from the tray menu |

---

## 10. Project structure

```
Kinex/
├── lib/                         Flutter app
│   ├── main.dart                Entry point
│   ├── config.dart              Server address per platform (SERVER_URL override)
│   ├── DB_API.dart              All HTTP calls to the PHP backend
│   ├── login_provider.dart      Riverpod providers (session state)
│   ├── widgets/                 Shared widgets
│   └── features/
│       ├── auth/                Onboarding, login, clinic sign-up
│       ├── admin/               Admin dashboard (clinic approval)
│       ├── clinic/              Clinic dashboard, member registration, complaints
│       ├── therapist/           Physiotherapist home, patients, messages, complaints
│       ├── patient/             Patient home, exercise detail, messages
│       └── shared/              Shared models/helpers
├── reed/                        PHP backend (copy to C:\wamp64\www\reed)
│   ├── api_common.php           Shared helpers: CORS, JSON responses, ID lookups
│   ├── db.php                   MySQL connection settings
│   ├── physio_clinic.sql        Database schema + demo data
│   ├── login.php, signup.php    Authentication / clinic registration
│   ├── get_* / update_* / ...   One endpoint per screen or action
│   ├── stripe_config.php        Stripe keys and return URLs
│   └── uploads/                 Created at runtime: justif/, profiles/, aifeedback/
├── android/  ios/  windows/  macos/  linux/  web/    Platform runners
├── assets/                      Images (app logo Kinex.png, etc.)
└── pubspec.yaml                 Flutter dependencies
```

### Main Flutter packages

`http` (API calls), `flutter_riverpod` (state), `google_mlkit_pose_detection` (on-device pose analysis), `image_picker` / `file_picker` (camera, photos, documents), `youtube_player_iframe` / `youtube_player_flutter` / `video_player` (exercise videos), `flutter_map` + `geolocator` (maps/location), `url_launcher` (Stripe Checkout), `permission_handler` (camera/microphone permissions).

### Notes for developers

- Every API call sends the logged-in user's **account ID** (`account.id`). The backend looks up the patient/physiotherapist row from it with `WHERE account_id = ?`; don't pass `patient.id` or `physiotherapist.id` as `account_id`.
- Android allows plain `http://` traffic because `android:usesCleartextTraffic="true"` is set in `android/app/src/main/AndroidManifest.xml` (needed for the local WAMP server).
- After editing PHP files, copy them to `C:\wamp64\www\reed` again (section 3.2).
