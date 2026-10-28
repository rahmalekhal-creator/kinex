<?php
require_once 'api_common.php';

$accountId = isset($_GET['account_id']) ? intval($_GET['account_id']) : 0;
if ($accountId <= 0) {
    api_respond(['error' => true, 'message' => 'account_id is required']);
}

$activeClinicId = require_active_clinic_account($conn, $accountId);

$photoSelect = table_has_column($conn, 'account', 'photo')
    ? "COALESCE(a.photo, '') AS photo_url"
    : (table_has_column($conn, 'account', 'Photo') ? "COALESCE(a.Photo, '') AS photo_url" : "'' AS photo_url");

$clinicStmt = $conn->prepare(
    "SELECT c.id, c.account_id, c.name, c.address, c.phone, " .
    (table_has_column($conn, 'clinic', 'justif') ? "c.justif" : "NULL AS justif") .
    ", $photoSelect" .
    " FROM clinic c JOIN account a ON a.id = c.account_id WHERE c.account_id = ? AND a.role = 'clinic' LIMIT 1"
);
if (!$clinicStmt) {
    api_respond(['error' => true, 'message' => 'Failed to prepare clinic lookup: ' . $conn->error]);
}
$clinicStmt->bind_param('i', $accountId);
$clinicStmt->execute();
$clinicRes = $clinicStmt->get_result();
$clinic = $clinicRes ? $clinicRes->fetch_assoc() : null;
$clinicStmt->close();
if (!$clinic) {
    api_respond(['error' => true, 'message' => 'Clinic not found for this account']);
}

$clinicId = intval($clinic['id']);
if ($activeClinicId !== $clinicId) {
    api_respond(['error' => true, 'message' => 'Clinic account mismatch']);
}
$isPremium = clinic_is_premium($conn, $clinicId);

$subStmt = $conn->prepare(
    "SELECT id, plan, amount, start_date, end_date, status
     FROM subscription
     WHERE clinic_id = ?
     ORDER BY id DESC
     LIMIT 1"
);
$subscription = null;
if ($subStmt) {
    $subStmt->bind_param('i', $clinicId);
    $subStmt->execute();
    $subRes = $subStmt->get_result();
    $subscription = $subRes ? $subRes->fetch_assoc() : null;
    $subStmt->close();
}

$counts = [
    'patients' => 0,
    'therapists' => 0,
];
$countStmt = $conn->prepare('SELECT COUNT(*) AS cnt FROM patient WHERE clinic_id = ?');
if ($countStmt) {
    $countStmt->bind_param('i', $clinicId);
    $countStmt->execute();
    $res = $countStmt->get_result();
    if ($row = $res->fetch_assoc()) {
        $counts['patients'] = intval($row['cnt']);
    }
    $countStmt->close();
}
$countStmt = $conn->prepare('SELECT COUNT(*) AS cnt FROM physiotherapist WHERE clinic_id = ?');
if ($countStmt) {
    $countStmt->bind_param('i', $clinicId);
    $countStmt->execute();
    $res = $countStmt->get_result();
    if ($row = $res->fetch_assoc()) {
        $counts['therapists'] = intval($row['cnt']);
    }
    $countStmt->close();
}

$therapists = [];
$tStmt = $conn->prepare(
    "SELECT p.id, p.account_id, p.name, p.specialization, p.phone, a.email, a.is_active
     FROM physiotherapist p
     JOIN account a ON a.id = p.account_id
     WHERE p.clinic_id = ?
     ORDER BY p.name ASC"
);
if ($tStmt) {
    $tStmt->bind_param('i', $clinicId);
    $tStmt->execute();
    $res = $tStmt->get_result();
    while ($row = $res->fetch_assoc()) {
        $therapists[] = [
            'id' => intval($row['id']),
            'account_id' => intval($row['account_id']),
            'name' => (string)$row['name'],
            'specialization' => $row['specialization'],
            'phone' => $row['phone'],
            'email' => (string)$row['email'],
            'is_active' => intval($row['is_active']),
        ];
    }
    $tStmt->close();
}

$patients = [];
$pStmt = $conn->prepare(
    "SELECT p.id, p.account_id, p.name, p.phone, p.birth_date, p.therapist_id, a.email,
            ph.name AS therapist_name
     FROM patient p
     JOIN account a ON a.id = p.account_id
     LEFT JOIN physiotherapist ph ON ph.id = p.therapist_id
     WHERE p.clinic_id = ?
     ORDER BY p.name ASC"
);
if ($pStmt) {
    $pStmt->bind_param('i', $clinicId);
    $pStmt->execute();
    $res = $pStmt->get_result();
    while ($row = $res->fetch_assoc()) {
        $patients[] = [
            'id' => intval($row['id']),
            'account_id' => intval($row['account_id']),
            'name' => (string)$row['name'],
            'phone' => $row['phone'],
            'birth_date' => $row['birth_date'],
            'therapist_id' => $row['therapist_id'] !== null ? intval($row['therapist_id']) : null,
            'therapist_name' => $row['therapist_name'],
            'email' => (string)$row['email'],
        ];
    }
    $pStmt->close();
}

api_respond([
    'error' => false,
    'clinic' => [
        'id' => $clinicId,
        'account_id' => intval($clinic['account_id']),
        'name' => (string)$clinic['name'],
        'address' => $clinic['address'],
        'phone' => $clinic['phone'],
        'justif' => $clinic['justif'] ?? null,
        'photo_url' => $clinic['photo_url'] ?? '',
    ],
    'counts' => $counts,
    'is_premium' => $isPremium ? 1 : 0,
    'subscription' => $subscription,
    'therapists' => $therapists,
    'patients' => $patients,
]);

