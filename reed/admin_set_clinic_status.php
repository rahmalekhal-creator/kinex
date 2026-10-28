<?php
require_once 'api_common.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_respond(['error' => true, 'message' => 'Method not allowed']);
}

$adminAccountId = isset($_POST['admin_account_id']) ? intval($_POST['admin_account_id']) : 0;
$clinicAccountId = isset($_POST['clinic_account_id']) ? intval($_POST['clinic_account_id']) : 0;
$isActive = isset($_POST['is_active']) ? intval($_POST['is_active']) : -1;

if ($adminAccountId <= 0 || $clinicAccountId <= 0 || ($isActive !== 0 && $isActive !== 1)) {
    api_respond(['error' => true, 'message' => 'admin_account_id, clinic_account_id and is_active (0/1) are required']);
}

require_admin_account($conn, $adminAccountId);

$stmt = $conn->prepare("UPDATE account SET is_active = ? WHERE id = ? AND role = 'clinic'");
if (!$stmt) {
    api_respond(['error' => true, 'message' => 'Failed to prepare update: ' . $conn->error]);
}
$stmt->bind_param('ii', $isActive, $clinicAccountId);
if (!$stmt->execute()) {
    $stmt->close();
    api_respond(['error' => true, 'message' => 'Failed to update status: ' . $stmt->error]);
}
$stmt->close();

api_respond([
    'error' => false,
    'message' => $isActive === 1 ? 'Clinic approved' : 'Clinic moved to waiting state',
]);

