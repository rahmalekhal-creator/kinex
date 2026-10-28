<?php
require_once 'api_common.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_respond(['error' => true, 'message' => 'Method not allowed']);
}

$adminAccountId = isset($_POST['admin_account_id']) ? intval($_POST['admin_account_id']) : 0;
$targetAccountId = isset($_POST['target_account_id']) ? intval($_POST['target_account_id']) : 0;
$action = isset($_POST['action']) ? strtolower(trim((string)$_POST['action'])) : 'update';

if ($adminAccountId <= 0 || $targetAccountId <= 0) {
    api_respond(['error' => true, 'message' => 'admin_account_id and target_account_id are required']);
}
require_admin_account($conn, $adminAccountId);

if ($action === 'delete') {
    if ($targetAccountId === $adminAccountId) {
        api_respond(['error' => true, 'message' => 'You cannot delete your own admin account']);
    }

    $roleCheck = $conn->prepare('SELECT role FROM account WHERE id = ? LIMIT 1');
    if ($roleCheck) {
        $roleCheck->bind_param('i', $targetAccountId);
        $roleCheck->execute();
        $roleRes = $roleCheck->get_result();
        $target = $roleRes ? $roleRes->fetch_assoc() : null;
        $roleCheck->close();
        if ($target && strtolower(trim((string)$target['role'])) === 'admin') {
            api_respond(['error' => true, 'message' => 'Admin accounts cannot be deleted']);
        }
    }

    $del = $conn->prepare('DELETE FROM account WHERE id = ?');
    if (!$del) {
        api_respond(['error' => true, 'message' => 'Failed to prepare delete: ' . $conn->error]);
    }
    $del->bind_param('i', $targetAccountId);
    if (!$del->execute()) {
        $del->close();
        api_respond(['error' => true, 'message' => 'Failed to delete account: ' . $del->error]);
    }
    $del->close();
    api_respond(['error' => false, 'message' => 'Account deleted']);
}

$email = isset($_POST['email']) ? trim((string)$_POST['email']) : '';
$role = isset($_POST['role']) ? strtolower(trim((string)$_POST['role'])) : '';
$isActive = isset($_POST['is_active']) ? intval($_POST['is_active']) : null;

$fields = [];
$params = [];
$types = '';

if ($email !== '') {
    $fields[] = 'email = ?';
    $params[] = $email;
    $types .= 's';
}
if (in_array($role, ['clinic', 'patient', 'therapist', 'admin'], true)) {
    $fields[] = 'role = ?';
    $params[] = $role;
    $types .= 's';
}
if ($isActive === 0 || $isActive === 1) {
    $fields[] = 'is_active = ?';
    $params[] = $isActive;
    $types .= 'i';
}

if (empty($fields)) {
    api_respond(['error' => true, 'message' => 'No valid update fields provided']);
}

$sql = 'UPDATE account SET ' . implode(', ', $fields) . ' WHERE id = ?';
$params[] = $targetAccountId;
$types .= 'i';

$stmt = $conn->prepare($sql);
if (!$stmt) {
    api_respond(['error' => true, 'message' => 'Failed to prepare update: ' . $conn->error]);
}
$stmt->bind_param($types, ...$params);
if (!$stmt->execute()) {
    $stmt->close();
    api_respond(['error' => true, 'message' => 'Failed to update account: ' . $stmt->error]);
}
$stmt->close();

api_respond(['error' => false, 'message' => 'Account updated']);

