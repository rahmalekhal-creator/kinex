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

$accountId = isset($_GET['account_id']) ? intval($_GET['account_id']) : 0;
$patientAccountId = isset($_GET['patient_account_id']) ? intval($_GET['patient_account_id']) : 0;
if ($accountId <= 0 || $patientAccountId <= 0) {
    respond(['error' => true, 'message' => 'account_id and patient_account_id are required']);
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

$patientName = '';
// the patient is assigned to this physiotherapist: opening the conversation reads its message notifications
notif_init($conn);
notif_mark_conversation_read($conn, $physioAccountId, $patientAccountId);

$patientNameStmt = $conn->prepare('SELECT name FROM patient WHERE account_id = ? AND therapist_id = ? LIMIT 1');
if ($patientNameStmt) {
    $patientNameStmt->bind_param('ii', $patientAccountId, $physioId);
    $patientNameStmt->execute();
    $patientNameRes = $patientNameStmt->get_result();
    if ($nameRow = $patientNameRes->fetch_assoc()) {
        $patientName = isset($nameRow['name']) ? (string)$nameRow['name'] : '';
    }
    $patientNameStmt->close();
}

$sql = 'SELECT id, sender_id, receiver_id, content, sent_at, is_read
        FROM message
        WHERE (sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)
        ORDER BY sent_at ASC, id ASC';
$stmt = $conn->prepare($sql);
if (!$stmt) {
    respond(['error' => true, 'message' => 'Failed to prepare messages query: ' . $conn->error]);
}
$stmt->bind_param('iiii', $physioAccountId, $patientAccountId, $patientAccountId, $physioAccountId);
$stmt->execute();
$result = $stmt->get_result();

$messages = [];
while ($msg = $result->fetch_assoc()) {
    $isMine = intval($msg['sender_id']) === $physioAccountId;
    $messages[] = [
        'id' => intval($msg['id']),
        'sender_id' => intval($msg['sender_id']),
        'receiver_id' => intval($msg['receiver_id']),
        'content' => (string)$msg['content'],
        'sent_at' => isset($msg['sent_at']) ? (string)$msg['sent_at'] : '',
        'is_read' => (isset($msg['is_read']) && intval($msg['is_read']) === 1) ? 1 : 0,
        'is_mine' => $isMine ? 1 : 0,
        'sender_name' => $isMine ? 'Me' : ($patientName !== '' ? $patientName : 'Patient'),
    ];
}
$stmt->close();

respond(['error' => false, 'messages' => $messages]);

