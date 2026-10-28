<?php
require_once 'api_common.php';

$accountId = isset($_GET['account_id']) ? intval($_GET['account_id']) : 0;
if ($accountId <= 0) {
    api_respond(['error' => true, 'message' => 'account_id is required']);
}

$clinicId = require_active_clinic_account($conn, $accountId);

$stmt = $conn->prepare(
    "SELECT c.id, c.description, c.symptoms, c.submitted_at, c.status,
            p.id AS patient_id, p.name AS patient_name,
            ph.name AS therapist_name
     FROM complaintform c
     INNER JOIN patient p ON p.id = c.patient_id
     LEFT JOIN physiotherapist ph ON ph.id = p.therapist_id
     WHERE p.clinic_id = ?
     ORDER BY c.submitted_at DESC, c.id DESC"
);
if (!$stmt) {
    api_respond(['error' => true, 'message' => 'Failed to prepare complaints query: ' . $conn->error]);
}
$stmt->bind_param('i', $clinicId);
$stmt->execute();
$res = $stmt->get_result();

$complaints = [];
while ($row = $res->fetch_assoc()) {
    $complaints[] = [
        'id' => intval($row['id']),
        'patient_id' => intval($row['patient_id']),
        'patient_name' => (string)$row['patient_name'],
        'therapist_name' => (string)($row['therapist_name'] ?? ''),
        'description' => (string)($row['description'] ?? ''),
        'symptoms' => (string)($row['symptoms'] ?? ''),
        'status' => (string)($row['status'] ?? 'pending'),
        'submitted_at' => (string)($row['submitted_at'] ?? ''),
    ];
}
$stmt->close();

api_respond([
    'error' => false,
    'clinic_id' => $clinicId,
    'complaints' => $complaints,
]);

