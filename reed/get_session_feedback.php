<?php
/**
 * The feedback of one session (a progress report: an exercise on a day, its live sets added up), for the session log.
 * GET account_id + progress_id, or account_id + patient_exercise_id + date (YYYY-MM-DD)
 *   -> {error: false, progress: {...}, exercise: {...}, sets: [{counts, pain, score, analysis, reps: [...]}]}
 * Allowed: the patient of the exercise, or their physiotherapist (AI feedback needs an active clinic subscription,
 * as get_physio_ai_feedback.php).
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
notif_init($conn); // live_set
ensure_ai_columns($conn);

$accountId = isset($_GET['account_id']) ? intval($_GET['account_id']) : 0;
$progressId = isset($_GET['progress_id']) ? intval($_GET['progress_id']) : 0;
$ppid = isset($_GET['patient_exercise_id']) ? intval($_GET['patient_exercise_id']) : 0;
$date = isset($_GET['date']) ? trim((string)$_GET['date']) : '';
if ($accountId <= 0 || ($progressId <= 0 && ($ppid <= 0 || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)))) {
    respond(['error' => true, 'message' => 'account_id and progress_id (or patient_exercise_id and date) are required']);
}
if ($progressId <= 0) {
    $st = $conn->prepare('SELECT id FROM progressreport WHERE ppid = ? AND DATE(date) = ? ORDER BY date DESC, id DESC LIMIT 1');
    $st->bind_param('is', $ppid, $date);
    $st->execute();
    $row = $st->get_result()->fetch_assoc();
    $st->close();
    if (!$row) {
        respond(['error' => false, 'progress' => null, 'exercise' => null, 'sets' => []]);
    }
    $progressId = intval($row['id']);
}

$fb = session_feedback($conn, $progressId);
if ($fb === null) {
    respond(['error' => true, 'message' => 'Progress report not found']);
}
$patientId = $fb['exercise']['patient_id'];

// who is asking: the patient, or the patient's physiotherapist
$allowed = false;
$st = $conn->prepare('SELECT id FROM patient WHERE account_id = ? AND id = ? LIMIT 1');
$st->bind_param('ii', $accountId, $patientId);
$st->execute();
$allowed = (bool)$st->get_result()->fetch_assoc();
$st->close();
if (!$allowed) {
    $st = $conn->prepare('SELECT ph.id, ph.clinic_id FROM physiotherapist ph INNER JOIN patient p ON p.therapist_id = ph.id
                          WHERE ph.account_id = ? AND p.id = ? LIMIT 1');
    $st->bind_param('ii', $accountId, $patientId);
    $st->execute();
    $physio = $st->get_result()->fetch_assoc();
    $st->close();
    if (!$physio) {
        respond(['error' => true, 'message' => 'Not allowed to see this session']);
    }
    $clinicId = intval($physio['clinic_id']);
    $active = false;
    if ($clinicId > 0) {
        $sub = $conn->prepare("SELECT id FROM subscription WHERE clinic_id = ? AND LOWER(TRIM(COALESCE(status,'active'))) = 'active' LIMIT 1");
        $sub->bind_param('i', $clinicId);
        $sub->execute();
        $active = (bool)$sub->get_result()->fetch_assoc();
        $sub->close();
    }
    if (!$active) {
        respond(['error' => true, 'message' => 'AI feedback is available only with active clinic subscription']);
    }
}

unset($fb['exercise']['patient_id']);
respond(['error' => false] + $fb);
