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
ensure_ai_columns($conn);

$accountId = isset($_GET['account_id']) ? intval($_GET['account_id']) : 0;
if ($accountId <= 0) {
    respond(['error' => true, 'message' => 'account_id is required']);
}

$physioId = 0;
$clinicId = 0;
$lookup = $conn->prepare('SELECT id, clinic_id FROM physiotherapist WHERE account_id = ? LIMIT 1');
if (!$lookup) {
    respond(['error' => true, 'message' => 'Failed to prepare physio lookup: ' . $conn->error]);
}
$lookup->bind_param('i', $accountId);
$lookup->execute();
$res = $lookup->get_result();
if ($row = $res->fetch_assoc()) {
    $physioId = intval($row['id']);
    $clinicId = intval($row['clinic_id']);
}
$lookup->close();

if ($physioId <= 0) {
    respond(['error' => true, 'message' => 'Physiotherapist not found']);
}

$hasActiveSubscription = false;
if ($clinicId > 0) {
    $sub = $conn->prepare("SELECT id FROM subscription WHERE clinic_id = ? AND LOWER(TRIM(COALESCE(status,'active'))) = 'active' LIMIT 1");
    if ($sub) {
        $sub->bind_param('i', $clinicId);
        $sub->execute();
        $subRes = $sub->get_result();
        $hasActiveSubscription = ($subRes && $subRes->fetch_assoc()) ? true : false;
        $sub->close();
    }
}

// Calculate adherence across prescription span up to today:
// (Total Completed Instances / Total Scheduled Instances where date <= Today) * 100.
// Missed past instances are factored in; upcoming future instances do not penalize current adherence.
$sql = "SELECT p.id, p.account_id, p.name, p.phone, p.birth_date,
               SUM(CASE WHEN pe.id IS NOT NULL AND DATE(pe.assigned_date) <= CURDATE() THEN 1 ELSE 0 END) AS assigned_count,
               SUM(CASE WHEN pe.id IS NOT NULL AND DATE(pe.assigned_date) <= CURDATE() AND LOWER(TRIM(COALESCE(pe.status, 'pending'))) IN ('completed','done') THEN 1 ELSE 0 END) AS completed_count,
               SUM(CASE WHEN pe.id IS NOT NULL AND DATE(pe.assigned_date) < CURDATE() AND LOWER(TRIM(COALESCE(pe.status, 'pending'))) NOT IN ('completed','done') THEN 1 ELSE 0 END) AS missed_count,
               SUM(CASE WHEN pe.id IS NOT NULL AND DATE(pe.assigned_date) > CURDATE() THEN 1 ELSE 0 END) AS upcoming_count,
               COUNT(pe.id) AS total_all_time
        FROM patient p
        LEFT JOIN patientexercise pe ON pe.patient_id = p.id
        WHERE p.therapist_id = ?
        GROUP BY p.id, p.account_id, p.name, p.phone, p.birth_date
        ORDER BY p.name ASC";
$stmt = $conn->prepare($sql);
if (!$stmt) {
    respond(['error' => true, 'message' => 'Failed to prepare patients query: ' . $conn->error]);
}
$stmt->bind_param('i', $physioId);
$stmt->execute();
$result = $stmt->get_result();

$patients = [];
while ($p = $result->fetch_assoc()) {
    $assignedToDate = intval($p['assigned_count']);
    $completedToDate = intval($p['completed_count']);
    $adherencePercent = $assignedToDate > 0 ? intval(round(($completedToDate * 100) / $assignedToDate)) : 0;

    $patients[] = [
        'patient_id' => intval($p['id']),
        'account_id' => intval($p['account_id']),
        'name' => (string)$p['name'],
        'phone' => isset($p['phone']) ? (string)$p['phone'] : '',
        'birth_date' => isset($p['birth_date']) ? (string)$p['birth_date'] : '',
        'assigned_count' => $assignedToDate,
        'completed_count' => $completedToDate,
        'missed_count' => intval($p['missed_count']),
        'upcoming_count' => intval($p['upcoming_count']),
        'adherence_percent' => $adherencePercent,
        'total_all_time' => intval($p['total_all_time']),
    ];
}
$stmt->close();

respond([
    'error' => false,
    'physio_id' => $physioId,
    'access' => [
        'has_active_subscription' => $hasActiveSubscription ? 1 : 0,
        'can_view_ai_feedback' => $hasActiveSubscription ? 1 : 0,
    ],
    'patients' => $patients,
]);
