<?php
/**
 * Notification center API. Every call needs the login token (header X-Auth-Token); the account comes from the
 * token, never from a parameter, so a user only ever sees and changes their own notifications.
 *
 * GET  ?action=list&page=1&limit=20&category=all|messages|routine|progress|pain&unread_only=0
 * GET  ?action=count                         -> unread count (for the badge; polled by the app)
 * POST action=read&id=N                      -> one notification read
 * POST action=read_all[&category=...]        -> all (of a category) read
 * GET  ?action=context&id=N                  -> what the notification points to (patient, day, set, report...),
 *                                               re-checked against the current patient / physiotherapist relationship
 * GET  ?action=prefs                         -> {type: on/off} for the types the caller's role receives
 * POST action=set_pref&type=T&enabled=0|1    -> turn a type off / on (off: such notifications are not created)
 */
ob_start();
ini_set('display_errors', '0');
error_reporting(E_ALL);
header('Content-Type: application/json; charset=UTF-8');

require_once 'notifications_lib.php';

function out($payload, $status = 200)
{
    if (ob_get_length()) {
        ob_clean();
    }
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit;
}

if (!isset($conn) || !($conn instanceof mysqli)) {
    out(['error' => true, 'message' => 'Database connection not initialized'], 500);
}
notif_init($conn);
$me = auth_require($conn);
$accountId = $me['account_id'];
$action = isset($_REQUEST['action']) ? (string)$_REQUEST['action'] : 'list';
const CATEGORIES = ['messages', 'routine', 'progress', 'pain'];

function unread_counts(mysqli $conn, $accountId)
{
    $st = $conn->prepare('SELECT category, COUNT(*) AS n FROM notification
                          WHERE recipient_account_id = ? AND read_at IS NULL GROUP BY category');
    $st->bind_param('i', $accountId);
    $st->execute();
    $rows = $st->get_result()->fetch_all(MYSQLI_ASSOC);
    $st->close();
    $by = array_fill_keys(CATEGORIES, 0);
    $total = 0;
    foreach ($rows as $r) {
        $by[$r['category']] = intval($r['n']);
        $total += intval($r['n']);
    }
    return [$total, $by];
}

function row_out(array $r)
{
    return [
        'id' => intval($r['id']),
        'type' => (string)$r['type'],
        'category' => (string)$r['category'],
        'priority' => intval($r['priority']),
        'title' => (string)$r['title'],
        'body' => (string)$r['body'],
        'data' => json_decode((string)$r['data'], true) ?: new stdClass(),
        'created_at' => (string)$r['created_at'],
        'read' => $r['read_at'] !== null,
        'resolved' => $r['resolved_at'] !== null,
    ];
}

/** The notification, if it belongs to the caller. */
function own_notification(mysqli $conn, $accountId, $id)
{
    $st = $conn->prepare('SELECT * FROM notification WHERE id = ? AND recipient_account_id = ? LIMIT 1');
    $st->bind_param('ii', $id, $accountId);
    $st->execute();
    $row = $st->get_result()->fetch_assoc();
    $st->close();
    return $row ?: null;
}

switch ($action) {
    case 'count':
        [$total, $by] = unread_counts($conn, $accountId);
        out(['error' => false, 'unread' => $total, 'unread_by_category' => $by]);

    case 'list':
        $page = max(1, intval($_GET['page'] ?? 1));
        $limit = max(1, min(50, intval($_GET['limit'] ?? 20)));
        $offset = ($page - 1) * $limit;
        $category = (string)($_GET['category'] ?? 'all');
        $unreadOnly = ($_GET['unread_only'] ?? '0') === '1';
        $where = 'recipient_account_id = ?';
        $types = 'i';
        $args = [$accountId];
        if (in_array($category, CATEGORIES, true)) {
            $where .= ' AND category = ?';
            $types .= 's';
            $args[] = $category;
        }
        if ($unreadOnly) {
            $where .= ' AND read_at IS NULL';
        }
        $fetch = $limit + 1; // one more tells whether there is a next page
        $st = $conn->prepare("SELECT * FROM notification WHERE $where ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?");
        $types .= 'ii';
        $args[] = $fetch;
        $args[] = $offset;
        $st->bind_param($types, ...$args);
        $st->execute();
        $rows = $st->get_result()->fetch_all(MYSQLI_ASSOC);
        $st->close();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);
        [$total, $by] = unread_counts($conn, $accountId);
        out(['error' => false, 'items' => array_map('row_out', $rows), 'page' => $page, 'has_more' => $hasMore,
             'unread' => $total, 'unread_by_category' => $by, 'server_now' => notif_now()]);

    case 'read':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            out(['error' => true, 'message' => 'POST required'], 405);
        }
        $id = intval($_POST['id'] ?? 0);
        $now = notif_now();
        $st = $conn->prepare('UPDATE notification SET read_at = COALESCE(read_at, ?) WHERE id = ? AND recipient_account_id = ?');
        $st->bind_param('sii', $now, $id, $accountId);
        $st->execute();
        $found = $st->affected_rows >= 0 && own_notification($conn, $accountId, $id) !== null;
        $st->close();
        if (!$found) {
            out(['error' => true, 'message' => 'Notification not found'], 404);
        }
        [$total, $by] = unread_counts($conn, $accountId);
        out(['error' => false, 'unread' => $total, 'unread_by_category' => $by]);

    case 'read_all':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            out(['error' => true, 'message' => 'POST required'], 405);
        }
        $category = (string)($_POST['category'] ?? 'all');
        $now = notif_now();
        if (in_array($category, CATEGORIES, true)) {
            $st = $conn->prepare('UPDATE notification SET read_at = ? WHERE recipient_account_id = ? AND category = ? AND read_at IS NULL');
            $st->bind_param('sis', $now, $accountId, $category);
        } else {
            $st = $conn->prepare('UPDATE notification SET read_at = ? WHERE recipient_account_id = ? AND read_at IS NULL');
            $st->bind_param('si', $now, $accountId);
        }
        $st->execute();
        $st->close();
        [$total, $by] = unread_counts($conn, $accountId);
        out(['error' => false, 'unread' => $total, 'unread_by_category' => $by]);

    case 'context':
        $id = intval($_GET['id'] ?? 0);
        $n = own_notification($conn, $accountId, $id);
        if (!$n) {
            out(['error' => true, 'code' => 'not_found', 'message' => 'Notification not found'], 404);
        }
        $data = json_decode((string)$n['data'], true) ?: [];
        $ctx = ['notification' => row_out($n)];
        $type = (string)$n['type'];

        if ($type === 'message') {
            // the conversation partner, if the two are still patient and physiotherapist
            $other = intval($data['sender_account_id'] ?? 0);
            $ctx['other_account_id'] = $other;
            $ctx['other_name'] = notif_display_name($conn, $other);
            $ctx['available'] = $ctx['other_name'] !== '';
            out(['error' => false] + $ctx);
        }
        if ($type === 'routine_update') {
            $ppid = intval($data['ppid'] ?? 0);
            $st = $conn->prepare('SELECT pe.id FROM patientexercise pe JOIN patient p ON p.id = pe.patient_id
                                  WHERE pe.id = ? AND p.account_id = ? LIMIT 1');
            $st->bind_param('ii', $ppid, $accountId);
            $st->execute();
            $ctx['available'] = $st->get_result()->fetch_assoc() !== null;
            $st->close();
            $ctx['ppid'] = $ppid;
            out(['error' => false] + $ctx);
        }

        // physiotherapist notifications about a patient: still that patient's physiotherapist?
        $patientId = intval($n['patient_id']);
        $st = $conn->prepare('SELECT p.id, p.account_id, p.name FROM patient p JOIN physiotherapist ph ON ph.id = p.therapist_id
                              WHERE p.id = ? AND ph.account_id = ? LIMIT 1');
        $st->bind_param('ii', $patientId, $accountId);
        $st->execute();
        $patient = $st->get_result()->fetch_assoc();
        $st->close();
        if (!$patient) {
            out(['error' => true, 'code' => 'forbidden', 'message' => 'This patient is no longer assigned to you'], 403);
        }
        $ctx['patient'] = ['id' => intval($patient['id']), 'account_id' => intval($patient['account_id']),
                           'name' => (string)$patient['name']];

        if ($type === 'inactivity') {
            $day = (string)($data['date'] ?? '');
            $start = $day . ' 00:00:00';
            $end = $day . ' 23:59:59';
            // what was prescribed then (assigned before that day), and what was recorded that day
            $st = $conn->prepare("SELECT pe.id, e.name, pe.Sets AS sets, pe.Reps AS reps, pe.assigned_date, pe.status
                                  FROM patientexercise pe JOIN exercise e ON e.id = pe.exercise_id
                                  WHERE pe.patient_id = ? AND pe.assigned_date < ?
                                    AND (LOWER(TRIM(COALESCE(pe.status, 'pending'))) NOT IN ('completed', 'done')
                                         OR (SELECT MAX(pr.date) FROM progressreport pr WHERE pr.ppid = pe.id) >= ?)
                                  ORDER BY pe.assigned_date");
            $st->bind_param('iss', $patientId, $start, $start);
            $st->execute();
            $ctx['prescribed'] = $st->get_result()->fetch_all(MYSQLI_ASSOC);
            $st->close();
            $st = $conn->prepare('SELECT pr.date, pr.reps_done, pr.pain_level, e.name FROM progressreport pr
                                  JOIN patientexercise pe ON pe.id = pr.ppid JOIN exercise e ON e.id = pe.exercise_id
                                  WHERE pe.patient_id = ? AND pr.date BETWEEN ? AND ? ORDER BY pr.date');
            $st->bind_param('iss', $patientId, $start, $end);
            $st->execute();
            $ctx['done_that_day'] = $st->get_result()->fetch_all(MYSQLI_ASSOC);
            $st->close();
            $ctx['date'] = $day;
            out(['error' => false] + $ctx);
        }

        $setId = intval($data['live_set_id'] ?? 0);
        if ($setId > 0) {
            $st = $conn->prepare('SELECT ls.*, e.name AS exercise_name FROM live_set ls
                                  JOIN patientexercise pe ON pe.id = ls.ppid JOIN exercise e ON e.id = pe.exercise_id
                                  WHERE ls.id = ? AND ls.patient_id = ? LIMIT 1');
            $st->bind_param('ii', $setId, $patientId);
            $st->execute();
            $set = $st->get_result()->fetch_assoc();
            $st->close();
            if ($set) {
                $ctx['set'] = [
                    'id' => intval($set['id']), 'exercise_name' => (string)$set['exercise_name'],
                    'created_at' => (string)$set['created_at'], 'judged' => intval($set['judged']),
                    'good' => intval($set['good']), 'mistakes' => intval($set['mistakes']),
                    'unsure' => intval($set['unsure']), 'pain_reported' => intval($set['pain_reported']) === 1,
                    'pain_level' => $set['pain_level'] === null ? null : intval($set['pain_level']),
                    'events' => json_decode((string)$set['events'], true) ?: [],
                    'summary' => (string)$set['mistake_summary'],
                ];
            }
        }
        $progressId = intval($data['progress_id'] ?? 0);
        if ($progressId > 0) {
            $st = $conn->prepare('SELECT pr.id, pr.date, pr.reps_done, pr.pain_level, pr.notes, e.name AS exercise_name
                                  FROM progressreport pr JOIN patientexercise pe ON pe.id = pr.ppid
                                  JOIN exercise e ON e.id = pe.exercise_id WHERE pr.id = ? AND pe.patient_id = ? LIMIT 1');
            $st->bind_param('ii', $progressId, $patientId);
            $st->execute();
            $ctx['report'] = $st->get_result()->fetch_assoc();
            $st->close();
        }
        out(['error' => false] + $ctx);

    case 'prefs':
        out(['error' => false, 'prefs' => notif_prefs($conn, $accountId, $me['role'])]);

    case 'set_pref':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            out(['error' => true, 'message' => 'POST required'], 405);
        }
        $type = (string)($_POST['type'] ?? '');
        if (!in_array($type, notif_types_for_role($me['role']), true)) {
            out(['error' => true, 'message' => 'Unknown notification type'], 400);
        }
        $enabled = ($_POST['enabled'] ?? '1') === '1' ? 1 : 0;
        $now = notif_now();
        $st = $conn->prepare('INSERT INTO notification_pref (account_id, type, enabled, updated_at) VALUES (?, ?, ?, ?)
                              ON DUPLICATE KEY UPDATE enabled = VALUES(enabled), updated_at = VALUES(updated_at)');
        $st->bind_param('isis', $accountId, $type, $enabled, $now);
        $st->execute();
        $st->close();
        out(['error' => false, 'prefs' => notif_prefs($conn, $accountId, $me['role'])]);

    default:
        out(['error' => true, 'message' => 'Unknown action'], 400);
}
