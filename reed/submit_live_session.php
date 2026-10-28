<?php
/**
 * A finished live camera set (the exercise assistant), sent by the patient's phone.
 *
 * POST (new set):
 *   account_id, patient_exercise_id, set_uid (unique id made by the phone: a re-sent set is recognised and not
 *   counted twice), reps_done (reps the app could judge), good, mistakes, unsure (confident good / confident mistake /
 *   "not sure" reps), notes (short summary for the progress list), analysis (rep by rep, for AI feedback),
 *   score (0-100), pain_events (JSON list of {time, source, utterance}: pain reported by the patient during the set),
 *   below_target (e4: good-form reps under the range target), wrong_side (reps done with the other arm / leg: not
 *   counted), reps (JSON list, one per rep: rep, label, status, confidence, peak_deg, target_deg -> live_rep rows)
 *   -> adds the reps to today's progress report (sets of a day add up), appends the notes, marks the exercise
 *      Completed at sets x reps, stores the analysis as an aifeedback row and the set as a live_set row;
 *      notifications: pain reported (urgent), most reps incorrect, inactivity of today resolved.
 * POST (pain rating, afterwards):
 *   account_id, progress_id, pain_level (0-10), [set_uid] -> sets the pain level of that report (and of the set);
 *   a rating >= KINEX_PAIN_ALERT_LEVEL notifies the physiotherapist.
 */
ob_start();
ini_set('display_errors', '0');
error_reporting(E_ALL);
header('Content-Type: application/json; charset=UTF-8');

require_once 'db.php';
require_once 'notifications_lib.php';
require_once 'ai_columns.php';

function respond($payload)
{
    if (ob_get_length()) {
        ob_clean();
    }
    echo json_encode($payload);
    exit;
}

if (!isset($conn) || !($conn instanceof mysqli)) {
    respond(['error' => true, 'message' => 'Database connection not initialized']);
}
notif_init($conn);
ensure_ai_columns($conn); // + tracked exercises, live_rep, live_set.below_target / wrong_side

$accountId = isset($_POST['account_id']) ? intval($_POST['account_id']) : 0;
if ($accountId <= 0) {
    respond(['error' => true, 'message' => 'account_id is required']);
}

$patientId = 0;
$stmt = $conn->prepare('SELECT id FROM patient WHERE account_id = ? LIMIT 1');
$stmt->bind_param('i', $accountId);
$stmt->execute();
$res = $stmt->get_result();
if ($row = $res->fetch_assoc()) {
    $patientId = intval($row['id']);
}
$stmt->close();
if ($patientId <= 0) {
    respond(['error' => true, 'message' => 'Patient profile not found']);
}
$patient = notif_patient($conn, $patientId);

// ---- pain rating of a report that was just sent
if (isset($_POST['progress_id'])) {
    $progressId = intval($_POST['progress_id']);
    $pain = isset($_POST['pain_level']) ? max(0, min(10, intval($_POST['pain_level']))) : null;
    if ($progressId <= 0 || $pain === null) {
        respond(['error' => true, 'message' => 'progress_id and pain_level are required']);
    }
    $chk = $conn->prepare('SELECT pr.id, pr.ppid FROM progressreport pr JOIN patientexercise pe ON pe.id = pr.ppid
                           WHERE pr.id = ? AND pe.patient_id = ? LIMIT 1');
    $chk->bind_param('ii', $progressId, $patientId);
    $chk->execute();
    $report = $chk->get_result()->fetch_assoc();
    $chk->close();
    if (!$report) {
        respond(['error' => true, 'message' => 'Progress report not found']);
    }
    $upd = $conn->prepare('UPDATE progressreport SET pain_level = ? WHERE id = ?');
    $upd->bind_param('ii', $pain, $progressId);
    $upd->execute();
    $upd->close();
    $setUid = isset($_POST['set_uid']) ? substr(trim((string)$_POST['set_uid']), 0, 64) : '';
    $set = null;
    if ($setUid !== '') {
        $st = $conn->prepare('SELECT * FROM live_set WHERE set_uid = ? AND patient_id = ? LIMIT 1');
        $st->bind_param('si', $setUid, $patientId);
        $st->execute();
        $set = $st->get_result()->fetch_assoc();
        $st->close();
        if ($set) {
            $u = $conn->prepare('UPDATE live_set SET pain_level = ? WHERE id = ?');
            $sid = intval($set['id']);
            $u->bind_param('ii', $pain, $sid);
            $u->execute();
            $u->close();
        }
    }
    // pain reported during the set: its notification gets the rating; otherwise a high rating creates one
    if ($patient && ($pain >= KINEX_PAIN_ALERT_LEVEL || ($set && intval($set['pain_reported']) === 1))) {
        $assign = notif_assignment($conn, intval($report['ppid']));
        $events = $set ? (json_decode((string)$set['events'], true) ?: []) : [];
        $key = $set ? 'pain:set:' . $set['set_uid'] : 'pain:progress:' . $progressId;
        notify_pain($conn, $key, $patient, $assign ? $assign['exercise_name'] : '',
            $set && intval($set['pain_reported']) === 1 ? 'live_set' : 'pain_scale', $pain,
            $set ? (string)$set['created_at'] : notif_now(),
            ['progress_id' => $progressId, 'ppid' => intval($report['ppid']),
             'live_set_id' => $set ? intval($set['id']) : null, 'events' => $events]);
    }
    respond(['error' => false, 'message' => 'Pain level saved', 'progress_id' => $progressId]);
}

// ---- a finished set
$ppid = isset($_POST['patient_exercise_id']) ? intval($_POST['patient_exercise_id']) : 0;
$repsDone = isset($_POST['reps_done']) ? max(0, intval($_POST['reps_done'])) : 0;
$good = isset($_POST['good']) ? max(0, intval($_POST['good'])) : 0;
$mistakes = isset($_POST['mistakes']) ? max(0, intval($_POST['mistakes'])) : 0;
$unsure = isset($_POST['unsure']) ? max(0, intval($_POST['unsure'])) : 0;
$belowTarget = isset($_POST['below_target']) ? max(0, intval($_POST['below_target'])) : 0;
$wrongSide = isset($_POST['wrong_side']) ? max(0, intval($_POST['wrong_side'])) : 0;
$repRows = parse_live_reps(isset($_POST['reps']) ? $_POST['reps'] : '');
$notes = isset($_POST['notes']) ? trim((string)$_POST['notes']) : '';
$analysis = isset($_POST['analysis']) ? trim((string)$_POST['analysis']) : '';
$score = isset($_POST['score']) ? floatval($_POST['score']) : null;
$setUid = isset($_POST['set_uid']) ? substr(trim((string)$_POST['set_uid']), 0, 64) : '';
if ($setUid === '') {
    $setUid = 'srv-' . bin2hex(random_bytes(12)); // older app versions: no idempotency
}
$painEvents = isset($_POST['pain_events']) ? json_decode((string)$_POST['pain_events'], true) : null;
$painEvents = is_array($painEvents) ? array_slice($painEvents, 0, 20) : [];
if ($ppid <= 0) {
    respond(['error' => true, 'message' => 'patient_exercise_id is required']);
}

// the same set sent again (a retry after a lost answer): nothing is added twice
$dup = $conn->prepare('SELECT id, progress_id FROM live_set WHERE set_uid = ? AND patient_id = ? LIMIT 1');
$dup->bind_param('si', $setUid, $patientId);
$dup->execute();
$existingSet = $dup->get_result()->fetch_assoc();
$dup->close();
if ($existingSet) {
    respond(['error' => false, 'message' => 'Progress saved', 'progress_id' => intval($existingSet['progress_id']),
             'duplicate' => true]);
}

$pick = $conn->prepare(
    "SELECT id, COALESCE(sets, 0) AS sets, COALESCE(reps, 0) AS reps, COALESCE(status, 'pending') AS status, ai_exercise
     FROM patientexercise WHERE id = ? AND patient_id = ? LIMIT 1"
);
$pick->bind_param('ii', $ppid, $patientId);
$pick->execute();
$target = $pick->get_result()->fetch_assoc();
$pick->close();
if (!$target) {
    respond(['error' => true, 'message' => 'Patient exercise assignment not found']);
}
$totalTarget = (intval($target['sets']) > 0 && intval($target['reps']) > 0)
    ? intval($target['sets']) * intval($target['reps'])
    : intval($target['reps']);
$alreadyDone = in_array(strtolower(trim((string)$target['status'])), array('completed', 'done'), true);

// today's report of this assignment: sets add up
$dayStart = date('Y-m-d') . ' 00:00:00';
$dayEnd = date('Y-m-d') . ' 23:59:59';
$chk = $conn->prepare('SELECT id, reps_done, notes FROM progressreport WHERE ppid = ? AND date BETWEEN ? AND ? LIMIT 1');
$chk->bind_param('iss', $ppid, $dayStart, $dayEnd);
$chk->execute();
$existing = $chk->get_result()->fetch_assoc();
$chk->close();

if ($existing) {
    $progressId = intval($existing['id']);
    $total = intval($existing['reps_done']) + $repsDone;
    $allNotes = trim((string)$existing['notes']);
    $allNotes = $allNotes === '' ? $notes : ($notes === '' ? $allNotes : $allNotes . "\n" . $notes);
    $upd = $conn->prepare('UPDATE progressreport SET reps_done = ?, notes = ?, date = NOW() WHERE id = ?');
    $upd->bind_param('isi', $total, $allNotes, $progressId);
    $upd->execute();
    $upd->close();
} else {
    $total = $repsDone;
    $ins = $conn->prepare('INSERT INTO progressreport (ppid, reps_done, pain_level, notes, date) VALUES (?, ?, NULL, ?, NOW())');
    $ins->bind_param('iis', $ppid, $repsDone, $notes);
    $ins->execute();
    $progressId = intval($conn->insert_id);
    $ins->close();
}

// the rep-by-rep analysis, for the physiotherapist's AI feedback list
if ($analysis !== '') {
    $fb = $conn->prepare("INSERT INTO aifeedback (analysis, score, generated_at, progressreport_id, vid_url) VALUES (?, ?, NOW(), ?, '')");
    $fb->bind_param('sdi', $analysis, $score, $progressId);
    $fb->execute();
    $feedbackId = intval($conn->insert_id);
    $fb->close();
}

// the set itself
$painReported = count($painEvents) > 0 ? 1 : 0;
$eventsJson = json_encode($painEvents, JSON_UNESCAPED_UNICODE);
$now = notif_now();
$ls = $conn->prepare('INSERT INTO live_set (set_uid, ppid, patient_id, progress_id, judged, good, mistakes, unsure,
                      below_target, wrong_side, pain_reported, events, mistake_summary, created_at)
                      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
$ls->bind_param('siiiiiiiiiisss', $setUid, $ppid, $patientId, $progressId, $repsDone, $good, $mistakes, $unsure,
    $belowTarget, $wrongSide, $painReported, $eventsJson, $notes, $now);
$ls->execute();
$liveSetId = intval($conn->insert_id);
$ls->close();
// the AI feedback row of this set (the session log opens a set's feedback)
if (isset($feedbackId) && $feedbackId > 0 && $liveSetId > 0) {
    $link = $conn->prepare('UPDATE aifeedback SET live_set_id = ? WHERE id = ?');
    $link->bind_param('ii', $liveSetId, $feedbackId);
    $link->execute();
    $link->close();
}

// every rep of the set (labels, statuses, e4 peak angle and target): the physiotherapist's e4 progress and the
// patient's usual lift are computed from these
if ($liveSetId > 0 && count($repRows) > 0) {
    $aiExercise = ($target['ai_exercise'] !== null && $target['ai_exercise'] !== '') ? (string)$target['ai_exercise'] : null;
    $lr = $conn->prepare('INSERT IGNORE INTO live_rep (live_set_id, ppid, patient_id, ai_exercise, rep, label, status,
                          confidence, peak_deg, target_deg, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
    foreach ($repRows as $r) {
        $lr->bind_param('iiisissddds', $liveSetId, $ppid, $patientId, $aiExercise, $r['rep'], $r['label'], $r['status'],
            $r['confidence'], $r['peak_deg'], $r['target_deg'], $now);
        $lr->execute();
    }
    $lr->close();
}

$completed = false;
if (!$alreadyDone && $totalTarget > 0 && $total >= $totalTarget) {
    $done = $conn->prepare("UPDATE patientexercise SET status = 'Completed' WHERE id = ?");
    $done->bind_param('i', $ppid);
    $done->execute();
    $done->close();
    $completed = true;
}

// ---- notifications
if ($patient) {
    $assign = notif_assignment($conn, $ppid);
    $setRow = ['id' => $liveSetId, 'set_uid' => $setUid, 'good' => $good, 'mistakes' => $mistakes, 'unsure' => $unsure,
               'created_at' => $now];
    if ($repsDone > 0) {
        resolve_inactivity($conn, $patientId, date('Y-m-d'));
    }
    if ($painReported) {
        notify_pain($conn, 'pain:set:' . $setUid, $patient, $assign ? $assign['exercise_name'] : '', 'live_set', null,
            $now, ['progress_id' => $progressId, 'ppid' => $ppid, 'live_set_id' => $liveSetId, 'events' => $painEvents]);
    }
    if ($assign) {
        notify_incorrect_reps($conn, $setRow, $patient, $assign);
    }
}

respond([
    'error' => false,
    'message' => $completed ? 'Exercise completed and progress saved' : 'Progress saved',
    'progress_id' => $progressId,
    'live_set_id' => $liveSetId,
    'reps_done_today' => $total,
    'target' => $totalTarget,
    'completed' => $completed,
]);
