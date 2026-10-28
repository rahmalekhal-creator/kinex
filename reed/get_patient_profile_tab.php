<?php
require_once 'api_common.php';

$accountId = isset($_GET['account_id']) ? intval($_GET['account_id']) : 0;
if ($accountId <= 0) {
    api_respond(['error' => true, 'message' => 'account_id is required']);
}

$stmt = $conn->prepare(
    "SELECT p.id AS patient_id, p.account_id, p.clinic_id, p.therapist_id, p.name, p.phone, p.birth_date,
            a.email, COALESCE(a.Photo, '') AS photo, c.name AS clinic_name
     FROM patient p
     INNER JOIN account a ON a.id = p.account_id
     LEFT JOIN clinic c ON c.id = p.clinic_id
     WHERE p.account_id = ?
     LIMIT 1"
);
if (!$stmt) {
    api_respond(['error' => true, 'message' => 'Failed to prepare profile query: ' . $conn->error]);
}
$stmt->bind_param('i', $accountId);
$stmt->execute();
$res = $stmt->get_result();
$row = $res ? $res->fetch_assoc() : null;
$stmt->close();

if (!$row) {
    api_respond(['error' => true, 'message' => 'Patient profile not found']);
}

$photoRaw = trim((string)$row['photo']);
$photoUrl = '';
if ($photoRaw !== '') {
    if (preg_match('/^https?:\/\//i', $photoRaw)) {
        $photoUrl = $photoRaw;
    } else {
        $base = rtrim((isset($_SERVER['HTTPS']) ? 'https' : 'http') . '://' . $_SERVER['HTTP_HOST'] . '/reed/', '/');
        $photoUrl = $base . '/' . ltrim($photoRaw, '/');
    }
}

$therapist = null;
$therapistId = isset($row['therapist_id']) ? intval($row['therapist_id']) : 0;
if ($therapistId > 0) {
    $tStmt = $conn->prepare('SELECT id, account_id, name, specialization, phone FROM physiotherapist WHERE id = ? LIMIT 1');
    if ($tStmt) {
        $tStmt->bind_param('i', $therapistId);
        $tStmt->execute();
        $tRes = $tStmt->get_result();
        if ($t = $tRes->fetch_assoc()) {
            $therapist = [
                'physio_id' => intval($t['id']),
                'account_id' => intval($t['account_id']),
                'name' => (string)$t['name'],
                'specialization' => isset($t['specialization']) ? (string)$t['specialization'] : '',
                'phone' => isset($t['phone']) ? (string)$t['phone'] : '',
            ];
        }
        $tStmt->close();
    }
}

api_respond([
    'error' => false,
    'profile' => [
        'patient_id' => intval($row['patient_id']),
        'account_id' => intval($row['account_id']),
        'clinic_id' => intval($row['clinic_id']),
        'clinic_name' => isset($row['clinic_name']) ? (string)$row['clinic_name'] : '',
        'name' => (string)$row['name'],
        'phone' => isset($row['phone']) ? (string)$row['phone'] : '',
        'birth_date' => isset($row['birth_date']) ? (string)$row['birth_date'] : '',
        'email' => isset($row['email']) ? (string)$row['email'] : '',
        'photo_url' => $photoUrl,
    ],
    'therapist' => $therapist,
]);
