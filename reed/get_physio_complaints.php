<?php
require_once 'api_common.php';

$accountId = isset($_GET['account_id']) ? intval($_GET['account_id']) : 0;
if ($accountId <= 0) {
    api_respond(['error' => true, 'message' => 'account_id is required']);
}

$physioId = 0;
$lookup = $conn->prepare('SELECT id FROM physiotherapist WHERE account_id = ? LIMIT 1');
if ($lookup) {
    $lookup->bind_param('i', $accountId);
    $lookup->execute();
    $lookupRes = $lookup->get_result();
    if ($row = $lookupRes->fetch_assoc()) {
        $physioId = intval($row['id']);
    }
    $lookup->close();
}
if ($physioId <= 0) {
    api_respond(['error' => true, 'message' => 'Physiotherapist profile not found']);
}

$stmt = $conn->prepare(
    "SELECT c.id, c.description, c.symptoms, c.submitted_at, c.status,
            p.id AS patient_id, p.name AS patient_name
     FROM complaintform c
     INNER JOIN patient p ON p.id = c.patient_id
     WHERE p.therapist_id = ?
     ORDER BY c.submitted_at DESC, c.id DESC"
);
if (!$stmt) {
    api_respond(['error' => true, 'message' => 'Failed to prepare complaints query: ' . $conn->error]);
}
$stmt->bind_param('i', $physioId);
$stmt->execute();
$res = $stmt->get_result();

$complaints = [];
while ($row = $res->fetch_assoc()) {
    $complaints[] = [
        'id' => intval($row['id']),
        'patient_id' => intval($row['patient_id']),
        'patient_name' => (string)$row['patient_name'],
        'description' => (string)($row['description'] ?? ''),
        'symptoms' => (string)($row['symptoms'] ?? ''),
        'status' => (string)($row['status'] ?? 'pending'),
        'submitted_at' => (string)($row['submitted_at'] ?? ''),
    ];
}
$stmt->close();

api_respond([
    'error' => false,
    'physio_id' => $physioId,
    'complaints' => $complaints,
]);

