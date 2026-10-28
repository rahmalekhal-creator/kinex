<?php
ob_start();
ini_set('display_errors', '0');
error_reporting(E_ALL);
header('Content-Type: application/json; charset=UTF-8');

require_once 'db.php';
require_once 'ai_columns.php';
require_once 'notifications_lib.php';

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

$accountId = isset($_POST['account_id']) ? intval($_POST['account_id']) : 0;
$patientId = isset($_POST['patient_id']) ? intval($_POST['patient_id']) : 0;
$exerciseId = isset($_POST['exercise_id']) ? intval($_POST['exercise_id']) : 0;
$sets = isset($_POST['sets']) ? intval($_POST['sets']) : 1;
$reps = isset($_POST['reps']) ? intval($_POST['reps']) : 1;

// Multi-day prescription parameters
$startDate = isset($_POST['start_date']) && trim((string)$_POST['start_date']) !== ''
    ? trim((string)$_POST['start_date'])
    : date('Y-m-d');
$endDate = isset($_POST['end_date']) && trim((string)$_POST['end_date']) !== ''
    ? trim((string)$_POST['end_date'])
    : $startDate;
$frequency = isset($_POST['frequency']) && trim((string)$_POST['frequency']) !== ''
    ? strtolower(trim((string)$_POST['frequency']))
    : 'daily';

// Validate date formats
$startTs = strtotime($startDate);
$endTs = strtotime($endDate);
if ($startTs === false || $endTs === false) {
    respond(['error' => true, 'message' => 'Invalid start_date or end_date format (expected YYYY-MM-DD)']);
}
if ($endTs < $startTs) {
    $endDate = $startDate;
    $endTs = $startTs;
}
$daysDiff = intval(round(($endTs - $startTs) / 86400));
if ($daysDiff > 180) {
    respond(['error' => true, 'message' => 'Prescription duration cannot exceed 180 days']);
}

// live camera tracking (optional)
$aiExercise = isset($_POST['ai_exercise']) ? strtolower(trim((string)$_POST['ai_exercise'])) : '';
$aiSide = isset($_POST['side']) ? strtolower(trim((string)$_POST['side'])) : '';
if ($aiExercise !== '' && !valid_ai_exercise($aiExercise)) {
    respond(['error' => true, 'message' => 'ai_exercise must be one of ' . implode(', ', tracked_exercise_ids())]);
}
if ($aiExercise !== '' && !valid_ai_side($aiSide)) {
    respond(['error' => true, 'message' => tracked_is_leg($aiExercise)
        ? 'Choose the lifted leg (left or right) for the tracked exercise'
        : 'Choose the arm (left or right) for the tracked exercise']);
}
$targetDeg = null;
if (isset($_POST['target_deg']) && trim((string)$_POST['target_deg']) !== '') {
    if ($aiExercise !== 'e4') {
        respond(['error' => true, 'message' => 'target_deg is only used for e4 (hip abduction)']);
    }
    $targetDeg = parse_target_deg($_POST['target_deg']);
    if ($targetDeg === false) {
        respond(['error' => true, 'message' => sprintf('target_deg must be a number between %.0f and %.0f degrees',
            E4_TARGET_MIN_DEG, E4_TARGET_MAX_DEG)]);
    }
}
if ($aiExercise === '') {
    $aiExercise = null;
    $aiSide = null;
}
ensure_ai_columns($conn);

if ($accountId <= 0 || $patientId <= 0 || $exerciseId <= 0) {
    respond(['error' => true, 'message' => 'account_id, patient_id and exercise_id are required']);
}
if ($sets <= 0 || $reps <= 0) {
    respond(['error' => true, 'message' => 'sets and reps must be greater than 0']);
}

$physioId = 0;
$lookup = $conn->prepare('SELECT id FROM physiotherapist WHERE account_id = ? LIMIT 1');
if (!$lookup) {
    respond(['error' => true, 'message' => 'Failed to prepare physio lookup: ' . $conn->error]);
}
$lookup->bind_param('i', $accountId);
$lookup->execute();
$res = $lookup->get_result();
if ($row = $res->fetch_assoc()) {
    $physioId = intval($row['id']);
}
$lookup->close();

if ($physioId <= 0) {
    respond(['error' => true, 'message' => 'Physiotherapist not found']);
}

$patientCheck = $conn->prepare('SELECT id FROM patient WHERE id = ? AND therapist_id = ? LIMIT 1');
if (!$patientCheck) {
    respond(['error' => true, 'message' => 'Failed to prepare patient check: ' . $conn->error]);
}
$patientCheck->bind_param('ii', $patientId, $physioId);
$patientCheck->execute();
$patientRes = $patientCheck->get_result();
$existsPatient = ($patientRes && $patientRes->fetch_assoc()) ? true : false;
$patientCheck->close();
if (!$existsPatient) {
    respond(['error' => true, 'message' => 'Patient is not assigned to this physiotherapist']);
}

$exerciseCheck = $conn->prepare('SELECT id FROM exercise WHERE id = ? LIMIT 1');
if (!$exerciseCheck) {
    respond(['error' => true, 'message' => 'Failed to prepare exercise check: ' . $conn->error]);
}
$exerciseCheck->bind_param('i', $exerciseId);
$exerciseCheck->execute();
$exerciseRes = $exerciseCheck->get_result();
$existsExercise = ($exerciseRes && $exerciseRes->fetch_assoc()) ? true : false;
$exerciseCheck->close();
if (!$existsExercise) {
    respond(['error' => true, 'message' => 'Exercise not found']);
}

function is_scheduled_for_date($dateStr, $frequency)
{
    if ($frequency === 'daily' || $frequency === '' || $frequency === null) {
        return true;
    }
    $isoDow = intval(date('N', strtotime($dateStr))); // 1 (Mon) to 7 (Sun)
    if ($frequency === 'weekdays') {
        return $isoDow >= 1 && $isoDow <= 5;
    }
    if ($frequency === 'weekends') {
        return $isoDow === 6 || $isoDow === 7;
    }
    // Specific days: comma-separated ISO day numbers (1..7) or day names ('mon,wed,fri')
    $parts = array_map('trim', explode(',', $frequency));
    $dayName = strtolower(date('D', strtotime($dateStr)));
    foreach ($parts as $p) {
        $p = strtolower($p);
        if ($p === (string)$isoDow || $p === $dayName || substr($p, 0, 3) === $dayName) {
            return true;
        }
    }
    return false;
}

$prescriptionId = 'rx_' . $patientId . '_' . time() . '_' . mt_rand(1000, 9999);
$curTs = $startTs;
$instanceIds = [];
$firstId = 0;

$insert = $conn->prepare('INSERT INTO patientexercise (patient_id, exercise_id, assigned_by, assigned_date, status, sets, reps, ai_exercise, side, target_deg, start_date, end_date, frequency, prescription_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
if (!$insert) {
    respond(['error' => true, 'message' => 'Failed to prepare assignment insert: ' . $conn->error]);
}

while ($curTs <= $endTs) {
    $curDate = date('Y-m-d', $curTs);
    if (is_scheduled_for_date($curDate, $frequency)) {
        $status = 'Pending';
        $insert->bind_param(
            'iiissiisdssss',
            $patientId,
            $exerciseId,
            $physioId,
            $curDate,
            $status,
            $sets,
            $reps,
            $aiExercise,
            $aiSide,
            $targetDeg,
            $startDate,
            $endDate,
            $frequency,
            $prescriptionId
        );
        if ($insert->execute()) {
            $insertedId = $conn->insert_id;
            $instanceIds[] = $insertedId;
            if ($firstId === 0) {
                $firstId = $insertedId;
            }
        }
    }
    $curTs = strtotime('+1 day', $curTs);
}
$insert->close();

if (empty($instanceIds)) {
    // Fallback: at least assign for start_date
    $status = 'Pending';
    $fb = $conn->prepare('INSERT INTO patientexercise (patient_id, exercise_id, assigned_by, assigned_date, status, sets, reps, ai_exercise, side, target_deg, start_date, end_date, frequency, prescription_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
    $fb->bind_param(
        'iiissiisdssss',
        $patientId,
        $exerciseId,
        $physioId,
        $startDate,
        $status,
        $sets,
        $reps,
        $aiExercise,
        $aiSide,
        $targetDeg,
        $startDate,
        $endDate,
        $frequency,
        $prescriptionId
    );
    $fb->execute();
    $firstId = $conn->insert_id;
    $instanceIds[] = $firstId;
    $fb->close();
}

// C. the patient is told that the routine changed
notif_init($conn);
notify_routine_update($conn, intval($firstId));

respond([
    'error' => false,
    'message' => 'Exercise assigned successfully for ' . count($instanceIds) . ' scheduled session(s)',
    'patient_exercise_id' => $firstId,
    'prescription_id' => $prescriptionId,
    'instances_count' => count($instanceIds),
    'start_date' => $startDate,
    'end_date' => $endDate,
    'frequency' => $frequency,
]);
