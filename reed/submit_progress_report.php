<?php
ob_start();
ini_set('display_errors', '0');
error_reporting(E_ALL);
header('Content-Type: application/json; charset=UTF-8');

require_once 'db.php';
require_once 'notifications_lib.php';

function respond($payload)
{
    if (ob_get_length()) ob_clean();
    echo json_encode($payload);
    exit;
}

if (!isset($conn) || !($conn instanceof mysqli)) {
    respond(['error' => true, 'message' => 'Database connection not initialized']);
}

$accountId   = isset($_POST['account_id'])   ? intval($_POST['account_id'])   : 0;
$patientExerciseId = isset($_POST['patient_exercise_id']) ? intval($_POST['patient_exercise_id']) : 0;
$repsDone    = isset($_POST['reps_done'])    ? intval($_POST['reps_done'])    : 0;
$painLevel   = isset($_POST['pain_level'])   ? intval($_POST['pain_level'])   : null;
$notes       = isset($_POST['notes'])        ? trim((string)$_POST['notes'])  : null;

if ($accountId <= 0 || $patientExerciseId <= 0) {
    respond(['error' => true, 'message' => 'account_id and patient_exercise_id are required']);
}

// Resolve patient_id from account_id
$patientId = 0;
$stmt = $conn->prepare("SELECT id FROM patient WHERE account_id = ? LIMIT 1");
if ($stmt) {
    $stmt->bind_param('i', $accountId);
    $stmt->execute();
    $res = $stmt->get_result();
    if ($row = $res->fetch_assoc()) {
        $patientId = intval($row['id']);
    }
    $stmt->close();
}
if ($patientId <= 0) {
    respond(['error' => true, 'message' => 'Patient profile not found']);
}

$today = date('Y-m-d');

function resolveTargetExercise($conn, $patientId, $patientExerciseId)
{
    $pick = $conn->prepare(
        "SELECT id, exercise_id,
                COALESCE(sets, 0) AS sets,
                COALESCE(reps, 0) AS reps,
                COALESCE(status, 'pending') AS status
         FROM patientexercise
         WHERE id = ? AND patient_id = ? LIMIT 1"
    );
    if (!$pick) {
        return null;
    }

    $pick->bind_param('ii', $patientExerciseId, $patientId);
    $pick->execute();
    $res = $pick->get_result();
    $target = $res->fetch_assoc();
    $pick->close();

    return $target ?: null;
}

$target = resolveTargetExercise($conn, $patientId, $patientExerciseId);
if (!$target) {
    respond(['error' => true, 'message' => 'Patient exercise assignment not found']);
}

$targetId     = intval($target['id']);
$targetExerciseId = intval($target['exercise_id']);
$targetSets   = intval($target['sets']);
$targetReps   = intval($target['reps']);
$targetStatus = strtolower(trim((string)$target['status']));
$isAlreadyCompleted = ($targetStatus === 'completed' || $targetStatus === 'done');

// Compute the total reps required: sets × reps (fall back to just reps when sets not set)
$totalTarget = ($targetSets > 0 && $targetReps > 0) ? ($targetSets * $targetReps) : $targetReps;

// ── Always save / update the progress report FIRST (so notes and pain are persisted) ──

// Check if a report already exists today for this assignment (ppid)
$checkStmt = $conn->prepare(
    "SELECT id FROM progressreport WHERE ppid = ? AND DATE(date) = ? LIMIT 1"
);
$existingId = null;
if ($checkStmt) {
    $checkStmt->bind_param('is', $targetId, $today);
    $checkStmt->execute();
    $res = $checkStmt->get_result();
    if ($row = $res->fetch_assoc()) {
        $existingId = intval($row['id']);
    }
    $checkStmt->close();
}

if ($existingId !== null) {
    // Update existing report
    $upd = $conn->prepare(
        "UPDATE progressreport SET reps_done = ?, pain_level = ?, notes = ?, date = NOW() WHERE id = ?"
    );
    if (!$upd) {
        respond(['error' => true, 'message' => 'Failed to prepare update: ' . $conn->error]);
    }
    $upd->bind_param('iisi', $repsDone, $painLevel, $notes, $existingId);
    $upd->execute();
    $upd->close();
    $savedId = $existingId;
} else {
    // Insert new report
    $ins = $conn->prepare(
        "INSERT INTO progressreport (ppid, reps_done, pain_level, notes, date) VALUES (?, ?, ?, ?, NOW())"
    );
    if (!$ins) {
        respond(['error' => true, 'message' => 'Failed to prepare insert: ' . $conn->error]);
    }
    $ins->bind_param('iiis', $targetId, $repsDone, $painLevel, $notes);
    $ins->execute();
    $savedId = intval($conn->insert_id);
    $ins->close();
}

// ── Notifications: progress today resolves an inactivity alert; a high pain rating alerts the physiotherapist ──
notif_init($conn);
$patientRow = notif_patient($conn, $patientId);
if ($patientRow) {
    if ($repsDone > 0) {
        resolve_inactivity($conn, $patientId, date('Y-m-d'));
    }
    if ($painLevel !== null && $painLevel >= KINEX_PAIN_ALERT_LEVEL) {
        $assign = notif_assignment($conn, $targetId);
        notify_pain($conn, 'pain:progress:' . $savedId, $patientRow, $assign ? $assign['exercise_name'] : '',
            'progress_report', $painLevel, notif_now(),
            ['progress_id' => intval($savedId), 'ppid' => intval($targetId), 'notes' => (string)$notes]);
    }
}

// ── Now check and update exercise completion status ──
$shouldComplete = !$isAlreadyCompleted
    && $totalTarget > 0
    && $repsDone >= $totalTarget;

if ($shouldComplete) {
    $updStatus = $conn->prepare(
        "UPDATE patientexercise SET status = 'Completed'
         WHERE id = ?
           AND LOWER(TRIM(COALESCE(status, 'pending'))) NOT IN ('completed', 'done')"
    );
    if ($updStatus) {
        $updStatus->bind_param('i', $targetId);
        $updStatus->execute();
        $updStatus->close();
    }
    respond([
        'error' => false,
        'message' => 'Exercise completed and progress saved',
        'id' => $savedId,
        'ppid' => $targetId,
        'exercise_id' => $targetExerciseId,
    ]);
}

respond([
    'error' => false,
    'message' => 'Progress report saved',
    'id' => $savedId,
    'ppid' => $targetId,
    'exercise_id' => $targetExerciseId,
]);

