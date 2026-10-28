<?php
ob_start();
ini_set('display_errors', '0');
error_reporting(E_ALL);
header('Content-Type: application/json; charset=UTF-8');

require_once 'db.php';

function respond($payload)
{
    if (ob_get_length()) {
        ob_clean();
    }
    echo json_encode($payload);
    exit;
}

function table_columns($conn, $table)
{
    $result = $conn->query("SHOW COLUMNS FROM `$table`");
    if (!$result) {
        return [];
    }
    $cols = [];
    while ($row = $result->fetch_assoc()) {
        $cols[] = $row['Field'];
    }
    return $cols;
}

if (!isset($conn) || !($conn instanceof mysqli)) {
    respond(['error' => true, 'message' => 'Database connection not initialized']);
}

$accountId = isset($_GET['account_id']) ? intval($_GET['account_id']) : 0;
if ($accountId <= 0) {
    respond(['error' => true, 'message' => 'account_id is required']);
}

$accountColumns = table_columns($conn, 'account');
$hasPhotoLower = in_array('photo', $accountColumns, true);
$hasPhotoUpper = in_array('Photo', $accountColumns, true);

if ($hasPhotoLower && $hasPhotoUpper) {
    $photoSelect = "COALESCE(NULLIF(a.`photo`, ''), NULLIF(a.`Photo`, ''), '')";
} elseif ($hasPhotoLower) {
    $photoSelect = "COALESCE(a.`photo`, '')";
} elseif ($hasPhotoUpper) {
    $photoSelect = "COALESCE(a.`Photo`, '')";
} else {
    $photoSelect = "''";
}

$sql = "SELECT ph.id AS physio_id, ph.account_id, ph.name, ph.phone, ph.specialization, ph.clinic_id,
               a.email, $photoSelect AS photo
        FROM physiotherapist ph
        INNER JOIN account a ON a.id = ph.account_id
        WHERE ph.account_id = ?
        LIMIT 1";
$stmt = $conn->prepare($sql);
if (!$stmt) {
    respond(['error' => true, 'message' => 'Failed to prepare profile query: ' . $conn->error]);
}
$stmt->bind_param('i', $accountId);
$stmt->execute();
$res = $stmt->get_result();
$row = $res->fetch_assoc();
$stmt->close();

if (!$row) {
    respond(['error' => true, 'message' => 'Physiotherapist profile not found']);
}

$photoRaw = isset($row['photo']) ? trim((string)$row['photo']) : '';
$photoUrl = '';
if ($photoRaw !== '') {
    if (preg_match('/^https?:\/\//i', $photoRaw)) {
        $photoUrl = $photoRaw;
    } else {
        $base = rtrim((isset($_SERVER['HTTPS']) ? 'https' : 'http') . '://' . $_SERVER['HTTP_HOST'] . '/reed/', '/');
        $photoUrl = $base . '/' . ltrim($photoRaw, '/');
    }
}

respond([
    'error' => false,
    'profile' => [
        'physio_id' => intval($row['physio_id']),
        'account_id' => intval($row['account_id']),
        'clinic_id' => intval($row['clinic_id']),
        'name' => (string)$row['name'],
        'phone' => isset($row['phone']) ? (string)$row['phone'] : '',
        'specialization' => isset($row['specialization']) ? (string)$row['specialization'] : '',
        'email' => isset($row['email']) ? (string)$row['email'] : '',
        'photo_url' => $photoUrl,
    ],
]);

