<?php
require_once 'api_common.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_respond(['error' => true, 'message' => 'Method not allowed']);
}

$adminAccountId = isset($_POST['admin_account_id']) ? intval($_POST['admin_account_id']) : 0;
$clinicId = isset($_POST['clinic_id']) ? intval($_POST['clinic_id']) : 0;
$action = isset($_POST['action']) ? strtolower(trim((string)$_POST['action'])) : 'update';

if ($adminAccountId <= 0 || $clinicId <= 0) {
    api_respond(['error' => true, 'message' => 'admin_account_id and clinic_id are required']);
}
require_admin_account($conn, $adminAccountId);

if ($action === 'delete') {
    $del = $conn->prepare('DELETE FROM clinic WHERE id = ?');
    if (!$del) {
        api_respond(['error' => true, 'message' => 'Failed to prepare delete: ' . $conn->error]);
    }
    $del->bind_param('i', $clinicId);
    if (!$del->execute()) {
        $del->close();
        api_respond(['error' => true, 'message' => 'Failed to delete clinic: ' . $del->error]);
    }
    $del->close();
    api_respond(['error' => false, 'message' => 'Clinic deleted']);
}

$name = isset($_POST['name']) ? trim((string)$_POST['name']) : '';
$address = isset($_POST['address']) ? trim((string)$_POST['address']) : '';
$phone = isset($_POST['phone']) ? trim((string)$_POST['phone']) : '';

if ($name === '') {
    api_respond(['error' => true, 'message' => 'name is required']);
}

$stmt = $conn->prepare('UPDATE clinic SET name = ?, address = ?, phone = ? WHERE id = ?');
if (!$stmt) {
    api_respond(['error' => true, 'message' => 'Failed to prepare update: ' . $conn->error]);
}
$stmt->bind_param('sssi', $name, $address, $phone, $clinicId);
if (!$stmt->execute()) {
    $stmt->close();
    api_respond(['error' => true, 'message' => 'Failed to update clinic: ' . $stmt->error]);
}
$stmt->close();

api_respond(['error' => false, 'message' => 'Clinic updated']);

