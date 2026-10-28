<?php
/**
 * Notifications: storage, authentication of the notification endpoints, creation with de-duplication, and the
 * rules that create them (messages, routine updates, inactivity, incorrect repetitions, pain reports).
 *
 * Text: a notification stores its TYPE and its DATA (names, counts, dates...). The app writes the sentence in the
 * user's language from them; `title` / `body` are an English fallback for other surfaces (logs, admin tools).
 *
 * De-duplication: (recipient_account_id, dedup_key) is unique, so the same event processed twice (a retried
 * request, the daily job run twice) never creates a second notification.
 */

require_once __DIR__ . '/db.php';

// ---------------------------------------------------------------------------------------------- settings
/** Clinic time zone: "a day" for the inactivity rule, and the clock of every date written here. */
function kinex_timezone()
{
    $tz = getenv('KINEX_TIMEZONE');
    return new DateTimeZone($tz ? $tz : 'Africa/Algiers');
}

/** A patient's pain rating (0-10) at or above this creates a pain notification (moderate pain and above). */
const KINEX_PAIN_ALERT_LEVEL = 4;

/** Incorrect-repetition alert: at least this share of the confidently judged reps of a set were mistakes... */
const KINEX_INCORRECT_SHARE = 0.9;
/** ...out of at least this many confidently judged reps (a set ends after 10 good or 15 reps in total). */
const KINEX_INCORRECT_MIN_REPS = 8;

/** Login tokens for the notification endpoints are valid this long. */
const KINEX_TOKEN_DAYS = 30;

// ---------------------------------------------------------------------------------------------- schema
function notif_ensure_schema(mysqli $conn)
{
    static $done = false;
    if ($done) {
        return;
    }
    $done = true;
    $conn->query("CREATE TABLE IF NOT EXISTS notification (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        recipient_account_id INT NOT NULL,
        type VARCHAR(32) NOT NULL,
        category VARCHAR(16) NOT NULL,
        priority TINYINT NOT NULL DEFAULT 0,
        title VARCHAR(200) NOT NULL,
        body VARCHAR(600) NULL,
        data TEXT NULL,
        patient_id INT NULL,
        related_account_id INT NULL,
        dedup_key VARCHAR(160) NOT NULL,
        created_at DATETIME NOT NULL,
        read_at DATETIME NULL,
        resolved_at DATETIME NULL,
        UNIQUE KEY uq_notification_dedup (recipient_account_id, dedup_key),
        KEY idx_notification_list (recipient_account_id, created_at),
        KEY idx_notification_unread (recipient_account_id, read_at),
        KEY idx_notification_related (recipient_account_id, type, related_account_id)
    ) DEFAULT CHARSET=utf8mb4");
    $conn->query("CREATE TABLE IF NOT EXISTS auth_token (
        token CHAR(64) NOT NULL PRIMARY KEY,
        account_id INT NOT NULL,
        created_at DATETIME NOT NULL,
        expires_at DATETIME NOT NULL,
        KEY idx_auth_token_account (account_id)
    ) DEFAULT CHARSET=utf8mb4");
    // one row per live camera set: makes re-sent sets idempotent and keeps the context of alerts
    $conn->query("CREATE TABLE IF NOT EXISTS live_set (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        set_uid VARCHAR(64) NOT NULL,
        ppid INT NOT NULL,
        patient_id INT NOT NULL,
        progress_id INT NULL,
        judged INT NOT NULL DEFAULT 0,
        good INT NOT NULL DEFAULT 0,
        mistakes INT NOT NULL DEFAULT 0,
        unsure INT NOT NULL DEFAULT 0,
        pain_reported TINYINT NOT NULL DEFAULT 0,
        pain_level INT NULL,
        events TEXT NULL,
        mistake_summary TEXT NULL,
        created_at DATETIME NOT NULL,
        UNIQUE KEY uq_live_set_uid (set_uid),
        KEY idx_live_set_patient (patient_id, created_at)
    ) DEFAULT CHARSET=utf8mb4");
    // types a user turned off (no row = on)
    $conn->query("CREATE TABLE IF NOT EXISTS notification_pref (
        account_id INT NOT NULL,
        type VARCHAR(32) NOT NULL,
        enabled TINYINT NOT NULL DEFAULT 1,
        updated_at DATETIME NOT NULL,
        PRIMARY KEY (account_id, type)
    ) DEFAULT CHARSET=utf8mb4");
}

/** The notification types a role can receive, so the ones it can turn off. */
function notif_types_for_role($role)
{
    $role = strtolower((string)$role);
    if ($role === 'patient') {
        return ['message', 'routine_update'];
    }
    if ($role === 'therapist' || $role === 'physiotherapist') {
        return ['pain_report', 'incorrect_reps', 'inactivity', 'message'];
    }
    return [];
}

/** Whether the account wants this type (on unless turned off). */
function notif_enabled(mysqli $conn, $accountId, $type)
{
    notif_ensure_schema($conn);
    $st = $conn->prepare('SELECT enabled FROM notification_pref WHERE account_id = ? AND type = ? LIMIT 1');
    $st->bind_param('is', $accountId, $type);
    $st->execute();
    $row = $st->get_result()->fetch_assoc();
    $st->close();
    return !$row || intval($row['enabled']) === 1;
}

/** type => on/off for the account's role. */
function notif_prefs(mysqli $conn, $accountId, $role)
{
    notif_ensure_schema($conn);
    $prefs = array_fill_keys(notif_types_for_role($role), true);
    $st = $conn->prepare('SELECT type, enabled FROM notification_pref WHERE account_id = ?');
    $st->bind_param('i', $accountId);
    $st->execute();
    foreach ($st->get_result()->fetch_all(MYSQLI_ASSOC) as $r) {
        if (array_key_exists($r['type'], $prefs)) {
            $prefs[$r['type']] = intval($r['enabled']) === 1;
        }
    }
    $st->close();
    return $prefs;
}

/** Every notification request: schema + the clinic clock for NOW() and PHP dates. */
function notif_init(mysqli $conn)
{
    $tz = kinex_timezone();
    date_default_timezone_set($tz->getName());
    $offset = (new DateTime('now', $tz))->format('P'); // e.g. +01:00
    $conn->query("SET time_zone = '" . $conn->real_escape_string($offset) . "'");
    notif_ensure_schema($conn);
}

function notif_now()
{
    return (new DateTime('now', kinex_timezone()))->format('Y-m-d H:i:s');
}

// ---------------------------------------------------------------------------------------------- auth
function auth_issue_token(mysqli $conn, $accountId)
{
    notif_ensure_schema($conn);
    $token = bin2hex(random_bytes(32));
    $now = notif_now();
    $exp = (new DateTime('now', kinex_timezone()))->modify('+' . KINEX_TOKEN_DAYS . ' days')->format('Y-m-d H:i:s');
    $st = $conn->prepare('INSERT INTO auth_token (token, account_id, created_at, expires_at) VALUES (?, ?, ?, ?)');
    $st->bind_param('siss', $token, $accountId, $now, $exp);
    $st->execute();
    $st->close();
    // old expired tokens of this account are removed
    $del = $conn->prepare('DELETE FROM auth_token WHERE account_id = ? AND expires_at < ?');
    $del->bind_param('is', $accountId, $now);
    $del->execute();
    $del->close();
    return $token;
}

/** The account of the request's token (header X-Auth-Token, or a 'token' field), with its role; null if invalid. */
function auth_account(mysqli $conn)
{
    $token = isset($_SERVER['HTTP_X_AUTH_TOKEN']) ? (string)$_SERVER['HTTP_X_AUTH_TOKEN'] : '';
    if ($token === '' && isset($_POST['token'])) {
        $token = (string)$_POST['token'];
    }
    if ($token === '' && isset($_GET['token'])) {
        $token = (string)$_GET['token'];
    }
    if (!preg_match('/^[0-9a-f]{64}$/', $token)) {
        return null;
    }
    $now = notif_now();
    $st = $conn->prepare(
        'SELECT a.id, a.role, a.is_active FROM auth_token t JOIN account a ON a.id = t.account_id
         WHERE t.token = ? AND t.expires_at >= ? LIMIT 1'
    );
    $st->bind_param('ss', $token, $now);
    $st->execute();
    $row = $st->get_result()->fetch_assoc();
    $st->close();
    if (!$row || intval($row['is_active']) !== 1) {
        return null;
    }
    return ['account_id' => intval($row['id']), 'role' => strtolower((string)$row['role'])];
}

function auth_require(mysqli $conn)
{
    $acc = auth_account($conn);
    if ($acc === null) {
        http_response_code(401);
        echo json_encode(['error' => true, 'code' => 'unauthorized', 'message' => 'Please log in again']);
        exit;
    }
    return $acc;
}

// ---------------------------------------------------------------------------------------------- creation
/**
 * Creates a notification once per (recipient, dedup_key). Returns the id, or 0 when it already existed.
 * $data: the facts the app needs to write the sentence and to open the right page.
 */
function notify(mysqli $conn, $recipientAccountId, $type, $category, $priority, $dedupKey, $title, $body, array $data,
                $patientId = null, $relatedAccountId = null)
{
    notif_ensure_schema($conn);
    if ($recipientAccountId <= 0) {
        return 0;
    }
    if (!notif_enabled($conn, $recipientAccountId, $type)) {
        return 0; // turned off by the recipient: not stored at all
    }
    $json = json_encode($data, JSON_UNESCAPED_UNICODE);
    $now = notif_now();
    $st = $conn->prepare(
        'INSERT IGNORE INTO notification
         (recipient_account_id, type, category, priority, title, body, data, patient_id, related_account_id, dedup_key, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $st->bind_param('ississsiiss', $recipientAccountId, $type, $category, $priority, $title, $body, $json,
        $patientId, $relatedAccountId, $dedupKey, $now);
    $st->execute();
    $id = $st->affected_rows > 0 ? intval($conn->insert_id) : 0;
    $st->close();
    return $id;
}

/** Replaces the data/body of an existing notification (e.g. a pain level given after the set) and marks it unread. */
function notify_update(mysqli $conn, $recipientAccountId, $dedupKey, $body, array $data)
{
    $json = json_encode($data, JSON_UNESCAPED_UNICODE);
    $st = $conn->prepare('UPDATE notification SET body = ?, data = ?, read_at = NULL
                          WHERE recipient_account_id = ? AND dedup_key = ?');
    $st->bind_param('ssis', $body, $json, $recipientAccountId, $dedupKey);
    $st->execute();
    $n = $st->affected_rows;
    $st->close();
    return $n;
}

/** A short, safe preview of a message (no line breaks, at most 80 characters). */
function notif_preview($text)
{
    $t = trim(preg_replace('/\s+/u', ' ', (string)$text));
    return mb_strlen($t) > 80 ? mb_substr($t, 0, 79) . '…' : $t;
}

// ---------------------------------------------------------------------------------------------- lookups
function notif_display_name(mysqli $conn, $accountId)
{
    foreach (['patient', 'physiotherapist'] as $table) {
        $st = $conn->prepare("SELECT name FROM $table WHERE account_id = ? LIMIT 1");
        $st->bind_param('i', $accountId);
        $st->execute();
        $row = $st->get_result()->fetch_assoc();
        $st->close();
        if ($row) {
            return (string)$row['name'];
        }
    }
    return '';
}

/** patient row (id, account_id, name, therapist_id) + the therapist's account id. */
function notif_patient(mysqli $conn, $patientId)
{
    $st = $conn->prepare(
        'SELECT p.id, p.account_id, p.name, p.therapist_id, ph.account_id AS physio_account_id, ph.name AS physio_name
         FROM patient p LEFT JOIN physiotherapist ph ON ph.id = p.therapist_id WHERE p.id = ? LIMIT 1'
    );
    $st->bind_param('i', $patientId);
    $st->execute();
    $row = $st->get_result()->fetch_assoc();
    $st->close();
    return $row ?: null;
}

/** The assignment (patientexercise) with its exercise name. */
function notif_assignment(mysqli $conn, $ppid)
{
    $st = $conn->prepare(
        'SELECT pe.id, pe.patient_id, pe.exercise_id, pe.Sets AS sets, pe.Reps AS reps, e.name AS exercise_name
         FROM patientexercise pe JOIN exercise e ON e.id = pe.exercise_id WHERE pe.id = ? LIMIT 1'
    );
    $st->bind_param('i', $ppid);
    $st->execute();
    $row = $st->get_result()->fetch_assoc();
    $st->close();
    return $row ?: null;
}

// ---------------------------------------------------------------------------------------------- rules
/** B. A message: the recipient is told who wrote and sees a short preview. Never the sender. */
function notify_message(mysqli $conn, $messageId, $senderAccountId, $receiverAccountId, $content)
{
    if ($senderAccountId === $receiverAccountId) {
        return 0;
    }
    $sender = notif_display_name($conn, $senderAccountId);
    $preview = notif_preview($content);
    $role = '';
    $st = $conn->prepare('SELECT role FROM account WHERE id = ? LIMIT 1');
    $st->bind_param('i', $senderAccountId);
    $st->execute();
    if ($r = $st->get_result()->fetch_assoc()) {
        $role = (string)$r['role'];
    }
    $st->close();
    return notify($conn, $receiverAccountId, 'message', 'messages', 0, 'msg:' . $messageId,
        'New message from ' . $sender, $preview,
        ['message_id' => $messageId, 'sender_account_id' => $senderAccountId, 'sender_name' => $sender,
         'sender_role' => $role, 'preview' => $preview, 'sent_at' => notif_now()],
        null, $senderAccountId);
}

/** Opening a conversation marks its message notifications as read. */
function notif_mark_conversation_read(mysqli $conn, $readerAccountId, $otherAccountId)
{
    notif_ensure_schema($conn);
    $now = notif_now();
    $st = $conn->prepare("UPDATE notification SET read_at = ? WHERE recipient_account_id = ? AND type = 'message'
                          AND related_account_id = ? AND read_at IS NULL");
    $st->bind_param('sii', $now, $readerAccountId, $otherAccountId);
    $st->execute();
    $st->close();
}

/** C. The physiotherapist added an exercise to the patient's routine. */
function notify_routine_update(mysqli $conn, $ppid)
{
    $a = notif_assignment($conn, $ppid);
    if (!$a) {
        return 0;
    }
    $p = notif_patient($conn, intval($a['patient_id']));
    if (!$p) {
        return 0;
    }
    return notify($conn, intval($p['account_id']), 'routine_update', 'routine', 0, 'routine:' . $ppid,
        'New exercise in your routine', (string)$a['exercise_name'],
        ['ppid' => intval($ppid), 'exercise_id' => intval($a['exercise_id']), 'exercise_name' => (string)$a['exercise_name'],
         'sets' => intval($a['sets']), 'reps' => intval($a['reps']), 'physio_name' => (string)$p['physio_name']],
        intval($p['id']), intval($p['physio_account_id']));
}

/**
 * D. Inactivity for one day: for every patient with a physiotherapist who had exercises to do that day and recorded no
 * progress at all that day, notify the physiotherapist. An assignment was due that day if it was given before it and
 * not finished before it: still pending, or completed by progress recorded on that day or later (patientexercise
 * only keeps the current status, so the date it was finished is taken from its last progress report).
 * Returns the number of notifications created. Idempotent (one per patient and day).
 */
function check_inactivity(mysqli $conn, $day, $onlyPatientId = 0)
{
    notif_ensure_schema($conn);
    $start = $day . ' 00:00:00';
    $end = $day . ' 23:59:59';
    $sql = "SELECT p.id AS patient_id, p.account_id, p.name, ph.account_id AS physio_account_id,
                   COUNT(pe.id) AS prescribed, GROUP_CONCAT(e.name ORDER BY e.name SEPARATOR '||') AS exercises
            FROM patient p
            JOIN physiotherapist ph ON ph.id = p.therapist_id
            JOIN patientexercise pe ON pe.patient_id = p.id
            JOIN exercise e ON e.id = pe.exercise_id
            WHERE pe.assigned_date < ?
              AND (LOWER(TRIM(COALESCE(pe.status, 'pending'))) NOT IN ('completed', 'done')
                   OR (SELECT MAX(pr.date) FROM progressreport pr WHERE pr.ppid = pe.id) >= ?)
              AND (? = 0 OR p.id = ?)
            GROUP BY p.id, p.account_id, p.name, ph.account_id";
    $st = $conn->prepare($sql);
    $only = intval($onlyPatientId);
    $st->bind_param('ssii', $start, $start, $only, $only);
    $st->execute();
    $patients = $st->get_result()->fetch_all(MYSQLI_ASSOC);
    $st->close();
    $created = 0;
    foreach ($patients as $p) {
        $done = $conn->prepare(
            'SELECT COUNT(*) AS n FROM progressreport pr JOIN patientexercise pe ON pe.id = pr.ppid
             WHERE pe.patient_id = ? AND pr.date BETWEEN ? AND ? AND pr.reps_done > 0'
        );
        $pid = intval($p['patient_id']);
        $done->bind_param('iss', $pid, $start, $end);
        $done->execute();
        $n = intval($done->get_result()->fetch_assoc()['n']);
        $done->close();
        if ($n > 0) {
            continue;
        }
        $exercises = $p['exercises'] === null ? [] : explode('||', (string)$p['exercises']);
        $id = notify($conn, intval($p['physio_account_id']), 'inactivity', 'progress', 1,
            'inactive:' . $pid . ':' . $day,
            $p['name'] . ' did no exercise on ' . $day,
            intval($p['prescribed']) . ' exercise(s) were prescribed',
            ['patient_id' => $pid, 'patient_account_id' => intval($p['account_id']), 'patient_name' => (string)$p['name'],
             'date' => $day, 'prescribed' => intval($p['prescribed']), 'exercises' => $exercises],
            $pid, intval($p['account_id']));
        if ($id > 0) {
            $created++;
        }
    }
    return $created;
}

/**
 * The patient recorded progress (on $day): their open inactivity notifications of that day and earlier are resolved -
 * the physiotherapist sees that the patient has resumed. The notification itself (the missed day) stays.
 */
function resolve_inactivity(mysqli $conn, $patientId, $day)
{
    notif_ensure_schema($conn);
    $now = notif_now();
    $prefix = 'inactive:' . intval($patientId) . ':%';
    $st = $conn->prepare("UPDATE notification SET resolved_at = ?
                          WHERE type = 'inactivity' AND dedup_key LIKE ? AND resolved_at IS NULL
                            AND SUBSTRING_INDEX(dedup_key, ':', -1) <= ?");
    $st->bind_param('sss', $now, $prefix, $day);
    $st->execute();
    $st->close();
}

/**
 * E. A live set where most confidently judged reps were mistakes. Only reps the model judged with enough confidence
 * count (good + mistake); "not sure" reps are left out of both numbers.
 */
function notify_incorrect_reps(mysqli $conn, array $set, array $patient, array $assignment)
{
    $judged = intval($set['good']) + intval($set['mistakes']);
    if ($judged < KINEX_INCORRECT_MIN_REPS) {
        return 0;
    }
    $share = intval($set['mistakes']) / $judged;
    if ($share < KINEX_INCORRECT_SHARE) {
        return 0;
    }
    return notify($conn, intval($patient['physio_account_id']), 'incorrect_reps', 'progress', 1,
        'incorrect:' . $set['set_uid'],
        $patient['name'] . ': most repetitions were incorrect',
        $set['mistakes'] . ' of ' . $judged . ' judged repetitions were incorrect (' . $assignment['exercise_name'] . ')',
        ['patient_id' => intval($patient['id']), 'patient_account_id' => intval($patient['account_id']),
         'patient_name' => (string)$patient['name'], 'live_set_id' => intval($set['id']), 'ppid' => intval($assignment['id']),
         'exercise_name' => (string)$assignment['exercise_name'], 'mistakes' => intval($set['mistakes']),
         'judged' => $judged, 'unsure' => intval($set['unsure']), 'share' => round($share, 3),
         'date' => substr((string)$set['created_at'], 0, 10)],
        intval($patient['id']), intval($patient['account_id']));
}

/**
 * F. Pain reported by the patient (during a live set, or a rating >= KINEX_PAIN_ALERT_LEVEL). Urgent priority.
 * $source: 'live_set' (pain said or pressed during the set), 'pain_scale' (rating after a set), 'progress_report'.
 */
function notify_pain(mysqli $conn, $dedupKey, array $patient, $exerciseName, $source, $painLevel, $reportedAt,
                     array $extra = [])
{
    $data = array_merge([
        'patient_id' => intval($patient['id']), 'patient_account_id' => intval($patient['account_id']),
        'patient_name' => (string)$patient['name'], 'exercise_name' => (string)$exerciseName,
        'source' => $source, 'pain_level' => $painLevel, 'reported_at' => $reportedAt,
    ], $extra);
    $body = 'Patient-reported pain' . ($painLevel !== null ? ' (' . $painLevel . '/10)' : '') . ' - ' . $exerciseName;
    $physio = intval($patient['physio_account_id']);
    $id = notify($conn, $physio, 'pain_report', 'pain', 2, $dedupKey,
        $patient['name'] . ' reported pain', $body, $data, intval($patient['id']), intval($patient['account_id']));
    if ($id === 0) {
        notify_update($conn, $physio, $dedupKey, $body, $data); // e.g. the rating came after the report
    }
    return $id;
}
