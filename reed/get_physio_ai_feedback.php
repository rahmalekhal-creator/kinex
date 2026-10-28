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

$accountId = isset($_GET['account_id']) ? intval($_GET['account_id']) : 0;
$patientId = isset($_GET['patient_id']) ? intval($_GET['patient_id']) : 0;
if ($accountId <= 0 || $patientId <= 0) {
    respond(['error' => true, 'message' => 'account_id and patient_id are required']);
}

$physioSql = 'SELECT id, clinic_id FROM physiotherapist WHERE account_id = ? LIMIT 1';
$physioStmt = $conn->prepare($physioSql);
if (!$physioStmt) {
    respond(['error' => true, 'message' => 'Failed to prepare physio lookup: ' . $conn->error]);
}
$physioStmt->bind_param('i', $accountId);
$physioStmt->execute();
$physioRes = $physioStmt->get_result();
$physio = $physioRes->fetch_assoc();
$physioStmt->close();
if (!$physio) {
    respond(['error' => true, 'message' => 'Physiotherapist not found']);
}

$physioId = intval($physio['id']);
$clinicId = intval($physio['clinic_id']);

$patientCheck = $conn->prepare('SELECT id FROM patient WHERE id = ? AND therapist_id = ? LIMIT 1');
if (!$patientCheck) {
    respond(['error' => true, 'message' => 'Failed to prepare patient check: ' . $conn->error]);
}
$patientCheck->bind_param('ii', $patientId, $physioId);
$patientCheck->execute();
$patientRes = $patientCheck->get_result();
$hasPatient = ($patientRes && $patientRes->fetch_assoc()) ? true : false;
$patientCheck->close();
if (!$hasPatient) {
    respond(['error' => true, 'message' => 'Patient not assigned to this physiotherapist']);
}

$hasActiveSubscription = false;
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

if (!$hasActiveSubscription) {
    respond(['error' => true, 'message' => 'AI feedback is available only with active clinic subscription']);
}

ensure_ai_columns($conn);
$sql = "SELECT af.id, af.progressreport_id AS progress_id, af.score, af.analysis, af.generated_at,
               pe.$peExerciseColumn AS exercise_id, pr.date AS progress_date, pe.ai_exercise,
               e.name AS exercise_name
        FROM aifeedback af
        INNER JOIN progressreport pr ON pr.id = af.progressreport_id
        INNER JOIN patientexercise pe ON pe.id = pr.ppid
        LEFT JOIN exercise e ON e.id = pe.$peExerciseColumn
        WHERE pe.patient_id = ?
        ORDER BY af.generated_at DESC, af.id DESC";
$stmt = $conn->prepare($sql);
if (!$stmt) {
    respond(['error' => true, 'message' => 'Failed to prepare AI feedback query: ' . $conn->error]);
}
$stmt->bind_param('i', $patientId);
$stmt->execute();
$result = $stmt->get_result();

$feedback = [];
while ($row = $result->fetch_assoc()) {
    $feedback[] = [
        'id' => intval($row['id']),
        'progress_id' => intval($row['progress_id']),
        'exercise_id' => intval($row['exercise_id']),
        'exercise_name' => isset($row['exercise_name']) ? (string)$row['exercise_name'] : 'Exercise',
        'ai_exercise' => ($row['ai_exercise'] !== null && $row['ai_exercise'] !== '') ? (string)$row['ai_exercise'] : null,
        'body_region' => tracked_region_of((string)$row['ai_exercise']),
        'score' => $row['score'] !== null ? floatval($row['score']) : null,
        'analysis' => $row['analysis'] !== null ? (string)$row['analysis'] : '',
        'progress_date' => isset($row['progress_date']) ? (string)$row['progress_date'] : '',
        'generated_at' => isset($row['generated_at']) ? (string)$row['generated_at'] : '',
    ];
}
$stmt->close();

respond([
    'error' => false,
    'feedback' => $feedback,
]);

