<?php
require_once 'api_common.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_respond(['error' => true, 'message' => 'Method not allowed']);
}

$clinicAccountId = isset($_POST['clinic_account_id']) ? intval($_POST['clinic_account_id']) : 0;
$name = isset($_POST['name']) ? trim((string)$_POST['name']) : '';
$address = isset($_POST['address']) ? trim((string)$_POST['address']) : '';
$phone = isset($_POST['phone']) ? trim((string)$_POST['phone']) : '';

if ($clinicAccountId <= 0 || $name === '') {
    api_respond(['error' => true, 'message' => 'clinic_account_id and name are required']);
}
if (strlen($name) < 3) {
    api_respond(['error' => true, 'message' => 'Clinic name must be at least 3 characters']);
}
if (!is_valid_phone($phone)) {
    api_respond(['error' => true, 'message' => 'Invalid phone format']);
}

$clinicId = require_active_clinic_account($conn, $clinicAccountId);

$stmt = $conn->prepare('UPDATE clinic SET name = ?, address = ?, phone = ? WHERE id = ?');
if (!$stmt) {
    api_respond(['error' => true, 'message' => 'Failed to prepare update: ' . $conn->error]);
}
$stmt->bind_param('sssi', $name, $address, $phone, $clinicId);
if (!$stmt->execute()) {
    $stmt->close();
    api_respond(['error' => true, 'message' => 'Failed to update profile: ' . $stmt->error]);
}
$stmt->close();

api_respond(['error' => false, 'message' => 'Clinic profile updated successfully']);

