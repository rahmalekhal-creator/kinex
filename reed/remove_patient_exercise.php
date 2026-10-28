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

$accountId = isset($_POST['account_id']) ? intval($_POST['account_id']) : 0;
$patientExerciseId = isset($_POST['patient_exercise_id']) ? intval($_POST['patient_exercise_id']) : 0;
$prescriptionId = isset($_POST['prescription_id']) ? trim((string)$_POST['prescription_id']) : '';

if ($accountId <= 0 || ($patientExerciseId <= 0 && $prescriptionId === '')) {
    respond(['error' => true, 'message' => 'account_id and patient_exercise_id or prescription_id are required']);
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

// If no prescriptionId given, check if patientExerciseId belongs to a prescription
if ($prescriptionId === '' && $patientExerciseId > 0) {
    $q = $conn->prepare('SELECT pe.prescription_id FROM patientexercise pe 
                         INNER JOIN patient p ON p.id = pe.patient_id 
                         WHERE pe.id = ? AND p.therapist_id = ? LIMIT 1');
    if ($q) {
        $q->bind_param('ii', $patientExerciseId, $physioId);
        $q->execute();
        $r = $q->get_result();
        if ($row = $r->fetch_assoc()) {
            $prescriptionId = (string)($row['prescription_id'] ?? '');
        }
        $q->close();
    }
}

if ($prescriptionId !== '') {
    $deleteSql = 'DELETE pe FROM patientexercise pe
                  INNER JOIN patient p ON p.id = pe.patient_id
                  WHERE pe.prescription_id = ? AND p.therapist_id = ?';
    $del = $conn->prepare($deleteSql);
    if (!$del) {
        respond(['error' => true, 'message' => 'Failed to prepare delete: ' . $conn->error]);
    }
    $del->bind_param('si', $prescriptionId, $physioId);
    $del->execute();
    $affected = $del->affected_rows;
    $del->close();
} else {
    $deleteSql = 'DELETE pe FROM patientexercise pe
                  INNER JOIN patient p ON p.id = pe.patient_id
                  WHERE pe.id = ? AND p.therapist_id = ?';
    $del = $conn->prepare($deleteSql);
    if (!$del) {
        respond(['error' => true, 'message' => 'Failed to prepare delete: ' . $conn->error]);
    }
    $del->bind_param('ii', $patientExerciseId, $physioId);
    $del->execute();
    $affected = $del->affected_rows;
    $del->close();
}

if ($affected <= 0) {
    respond(['error' => true, 'message' => 'Exercise assignment not found or not allowed']);
}

respond(['error' => false, 'message' => 'Exercise removed successfully', 'removed_count' => $affected]);
