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

$accountCols = table_columns($conn, 'account');
$hasPhotoLower = in_array('photo', $accountCols, true);
$hasPhotoUpper = in_array('Photo', $accountCols, true);
if ($hasPhotoLower && $hasPhotoUpper) {
    $photoSelect = "COALESCE(NULLIF(a.`photo`, ''), NULLIF(a.`Photo`, ''), '')";
} elseif ($hasPhotoLower) {
    $photoSelect = "COALESCE(a.`photo`, '')";
} elseif ($hasPhotoUpper) {
    $photoSelect = "COALESCE(a.`Photo`, '')";
} else {
    $photoSelect = "''";
}

$physioSql = "SELECT ph.id, ph.account_id, ph.clinic_id, ph.name, ph.specialization, ph.phone,
                     a.email,
                     $photoSelect AS photo_url
              FROM physiotherapist ph
              INNER JOIN account a ON a.id = ph.account_id
              WHERE ph.account_id = ?
              LIMIT 1";
$physioStmt = $conn->prepare($physioSql);
if (!$physioStmt) {
    respond(['error' => true, 'message' => 'Failed to prepare physiotherapist lookup: ' . $conn->error]);
}
$physioStmt->bind_param('i', $accountId);
$physioStmt->execute();
$physioRes = $physioStmt->get_result();
$row = $physioRes->fetch_assoc();
$physioStmt->close();

if (!$row) {
    respond(['error' => true, 'message' => 'Physiotherapist not found']);
}

$clinicId = isset($row['clinic_id']) ? intval($row['clinic_id']) : 0;
$clinicName = '';
$hasActiveSubscription = false;

if ($clinicId > 0) {
    $clinicStmt = $conn->prepare('SELECT name FROM clinic WHERE id = ? LIMIT 1');
    if ($clinicStmt) {
        $clinicStmt->bind_param('i', $clinicId);
        $clinicStmt->execute();
        $clinicRes = $clinicStmt->get_result();
        if ($clinicRow = $clinicRes->fetch_assoc()) {
            $clinicName = isset($clinicRow['name']) ? (string)$clinicRow['name'] : '';
        }
        $clinicStmt->close();
    }

    $subStmt = $conn->prepare("SELECT id FROM subscription WHERE clinic_id = ? AND LOWER(TRIM(COALESCE(status,'active'))) = 'active' LIMIT 1");
    if ($subStmt) {
        $subStmt->bind_param('i', $clinicId);
        $subStmt->execute();
        $subRes = $subStmt->get_result();
        $hasActiveSubscription = ($subRes && $subRes->fetch_assoc()) ? true : false;
        $subStmt->close();
    }
}

respond([
    'error' => false,
    'profile' => [
        'physio_id' => intval($row['id']),
        'account_id' => intval($row['account_id']),
        'clinic_id' => $clinicId,
        'clinic_name' => $clinicName,
        'name' => (string)$row['name'],
        'specialization' => isset($row['specialization']) ? (string)$row['specialization'] : '',
        'phone' => isset($row['phone']) ? (string)$row['phone'] : '',
        'email' => isset($row['email']) ? (string)$row['email'] : '',
        'photo_url' => isset($row['photo_url']) ? (string)$row['photo_url'] : '',
    ],
    'access' => [
        'has_active_subscription' => $hasActiveSubscription ? 1 : 0,
        'can_view_ai_feedback' => $hasActiveSubscription ? 1 : 0,
    ],
]);


