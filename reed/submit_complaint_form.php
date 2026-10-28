<?php
require_once 'api_common.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_respond(['error' => true, 'message' => 'Method not allowed']);
}

$accountId = isset($_POST['account_id']) ? intval($_POST['account_id']) : 0;
$description = isset($_POST['description']) ? trim((string)$_POST['description']) : '';
$symptoms = isset($_POST['symptoms']) ? trim((string)$_POST['symptoms']) : '';

if ($accountId <= 0 || $description === '') {
    api_respond(['error' => true, 'message' => 'account_id and description are required']);
}
if (strlen($description) < 5) {
    api_respond(['error' => true, 'message' => 'Description must be at least 5 characters']);
}

$patientId = resolve_patient_id_from_account($conn, $accountId);
if ($patientId <= 0) {
    api_respond(['error' => true, 'message' => 'Patient profile not found']);
}

$insert = $conn->prepare('INSERT INTO complaintform (patient_id, description, symptoms, status) VALUES (?, ?, ?, ?)');
if (!$insert) {
    api_respond(['error' => true, 'message' => 'Failed to prepare complaint insert: ' . $conn->error]);
}
$status = 'pending';
$insert->bind_param('isss', $patientId, $description, $symptoms, $status);
if (!$insert->execute()) {
    $insert->close();
    api_respond(['error' => true, 'message' => 'Failed to submit complaint: ' . $insert->error]);
}
$complaintId = intval($conn->insert_id);
$insert->close();

api_respond([
    'error' => false,
    'message' => 'Complaint submitted successfully',
    'complaint_id' => $complaintId,
]);

