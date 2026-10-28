<?php
require_once 'api_common.php';
require_once 'notifications_lib.php';

$accountId = isset($_GET['account_id']) ? intval($_GET['account_id']) : 0;
if ($accountId <= 0) {
    api_respond(['error' => true, 'message' => 'account_id is required']);
}

// The patient chats with their assigned physiotherapist.
$stmt = $conn->prepare(
    'SELECT ph.account_id AS physio_account_id, ph.name AS physio_name
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
    if (resolve_patient_id_from_account($conn, $accountId) <= 0) {
        api_respond(['error' => true, 'message' => 'Patient profile not found']);
    }
    api_respond(['error' => true, 'message' => 'No physiotherapist is assigned to you yet']);
}
$physioAccountId = intval($physio['physio_account_id']);
// opening the conversation: its message notifications are read
notif_init($conn);
notif_mark_conversation_read($conn, $accountId, $physioAccountId);
$physioName = (string)$physio['physio_name'];

$sql = 'SELECT id, sender_id, receiver_id, content, sent_at, is_read
        FROM message
        WHERE (sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)
        ORDER BY sent_at ASC, id ASC';
$stmt = $conn->prepare($sql);
if (!$stmt) {
    api_respond(['error' => true, 'message' => 'Failed to prepare messages query: ' . $conn->error]);
}
$stmt->bind_param('iiii', $accountId, $physioAccountId, $physioAccountId, $accountId);
$stmt->execute();
$result = $stmt->get_result();

$messages = [];
while ($msg = $result->fetch_assoc()) {
    $isMine = intval($msg['sender_id']) === $accountId;
    $messages[] = [
        'id' => intval($msg['id']),
        'sender_id' => intval($msg['sender_id']),
        'receiver_id' => intval($msg['receiver_id']),
        'content' => (string)$msg['content'],
        'sent_at' => isset($msg['sent_at']) ? (string)$msg['sent_at'] : '',
        'is_read' => (isset($msg['is_read']) && intval($msg['is_read']) === 1) ? 1 : 0,
        'is_mine' => $isMine ? 1 : 0,
        'sender_name' => $isMine ? 'Me' : ($physioName !== '' ? $physioName : 'Physiotherapist'),
    ];
}
$stmt->close();

api_respond(['error' => false, 'messages' => $messages]);
