<?php
require_once 'api_common.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_respond(['error' => true, 'message' => 'Method not allowed']);
}

$seedKey = isset($_POST['seed_key']) ? trim((string)$_POST['seed_key']) : '';
if ($seedKey !== 'kinex-admin-seed-2026') {
    api_respond(['error' => true, 'message' => 'Invalid seed key']);
}

$email = isset($_POST['email']) ? trim((string)$_POST['email']) : 'admin@kinex.app';
$password = isset($_POST['password']) ? trim((string)$_POST['password']) : 'Admin@123';

$check = $conn->prepare("SELECT id FROM account WHERE role = 'admin' AND email = ? LIMIT 1");
if (!$check) {
    api_respond(['error' => true, 'message' => 'Failed to prepare admin check: ' . $conn->error]);
}
$check->bind_param('s', $email);
$check->execute();
$res = $check->get_result();
$existing = $res ? $res->fetch_assoc() : null;
$check->close();
if ($existing) {
    api_respond(['error' => false, 'message' => 'Admin account already exists', 'account_id' => intval($existing['id'])]);
}

$hash = password_hash($password, PASSWORD_BCRYPT);
$ins = $conn->prepare("INSERT INTO account (email, password_hash, role, is_active, Photo) VALUES (?, ?, 'admin', 1, '')");
if (!$ins) {
    api_respond(['error' => true, 'message' => 'Failed to prepare admin insert: ' . $conn->error]);
}
$ins->bind_param('ss', $email, $hash);
if (!$ins->execute()) {
    $ins->close();
    api_respond(['error' => true, 'message' => 'Failed to create admin account: ' . $ins->error]);
}
$accountId = intval($conn->insert_id);
$ins->close();

api_respond([
    'error' => false,
    'message' => 'Admin account created',
    'account_id' => $accountId,
    'email' => $email,
]);

