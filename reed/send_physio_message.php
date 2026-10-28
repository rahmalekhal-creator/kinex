<?php
ob_start();
ini_set('display_errors', '0');
error_reporting(E_ALL);
header('Content-Type: application/json; charset=UTF-8');

require_once 'db.php';
require_once 'notifications_lib.php';

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

$accountId = isset($_POST['account_id']) ? intval($_POST['account_id']) : 0;
$patientAccountId = isset($_POST['patient_account_id']) ? intval($_POST['patient_account_id']) : 0;
$content = isset($_POST['content']) ? trim((string)$_POST['content']) : '';

if ($accountId <= 0 || $patientAccountId <= 0) {
    respond(['error' => true, 'message' => 'account_id and patient_account_id are required']);
}
if ($content === '') {
    respond(['error' => true, 'message' => 'Message content is required']);
}

$physioStmt = $conn->prepare('SELECT id, account_id FROM physiotherapist WHERE account_id = ? LIMIT 1');
if (!$physioStmt) {
    respond(['error' => true, 'message' => 'Failed to prepare physiotherapist lookup: ' . $conn->error]);
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
$physioAccountId = intval($physio['account_id']);

$patientCheck = $conn->prepare('SELECT id FROM patient WHERE account_id = ? AND therapist_id = ? LIMIT 1');
if (!$patientCheck) {
    respond(['error' => true, 'message' => 'Failed to prepare patient check: ' . $conn->error]);
}
$patientCheck->bind_param('ii', $patientAccountId, $physioId);
$patientCheck->execute();
$patientRes = $patientCheck->get_result();
$isAllowed = ($patientRes && $patientRes->fetch_assoc()) ? true : false;
$patientCheck->close();
if (!$isAllowed) {
    respond(['error' => true, 'message' => 'Patient is not assigned to this physiotherapist']);
}

$isRead = 0;
$insert = $conn->prepare('INSERT INTO message (sender_id, receiver_id, content, sent_at, is_read) VALUES (?, ?, ?, NOW(), ?)');
if (!$insert) {
    respond(['error' => true, 'message' => 'Failed to prepare message insert: ' . $conn->error]);
}
$insert->bind_param('iisi', $physioAccountId, $patientAccountId, $content, $isRead);
if (!$insert->execute()) {
    $insert->close();
    respond(['error' => true, 'message' => 'Failed to send message: ' . $insert->error]);
}
$messageId = $conn->insert_id;
$insert->close();
notif_init($conn);
notify_message($conn, intval($messageId), $physioAccountId, $patientAccountId, $content);

respond([
    'error' => false,
    'message' => 'Message sent successfully',
    'message_id' => $messageId,
]);


