# Notifications

In-app notification center for patients and physiotherapists. Every notification is a row in the database,
created by the backend when the event happens (or by the daily job). The app shows them on a Notifications page,
with an unread badge on the bell.

**What this is not:** there are no phone (OS) push notifications. The app has no Firebase / FCM setup, so nothing
reaches a phone whose app is closed. While the app is open, the bell polls the server every 30 s (and when the app
comes back to the foreground). See "Limitations".

## What triggers a notification

| Type | Who gets it | When | Opens |
|---|---|---|---|
| `message` | the receiver (never the sender) | a message is sent (`send_patient_message.php`, `send_physio_message.php`) | the conversation |
| `routine_update` | the patient | the physiotherapist assigns an exercise (`assign_patient_exercise.php`) | the exercise (or "no longer available") |
| `inactivity` | the physiotherapist | the daily job: the patient had exercises due that day and recorded none | day details, then the patient's file or a message |
| `incorrect_reps` | the physiotherapist | a live camera set with at least 8 confidently judged reps, of which at least 90 % are incorrect | set details, then the patient's file or a message |
| `pain_report` (urgent) | the physiotherapist | pain reported during a live set (voice or button), or a pain rating of 4/10 or more (after a set, or in the manual progress form) | the report, then the patient's file or a message |

Details:

- **Messages:** the notification keeps the sender's name and the first 80 characters, on one line. Opening the
  conversation marks that conversation's notifications as read.
- **Inactivity:** a day is checked only once it is over (the job runs at 00:15 for the day before), in the clinic
  time zone. An exercise was due that day if it was assigned *before* that day and not finished before it: still
  pending, or completed by progress recorded on that day or later. `patientexercise` only keeps the current status,
  so the day it was finished is taken from its last progress report. Nothing is sent if nothing was due. Any progress with at least 1 rep that day counts as activity. When the patient
  exercises again, the open alert is marked **Resolved**; the missed day stays listed.
- **Incorrect reps:** only the reps the assistant judged with confidence count (good + mistakes). Reps it could not
  judge reliably ("not sure") are left out of the threshold, and the detail page says how many there were. So an alert
  means confirmed mistakes, not bad tracking. The thresholds are `KINEX_INCORRECT_SHARE` (0.9) and
  `KINEX_INCORRECT_MIN_REPS` (8) in `reed/notifications_lib.php`.
- **Pain:** the alert shows what the patient reported: when in the set, by voice or button, their words, and the
  rating if given. It is labelled as the patient's own report, not a medical finding. A rating given after a set is
  added to the same alert. The level threshold is `KINEX_PAIN_ALERT_LEVEL` (4).
- **Messages from a notification:** "Message patient" opens the conversation with a suggested text already typed.
  It is sent only if the physiotherapist presses Send.

## Settings (physiotherapist)

The gear icon on the physiotherapist's Notifications page turns each type on or off: pain reports, mostly incorrect
repetitions, no exercise done, and messages. Turning pain alerts off asks for confirmation first. The setting is saved
on the server (`notification_pref`, no row = on), and `notify()` checks it. A type that is off is not stored at all,
so turning it back on does not bring back what happened meanwhile. API: `GET ?action=prefs`,
`POST action=set_pref&type=…&enabled=0|1`. Only the types of the caller's role can be changed.

## No duplicates

Each notification has a key that is unique per recipient (`UNIQUE (recipient_account_id, dedup_key)`, inserted with
`INSERT IGNORE`):

- `msg:<message id>`
- `routine:<assignment id>`
- `inactive:<patient id>:<date>`
- `incorrect:<set id>`
- `pain:set:<set id>` / `pain:progress:<report id>`

A live set carries an id made by the phone (`set_uid`). If the same set is sent again (a retry after a lost answer),
the server recognises it: the reps are not added twice and no new notification is created. Running the daily job
twice for the same day creates nothing new.

## Access

- `login.php` now also returns a `token` (64 hex characters, valid 30 days, table `auth_token`). The app keeps it in
  memory and sends it as `X-Auth-Token`.
- `notifications_api.php` takes the account from the token only, never from a parameter. Another user's
  notification id gives 404.
- Opening the details of a patient notification checks again that the patient is *still* assigned to the caller.
  If not, the server returns 403 and the app says "This patient is no longer assigned to you."

## Backend

| File | Role |
|---|---|
| `reed/notifications_lib.php` | the tables (created on first use), time zone, tokens, `notify()` and one function per event |
| `reed/notifications_api.php` | `list` (pages, category, unread only), `count`, `read`, `read_all`, `context` |
| `reed/cron/run_notification_jobs.php` | the daily inactivity check (command line only) |
| `tool/register_notification_task.ps1` | registers that job with the Windows Task Scheduler |

Tables: `notification`, `auth_token`, `live_set` (one row per live camera set: good / mistakes / unsure, pain events).
`notification` has indexes for the list (`recipient, created_at`), the unread count (`recipient, read_at`) and the
lookups by type and related account (`recipient, type, related_account_id`).

**Time zone:** PHP and the MySQL session use `KINEX_TIMEZONE` (environment variable, default `Africa/Algiers`). WAMP's
PHP defaults to UTC, which would have put "today" an hour off.

## App

- `lib/features/notifications/`
  - `data/`: the model, the API client and the polled unread count
  - `pages/`: the list, and the detail page for patient notifications
  - `widgets/notification_bell.dart`: the bell with its badge
- **Patient:** the bell in the home header (it used to show a red dot that was always on) and the drawer item
  (it used to say "coming soon"). Categories: Messages, Routine updates.
- **Physiotherapist:** a new bell in the app bar. Categories: Pain reports, Exercise progress, Messages.
- The list shows unread items highlighted with a dot, urgent ones with a red edge, and resolved inactivity alerts with
  a "Resolved" tag. The count is shown per category. You can mark one or all as read, pull to refresh, and the next
  20 load while scrolling. Ages ("5 min ago") use the server clock.

## Setup on a new machine

1. Nothing to migrate by hand: the tables are created on the first call.
2. If the clinic is not in Algeria, set `KINEX_TIMEZONE` (Apache / PHP environment) to its time zone.
3. Register the daily job once (PowerShell):
   `powershell -ExecutionPolicy Bypass -File tool\register_notification_task.ps1`
   (remove it with `schtasks /Delete /TN KinexNotificationJobs /F`). The log is `reed/cron/notification_jobs.log`.
   On Linux: `15 0 * * * php /path/to/reed/cron/run_notification_jobs.php`.
4. Users must log in again once after updating, to get a token.

## Tests

- `python tool/test_notifications.py` (52 checks, against WAMP and the real database). It creates two
  physiotherapists and two patients, triggers each event through the real endpoints, checks recipients, content,
  duplicates, retries, the thresholds, access rules, the daily job (for one test patient only, including exercises
  finished later or earlier) and its resolution, the settings, read states and pagination. Then it deletes everything it created.
- `flutter test test/notifications` (17 tests): parsing, the client (token, error codes), the page (states, read /
  mark all, categories, pagination) and the detail page (numbers, tracking note, the patient's words, a draft that is
  only prepared, a patient who is no longer assigned) and the settings page.

## Limitations

- **No OS push.** Notifications appear when the app is open (30 s polling). Push would need Firebase (FCM) in the
  app and on the server.
- **Only the notification API checks tokens.** The app's other endpoints still take `account_id` as a parameter, as
  before. Securing them would need every page of the app to send the token, which is a separate change.
- **The manual progress form replaces the day's total** (unchanged existing behaviour). Live sets add up.
- **Patients have no settings page** (they only receive messages and routine updates). The API already supports
  their two types.
