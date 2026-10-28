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
    respond(array('error' => true, 'message' => 'Database connection not initialized'));
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
    respond(array('error' => true, 'message' => 'Exercise reference column not found in patientexercise'));
}
$accountId = isset($_GET['account_id']) ? intval($_GET['account_id']) : 0;
if ($accountId <= 0) {
    respond(array('error' => true, 'message' => 'account_id is required'));
}
$filter = isset($_GET['filter']) ? strtolower(trim((string)$_GET['filter'])) : 'all';
$allowedFilters = array('all', 'today', 'completed', 'pending');
if (!in_array($filter, $allowedFilters, true)) {
    $filter = 'all';
}
$patientId = 0;
$clinicId = 0;
$hasActiveSubscription = false;
$patientLookup = $conn->prepare('SELECT id, clinic_id FROM patient WHERE account_id = ? LIMIT 1');
if ($patientLookup) {
    $patientLookup->bind_param('i', $accountId);
    $patientLookup->execute();
    $res = $patientLookup->get_result();
    if ($row = $res->fetch_assoc()) {
        $patientId = intval($row['id']);
        $clinicId = isset($row['clinic_id']) ? intval($row['clinic_id']) : 0;
    }
    $patientLookup->close();
}
if ($patientId <= 0) {
    respond(['error' => true, 'message' => 'Patient profile not found']);
}
if ($clinicId > 0) {
    $subStmt = $conn->prepare("SELECT id FROM subscription WHERE clinic_id = ? AND LOWER(TRIM(COALESCE(status,'active'))) = 'active' LIMIT 1");
    if ($subStmt) {
        $subStmt->bind_param('i', $clinicId);
        $subStmt->execute();
        $subRes = $subStmt->get_result();
        $hasActiveSubscription = ($subRes && $subRes->fetch_assoc()) ? true : false;
        $subStmt->close();
    }
}
$whereClause = 'pe.patient_id = ?';
if ($filter === 'today') {
    $whereClause .= ' AND DATE(pe.assigned_date) = CURDATE()';
} elseif ($filter === 'completed') {
    $whereClause .= " AND LOWER(TRIM(COALESCE(pe.status, 'pending'))) IN ('completed', 'done')";
} elseif ($filter === 'pending') {
    $whereClause .= " AND LOWER(TRIM(COALESCE(pe.status, 'pending'))) NOT IN ('completed', 'done')";
}
ensure_ai_columns($conn);
$sql = "SELECT
            pe.id,
            pe.ai_exercise,
            pe.side,
            pe.target_deg,
            pe.start_date,
            pe.end_date,
            pe.frequency,
            pe.prescription_id,
            pe.$peExerciseColumn AS exercise_id,
            COALESCE(e.name, 'Exercise') AS name,
            COALESCE(e.description, '') AS description,
            COALESCE(e.video_url, '') AS video_url,
            COALESCE(pe.sets, 0) AS sets,
            COALESCE(pe.reps, 0) AS reps,
            pe.assigned_date,
            COALESCE(pe.status, 'pending') AS status,
            COALESCE(ph.name, 'Physiotherapist') AS assigned_by_name,
            latest_pr.reps_done,
            latest_pr.pain_level,
            latest_pr.notes AS progress_notes,
            latest_pr.date AS last_report_date
        FROM patientexercise pe
        INNER JOIN exercise e ON e.id = pe.$peExerciseColumn
        LEFT JOIN patient p ON p.id = pe.patient_id
        LEFT JOIN physiotherapist ph ON ph.id = p.therapist_id
        LEFT JOIN (
            SELECT pr1.ppid, pr1.reps_done, pr1.pain_level, pr1.notes, pr1.date
            FROM progressreport pr1
            INNER JOIN (
                SELECT ppid, MAX(date) AS max_date
                FROM progressreport
                GROUP BY ppid
            ) pr2 ON pr1.ppid = pr2.ppid AND pr1.date = pr2.max_date
        ) latest_pr ON latest_pr.ppid = pe.id
        WHERE $whereClause
        ORDER BY pe.assigned_date DESC, pe.id DESC";
$stmt = $conn->prepare($sql);
if (!$stmt) {
    respond(array('error' => true, 'message' => 'Failed to prepare query: ' . $conn->error));
}
$stmt->bind_param('i', $patientId);
$stmt->execute();
$result = $stmt->get_result();
$usualLiftValue = false;
$usualLift = function () use ($conn, $patientId, &$usualLiftValue) {
    if ($usualLiftValue === false) {
        $usualLiftValue = e4_usual_lift($conn, $patientId);
    }
    return $usualLiftValue;
};
$exercises = array();
$total = 0;
$completed = 0;
$todayDate = date('Y-m-d');
while ($row = $result->fetch_assoc()) {
    $total++;
    $statusText = isset($row['status']) ? (string)$row['status'] : 'pending';
    $status = strtolower(trim($statusText));
    $isCompleted = ($status === 'completed' || $status === 'done');
    if ($isCompleted) {
        $completed++;
    }
    $reps = intval($row['reps']);
    $sets = intval($row['sets']);
    $repsDone = ($row['reps_done'] !== null) ? intval($row['reps_done']) : null;
    $totalTarget = ($sets > 0 && $reps > 0) ? ($sets * $reps) : $reps;
    $completionPercent = 0;
    if ($repsDone !== null && $totalTarget > 0) {
        $completionPercent = min(100, intval(round(($repsDone * 100) / $totalTarget)));
    } elseif ($isCompleted) {
        $completionPercent = 100;
    }

    $assignedDate = isset($row['assigned_date']) ? substr((string)$row['assigned_date'], 0, 10) : '';
    $isPast = ($assignedDate !== '' && $assignedDate < $todayDate);
    $isToday = ($assignedDate !== '' && $assignedDate === $todayDate);
    $isFuture = ($assignedDate !== '' && $assignedDate > $todayDate);

    $computedStatus = $statusText;
    if ($isCompleted) {
        $computedStatus = 'Completed';
    } elseif ($isPast) {
        $computedStatus = 'Missed';
    } elseif ($isToday) {
        $computedStatus = 'Pending';
    } else {
        $computedStatus = 'Upcoming';
    }

    $exercises[] = array(
        'id' => intval($row['id']),
        'ppid' => intval($row['id']),
        'exercise_id' => intval($row['exercise_id']),
        'name' => isset($row['name']) ? (string)$row['name'] : 'Exercise',
        'description' => isset($row['description']) ? (string)$row['description'] : '',
        'video_url' => isset($row['video_url']) ? (string)$row['video_url'] : '',
        'sets' => intval($row['sets']),
        'reps' => $reps,
        'assigned_date' => $assignedDate,
        'start_date' => isset($row['start_date']) ? (string)$row['start_date'] : $assignedDate,
        'end_date' => isset($row['end_date']) ? (string)$row['end_date'] : $assignedDate,
        'frequency' => isset($row['frequency']) ? (string)$row['frequency'] : 'daily',
        'prescription_id' => isset($row['prescription_id']) ? (string)$row['prescription_id'] : null,
        'assigned_by_name' => isset($row['assigned_by_name']) ? (string)$row['assigned_by_name'] : 'Physiotherapist',
        'status' => $statusText,
        'computed_status' => $computedStatus,
        'is_completed' => $isCompleted ? 1 : 0,
        'is_missed' => ($computedStatus === 'Missed') ? 1 : 0,
        'is_today' => $isToday ? 1 : 0,
        'reps_done' => $repsDone,
        'pain_level' => ($row['pain_level'] !== null) ? intval($row['pain_level']) : null,
        'progress_notes' => ($row['progress_notes'] !== null) ? (string)$row['progress_notes'] : null,
        'last_report_date' => ($row['last_report_date'] !== null) ? (string)$row['last_report_date'] : null,
        'completion_percent' => $completionPercent,
        'ai_exercise' => ($row['ai_exercise'] !== null && $row['ai_exercise'] !== '') ? (string)$row['ai_exercise'] : null,
        'side' => ($row['side'] !== null && $row['side'] !== '') ? (string)$row['side'] : null,
        'body_region' => tracked_region_of((string)$row['ai_exercise']),
        'target_deg' => ($row['target_deg'] !== null) ? floatval($row['target_deg']) : null,
        'usual_lift_deg' => ($row['ai_exercise'] === 'e4') ? $usualLift() : null,
    );
}
$stmt->close();

// Always compute strict Today statistics regardless of filter
$todayTotal = 0;
$todayCompleted = 0;
$todayStmt = $conn->prepare("SELECT COUNT(*) AS total, 
    SUM(CASE WHEN LOWER(TRIM(COALESCE(status, 'pending'))) IN ('completed', 'done') THEN 1 ELSE 0 END) AS completed
    FROM patientexercise WHERE patient_id = ? AND DATE(assigned_date) = CURDATE()");
if ($todayStmt) {
    $todayStmt->bind_param('i', $patientId);
    $todayStmt->execute();
    $todayRes = $todayStmt->get_result()->fetch_assoc();
    if ($todayRes) {
        $todayTotal = intval($todayRes['total']);
        $todayCompleted = intval($todayRes['completed']);
    }
    $todayStmt->close();
}
$todayPercent = $todayTotal > 0 ? intval(round(($todayCompleted * 100) / $todayTotal)) : 0;

$percent = $total > 0 ? intval(round(($completed * 100) / $total)) : 0;

respond(array(
    'error' => false,
    'access' => array(
        'has_active_subscription' => $hasActiveSubscription ? 1 : 0,
        'can_record_video' => $hasActiveSubscription ? 1 : 0,
    ),
    'summary' => array(
        'total' => $total,
        'completed' => $completed,
        'percent' => $percent,
        'filter' => $filter,
        'today_total' => $todayTotal,
        'today_completed' => $todayCompleted,
        'today_percent' => $todayPercent,
    ),
    'exercises' => $exercises,
));
