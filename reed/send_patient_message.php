<?php
require_once 'api_common.php';
require_once 'notifications_lib.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_respond(['error' => true, 'message' => 'Method not allowed']);
}

$accountId = isset($_POST['account_id']) ? intval($_POST['account_id']) : 0;
$content = isset($_POST['content']) ? trim((string)$_POST['content']) : '';

if ($accountId <= 0) {
    api_respond(['error' => true, 'message' => 'account_id is required']);
}
if ($content === '') {
    api_respond(['error' => true, 'message' => 'Message content is required']);
}

$stmt = $conn->prepare(
    'SELECT ph.account_id AS physio_account_id
     FROM patient p
     INNER JOIN physiotherapist ph ON ph.id = p.therapist_id
     WHERE p.account_id = ?
     LIMIT 1'
);
if (!$stmt) {
    api_respond(['error' => true, 'message' => 'Failed to prepare therapist lookup: ' . $conn->error]);
}
$stmt->bind_param('i', $accountId);
$stmt->execute();
$res = $stmt->get_result();
$physio = $res ? $res->fetch_assoc() : null;
$stmt->close();

if (!$physio) {
    api_respond(['error' => true, 'message' => 'No physiotherapist is assigned to you yet']);
}
$physioAccountId = intval($physio['physio_account_id']);

$isRead = 0;
$insert = $conn->prepare('INSERT INTO message (sender_id, receiver_id, content, sent_at, is_read) VALUES (?, ?, ?, NOW(), ?)');
if (!$insert) {
    api_respond(['error' => true, 'message' => 'Failed to prepare message insert: ' . $conn->error]);
}
$insert->bind_param('iisi', $accountId, $physioAccountId, $content, $isRead);
if (!$insert->execute()) {
    $insert->close();
    api_respond(['error' => true, 'message' => 'Failed to send message: ' . $insert->error]);
}
$messageId = $conn->insert_id;
$insert->close();
notif_init($conn);
notify_message($conn, intval($messageId), $accountId, $physioAccountId, $content);

api_respond([
    'error' => false,
    'message' => 'Message sent successfully',
    'message_id' => $messageId,
]);
