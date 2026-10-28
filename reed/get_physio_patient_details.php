<?php
ob_start();
ini_set('display_errors', '0');
error_reporting(E_ALL);
header('Content-Type: application/json; charset=UTF-8');

require_once 'db.php';
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

$accountId = isset($_GET['account_id']) ? intval($_GET['account_id']) : 0;
$patientId = isset($_GET['patient_id']) ? intval($_GET['patient_id']) : 0;
if ($accountId <= 0 || $patientId <= 0) {
    respond(['error' => true, 'message' => 'account_id and patient_id are required']);
}

$physioId = 0;
$physioLookup = $conn->prepare('SELECT id FROM physiotherapist WHERE account_id = ? LIMIT 1');
if (!$physioLookup) {
    respond(['error' => true, 'message' => 'Failed to prepare physio lookup: ' . $conn->error]);
}
$physioLookup->bind_param('i', $accountId);
$physioLookup->execute();
$physioRes = $physioLookup->get_result();
if ($row = $physioRes->fetch_assoc()) {
    $physioId = intval($row['id']);
}
$physioLookup->close();

if ($physioId <= 0) {
    respond(['error' => true, 'message' => 'Physiotherapist not found']);
}

$patientStmt = $conn->prepare('SELECT id, account_id, name, phone FROM patient WHERE id = ? AND therapist_id = ? LIMIT 1');
if (!$patientStmt) {
    respond(['error' => true, 'message' => 'Failed to prepare patient query: ' . $conn->error]);
}
$patientStmt->bind_param('ii', $patientId, $physioId);
$patientStmt->execute();
$patientRes = $patientStmt->get_result();
$patient = $patientRes->fetch_assoc();
$patientStmt->close();

if (!$patient) {
    respond(['error' => true, 'message' => 'Patient not found for this physiotherapist']);
}

function resolvePatientExerciseExerciseColumn(mysqli $conn)
{
    $allowed = ['exercise_id', 'exercice_id', 'exerciseId', 'Exercise_exerciseID'];
    $res = $conn->query('SHOW COLUMNS FROM patientexercise');
    if (!$res) {
        return null;
    }

    $columns = [];
    while ($row = $res->fetch_assoc()) {
        if (isset($row['Field'])) {
            $columns[] = (string)$row['Field'];
        }
    }

    foreach ($allowed as $name) {
        if (in_array($name, $columns, true)) {
            return $name;
        }
    }

    return null;
}

$peExerciseColumn = resolvePatientExerciseExerciseColumn($conn);
if ($peExerciseColumn === null) {
    respond(['error' => true, 'message' => 'Exercise reference column not found in patientexercise']);
}

function exercise_has_column(mysqli $conn, $column)
{
    $safe = $conn->real_escape_string((string)$column);
    $res = $conn->query("SHOW COLUMNS FROM exercise LIKE '{$safe}'");
    return $res && $res->num_rows > 0;
}

ensure_ai_columns($conn);

$todayDate = date('Y-m-d');

// Query all scheduled exercise instances with their latest progress report & AI feedback
$assignedSql = "SELECT pe.id, pe.exercise_id, pe.assigned_date, pe.start_date, pe.end_date, pe.frequency, pe.prescription_id,
                       pe.status, pe.sets, pe.reps, pe.ai_exercise, pe.side, pe.target_deg,
                       e.name, e.video_url,
                       pr.id AS progress_id, pr.date AS progress_date, pr.reps_done, pr.pain_level, pr.notes,
                       af.id AS ai_feedback_id
                FROM patientexercise pe
                INNER JOIN exercise e ON e.id = pe.$peExerciseColumn
                LEFT JOIN (
                    SELECT p1.*
                    FROM progressreport p1
                    INNER JOIN (
                        SELECT ppid, MAX(date) AS max_date
                        FROM progressreport
                        GROUP BY ppid
                    ) p2 ON p1.ppid = p2.ppid AND p1.date = p2.max_date
                ) pr ON pr.ppid = pe.id
                LEFT JOIN aifeedback af ON af.progress_report_id = pr.id
                WHERE pe.patient_id = ?
                ORDER BY pe.assigned_date DESC, pe.id DESC";

$assignedStmt = $conn->prepare($assignedSql);
if (!$assignedStmt) {
    respond(['error' => true, 'message' => 'Failed to prepare assigned exercises query: ' . $conn->error]);
}
$assignedStmt->bind_param('i', $patientId);
$assignedStmt->execute();
$assignedRes = $assignedStmt->get_result();

$allRows = [];
$assignedExercises = [];
$dailyInstances = [];
$prescriptionsMap = [];

while ($row = $assignedRes->fetch_assoc()) {
    $peId = intval($row['id']);
    $exId = intval($row['exercise_id']);
    $exName = (string)$row['name'];
    $assignedDate = isset($row['assigned_date']) ? substr((string)$row['assigned_date'], 0, 10) : '';
    $startDate = isset($row['start_date']) && trim((string)$row['start_date']) !== '' ? (string)$row['start_date'] : $assignedDate;
    $endDate = isset($row['end_date']) && trim((string)$row['end_date']) !== '' ? (string)$row['end_date'] : $assignedDate;
    $frequency = isset($row['frequency']) && trim((string)$row['frequency']) !== '' ? (string)$row['frequency'] : 'daily';
    $rxId = isset($row['prescription_id']) && trim((string)$row['prescription_id']) !== ''
        ? (string)$row['prescription_id']
        : 'rx_legacy_' . $peId;

    $rawStatus = isset($row['status']) ? (string)$row['status'] : 'Pending';
    $statusLower = strtolower(trim($rawStatus));
    $isCompleted = ($statusLower === 'completed' || $statusLower === 'done');

    // Compute status
    if ($isCompleted) {
        $computedStatus = 'completed';
    } elseif ($assignedDate !== '' && $assignedDate < $todayDate) {
        $computedStatus = 'missed';
    } elseif ($assignedDate !== '' && $assignedDate === $todayDate) {
        $computedStatus = 'pending';
    } else {
        $computedStatus = 'upcoming';
    }

    $progressId = $row['progress_id'] !== null ? intval($row['progress_id']) : 0;
    $aiFeedbackId = $row['ai_feedback_id'] !== null ? intval($row['ai_feedback_id']) : 0;
    $repsDone = $row['reps_done'] !== null ? intval($row['reps_done']) : null;
    $painLevel = $row['pain_level'] !== null ? intval($row['pain_level']) : null;
    $notes = $row['notes'] !== null ? (string)$row['notes'] : '';

    $instanceItem = [
        'id' => $peId,
        'prescription_id' => $rxId,
        'exercise_id' => $exId,
        'exercise_name' => $exName,
        'name' => $exName,
        'video_url' => isset($row['video_url']) ? (string)$row['video_url'] : '',
        'date' => $assignedDate,
        'assigned_date' => $assignedDate,
        'start_date' => $startDate,
        'end_date' => $endDate,
        'frequency' => $frequency,
        'status' => $computedStatus,
        'raw_status' => $rawStatus,
        'is_completed' => $isCompleted ? 1 : 0,
        'is_missed' => ($computedStatus === 'missed') ? 1 : 0,
        'is_pending' => ($computedStatus === 'pending') ? 1 : 0,
        'is_upcoming' => ($computedStatus === 'upcoming') ? 1 : 0,
        'sets' => intval($row['sets']),
        'reps' => intval($row['reps']),
        'ai_exercise' => ($row['ai_exercise'] !== null && $row['ai_exercise'] !== '') ? (string)$row['ai_exercise'] : null,
        'side' => ($row['side'] !== null && $row['side'] !== '') ? (string)$row['side'] : null,
        'body_region' => tracked_region_of((string)$row['ai_exercise']),
        'target_deg' => ($row['target_deg'] !== null) ? floatval($row['target_deg']) : null,
        'progress_id' => $progressId,
        'has_ai_feedback' => ($aiFeedbackId > 0 || $progressId > 0),
        'reps_done' => $repsDone,
        'pain_level' => $painLevel,
        'notes' => $notes,
        'progress_date' => isset($row['progress_date']) ? (string)$row['progress_date'] : '',
    ];

    $dailyInstances[] = $instanceItem;
    $assignedExercises[] = $instanceItem; // for backward compatibility

    // Aggregate into prescriptions
    if (!isset($prescriptionsMap[$rxId])) {
        $prescriptionsMap[$rxId] = [
            'prescription_id' => $rxId,
            'id' => $peId, // representative id
            'exercise_id' => $exId,
            'name' => $exName,
            'video_url' => isset($row['video_url']) ? (string)$row['video_url'] : '',
            'start_date' => $startDate,
            'end_date' => $endDate,
            'frequency' => $frequency,
            'sets' => intval($row['sets']),
            'reps' => intval($row['reps']),
            'ai_exercise' => ($row['ai_exercise'] !== null && $row['ai_exercise'] !== '') ? (string)$row['ai_exercise'] : null,
            'side' => ($row['side'] !== null && $row['side'] !== '') ? (string)$row['side'] : null,
            'body_region' => tracked_region_of((string)$row['ai_exercise']),
            'target_deg' => ($row['target_deg'] !== null) ? floatval($row['target_deg']) : null,
            'total_days' => 0,
            'completed_days' => 0,
            'missed_days' => 0,
            'pending_days' => 0,
            'upcoming_days' => 0,
        ];
    }
    // Update min/max start/end date if multiple rows in prescription
    if ($startDate < $prescriptionsMap[$rxId]['start_date']) {
        $prescriptionsMap[$rxId]['start_date'] = $startDate;
    }
    if ($endDate > $prescriptionsMap[$rxId]['end_date']) {
        $prescriptionsMap[$rxId]['end_date'] = $endDate;
    }

    $prescriptionsMap[$rxId]['total_days']++;
    if ($isCompleted) {
        $prescriptionsMap[$rxId]['completed_days']++;
    } elseif ($computedStatus === 'missed') {
        $prescriptionsMap[$rxId]['missed_days']++;
    } elseif ($computedStatus === 'pending') {
        $prescriptionsMap[$rxId]['pending_days']++;
    } else {
        $prescriptionsMap[$rxId]['upcoming_days']++;
    }
}
$assignedStmt->close();

// Finalize prescriptions and split into active vs past
$activePrescriptions = [];
$pastPrescriptions = [];
$prescriptions = [];

foreach ($prescriptionsMap as $rxId => $rx) {
    $isActive = ($rx['end_date'] >= $todayDate);
    $rx['is_active'] = $isActive ? 1 : 0;
    $totalDays = $rx['total_days'];
    $completedDays = $rx['completed_days'];
    $rx['progress_percent'] = $totalDays > 0 ? intval(round(($completedDays * 100) / $totalDays)) : 0;
    $rx['status'] = $isActive ? 'Active' : ($completedDays >= $totalDays ? 'Completed' : 'Ended');

    $prescriptions[] = $rx;
    if ($isActive) {
        $activePrescriptions[] = $rx;
    } else {
        $pastPrescriptions[] = $rx;
    }
}

// Compute adherence stats across prescription span up to today:
// (Total Completed Instances / Total Scheduled Instances where date <= Today) * 100
$scheduledToDate = 0;
$completedToDate = 0;
$missedCount = 0;
$pendingToday = 0;
$upcomingCount = 0;

foreach ($dailyInstances as $inst) {
    $d = $inst['date'];
    $s = $inst['status'];
    if ($d !== '' && $d <= $todayDate) {
        $scheduledToDate++;
        if ($s === 'completed') {
            $completedToDate++;
        } elseif ($s === 'missed') {
            $missedCount++;
        } elseif ($s === 'pending') {
            $pendingToday++;
        }
    } else {
        $upcomingCount++;
    }
}
$adherencePercent = $scheduledToDate > 0 ? intval(round(($completedToDate * 100) / $scheduledToDate)) : 0;

$adherenceStats = [
    'adherence_percent' => $adherencePercent,
    'scheduled_to_date' => $scheduledToDate,
    'completed_to_date' => $completedToDate,
    'missed_count' => $missedCount,
    'pending_today' => $pendingToday,
    'upcoming_count' => $upcomingCount,
    'total_all_time' => count($dailyInstances),
];

// Exercise catalog
$hasVideoUrl = exercise_has_column($conn, 'video_url');
$hasDifficulty = exercise_has_column($conn, 'difficulty');
$videoSelect = $hasVideoUrl ? 'COALESCE(video_url, "") AS video_url' : '"" AS video_url';
$difficultySelect = $hasDifficulty ? 'COALESCE(difficulty, "") AS difficulty' : '"" AS difficulty';

$catalogSql = "SELECT id, name, {$videoSelect}, {$difficultySelect} FROM exercise ORDER BY name ASC";
$catalogStmt = $conn->prepare($catalogSql);
$exerciseCatalog = [];
if ($catalogStmt) {
    $catalogStmt->execute();
    $catalogRes = $catalogStmt->get_result();
    while ($row = $catalogRes->fetch_assoc()) {
        $exerciseCatalog[] = [
            'id' => intval($row['id']),
            'name' => (string)$row['name'],
            'video_url' => isset($row['video_url']) ? (string)$row['video_url'] : '',
            'difficulty' => isset($row['difficulty']) ? (string)$row['difficulty'] : '',
        ];
    }
    $catalogStmt->close();
}

// Progress logs (backward compatible)
$logsSql = "SELECT pr.id, pr.ppid, pe.$peExerciseColumn AS exercise_id, pr.date, pr.reps_done, pr.pain_level, pr.notes, 
                   COALESCE(e.name, 'Exercise') AS exercise_name,
                   af.id AS ai_feedback_id
            FROM progressreport pr
            INNER JOIN patientexercise pe ON pe.id = pr.ppid
            LEFT JOIN exercise e ON e.id = pe.$peExerciseColumn
            LEFT JOIN aifeedback af ON af.progress_report_id = pr.id
            WHERE pe.patient_id = ?
            ORDER BY pr.date DESC, pr.id DESC";
$logsStmt = $conn->prepare($logsSql);
$progressLogs = [];
if ($logsStmt) {
    $logsStmt->bind_param('i', $patientId);
    $logsStmt->execute();
    $logsRes = $logsStmt->get_result();
    while ($row = $logsRes->fetch_assoc()) {
        $progressLogs[] = [
            'id' => intval($row['id']),
            'ppid' => intval($row['ppid']),
            'exercise_id' => intval($row['exercise_id']),
            'exercise_name' => isset($row['exercise_name']) ? (string)$row['exercise_name'] : 'Exercise',
            'date' => isset($row['date']) ? (string)$row['date'] : '',
            'reps_done' => $row['reps_done'] !== null ? intval($row['reps_done']) : null,
            'pain_level' => $row['pain_level'] !== null ? intval($row['pain_level']) : null,
            'notes' => $row['notes'] !== null ? (string)$row['notes'] : '',
            'has_ai_feedback' => ($row['ai_feedback_id'] !== null && intval($row['ai_feedback_id']) > 0),
        ];
    }
    $logsStmt->close();
}

respond([
    'error' => false,
    'patient' => [
        'patient_id' => intval($patient['id']),
        'account_id' => intval($patient['account_id']),
        'name' => (string)$patient['name'],
        'phone' => isset($patient['phone']) ? (string)$patient['phone'] : '',
    ],
    'adherence_stats' => $adherenceStats,
    'prescriptions' => $prescriptions,
    'active_prescriptions' => $activePrescriptions,
    'past_prescriptions' => $pastPrescriptions,
    'daily_instances' => $dailyInstances,
    'assigned_exercises' => $assignedExercises,
    'exercise_catalog' => $exerciseCatalog,
    'progress_logs' => $progressLogs,
    'e4_progress' => e4_progress($conn, $patientId),
]);
