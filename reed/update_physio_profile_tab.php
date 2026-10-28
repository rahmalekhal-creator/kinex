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

$accountId = isset($_POST['account_id']) ? intval($_POST['account_id']) : 0;
$name = isset($_POST['name']) ? trim((string)$_POST['name']) : '';
$phone = isset($_POST['phone']) ? trim((string)$_POST['phone']) : '';
$specialization = isset($_POST['specialization']) ? trim((string)$_POST['specialization']) : '';
$password = isset($_POST['password']) ? trim((string)$_POST['password']) : '';

if ($accountId <= 0) {
    respond(['error' => true, 'message' => 'account_id is required']);
}
if ($name === '' || $phone === '') {
    respond(['error' => true, 'message' => 'Name and phone are required']);
}
if ($password !== '' && strlen($password) < 6) {
    respond(['error' => true, 'message' => 'Password must be at least 6 characters']);
}

$resolve = $conn->prepare('SELECT id, account_id FROM physiotherapist WHERE account_id = ? LIMIT 1');
if (!$resolve) {
    respond(['error' => true, 'message' => 'Failed to prepare physiotherapist resolve query: ' . $conn->error]);
}
$resolve->bind_param('i', $accountId);
$resolve->execute();
$resolvedRes = $resolve->get_result();
if (!($resolved = $resolvedRes->fetch_assoc())) {
    $resolve->close();
    respond(['error' => true, 'message' => 'Physiotherapist not found']);
}
$resolve->close();

$physioId = intval($resolved['id']);
$resolvedAccountId = intval($resolved['account_id']);

$physioUpdate = $conn->prepare('UPDATE physiotherapist SET name = ?, phone = ?, specialization = ? WHERE id = ?');
if (!$physioUpdate) {
    respond(['error' => true, 'message' => 'Failed to prepare physiotherapist update: ' . $conn->error]);
}
$physioUpdate->bind_param('sssi', $name, $phone, $specialization, $physioId);
if (!$physioUpdate->execute()) {
    $physioUpdate->close();
    respond(['error' => true, 'message' => 'Failed to update physiotherapist info: ' . $physioUpdate->error]);
}
$physioUpdate->close();

if ($password !== '') {
    $accountColumns = table_columns($conn, 'account');
    $passwordColumn = in_array('password_hash', $accountColumns, true)
        ? 'password_hash'
        : (in_array('password', $accountColumns, true) ? 'password' : null);

    if ($passwordColumn === null) {
        respond(['error' => true, 'message' => 'No password column found in account table']);
    }

    $hashed = password_hash($password, PASSWORD_BCRYPT);
    $accountUpdate = $conn->prepare("UPDATE account SET `$passwordColumn` = ? WHERE id = ?");
    if (!$accountUpdate) {
        respond(['error' => true, 'message' => 'Failed to prepare password update: ' . $conn->error]);
    }
    $accountUpdate->bind_param('si', $hashed, $resolvedAccountId);
    if (!$accountUpdate->execute()) {
        $accountUpdate->close();
        respond(['error' => true, 'message' => 'Failed to update password: ' . $accountUpdate->error]);
    }
    $accountUpdate->close();
}

respond(['error' => false, 'message' => 'Profile updated successfully']);


