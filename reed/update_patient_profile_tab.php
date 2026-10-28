<?php
require_once 'api_common.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_respond(['error' => true, 'message' => 'Method not allowed']);
}

$accountId = isset($_POST['account_id']) ? intval($_POST['account_id']) : 0;
$name = isset($_POST['name']) ? trim((string)$_POST['name']) : '';
$phone = isset($_POST['phone']) ? trim((string)$_POST['phone']) : '';
$password = isset($_POST['password']) ? trim((string)$_POST['password']) : '';

if ($accountId <= 0) {
    api_respond(['error' => true, 'message' => 'account_id is required']);
}
if ($name === '' || $phone === '') {
    api_respond(['error' => true, 'message' => 'Name and phone are required']);
}
if (!is_valid_phone($phone)) {
    api_respond(['error' => true, 'message' => 'Invalid phone number']);
}
if ($password !== '' && strlen($password) < 6) {
    api_respond(['error' => true, 'message' => 'Password must be at least 6 characters']);
}

$patientId = resolve_patient_id_from_account($conn, $accountId);
if ($patientId <= 0) {
    api_respond(['error' => true, 'message' => 'Patient profile not found']);
}

$update = $conn->prepare('UPDATE patient SET name = ?, phone = ? WHERE id = ?');
if (!$update) {
    api_respond(['error' => true, 'message' => 'Failed to prepare patient update: ' . $conn->error]);
}
$update->bind_param('ssi', $name, $phone, $patientId);
if (!$update->execute()) {
    $update->close();
    api_respond(['error' => true, 'message' => 'Failed to update patient info: ' . $update->error]);
}
$update->close();

if ($password !== '') {
    $hashed = password_hash($password, PASSWORD_BCRYPT);
    $pwUpdate = $conn->prepare('UPDATE account SET password_hash = ? WHERE id = ?');
    if (!$pwUpdate) {
        api_respond(['error' => true, 'message' => 'Failed to prepare password update: ' . $conn->error]);
    }
    $pwUpdate->bind_param('si', $hashed, $accountId);
    if (!$pwUpdate->execute()) {
        $pwUpdate->close();
        api_respond(['error' => true, 'message' => 'Failed to update password: ' . $pwUpdate->error]);
    }
    $pwUpdate->close();
}

api_respond(['error' => false, 'message' => 'Profile updated successfully']);
