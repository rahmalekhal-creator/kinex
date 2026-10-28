<?php
require_once 'api_common.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_respond(['error' => true, 'message' => 'Method not allowed']);
}

$clinicAccountId = isset($_POST['clinic_account_id']) ? intval($_POST['clinic_account_id']) : 0;
$memberAccountId = isset($_POST['member_account_id']) ? intval($_POST['member_account_id']) : 0;
$memberRole = isset($_POST['member_role']) ? strtolower(trim((string)$_POST['member_role'])) : '';

if ($clinicAccountId <= 0 || $memberAccountId <= 0 || $memberRole === '') {
    api_respond(['error' => true, 'message' => 'clinic_account_id, member_account_id and member_role are required']);
}

if (!in_array($memberRole, ['patient', 'therapist'], true)) {
    api_respond(['error' => true, 'message' => 'member_role must be patient or therapist']);
}

$clinicId = require_active_clinic_account($conn, $clinicAccountId);

if ($memberRole === 'patient') {
    $lookup = $conn->prepare(
        "SELECT p.id
         FROM patient p
         JOIN account a ON a.id = p.account_id
         WHERE p.account_id = ? AND p.clinic_id = ? AND a.role = 'patient'
         LIMIT 1"
    );
} else {
    $lookup = $conn->prepare(
        "SELECT ph.id
         FROM physiotherapist ph
         JOIN account a ON a.id = ph.account_id
         WHERE ph.account_id = ? AND ph.clinic_id = ? AND a.role = 'therapist'
         LIMIT 1"
    );
}

if (!$lookup) {
    api_respond(['error' => true, 'message' => 'Failed to prepare ownership lookup: ' . $conn->error]);
}

$lookup->bind_param('ii', $memberAccountId, $clinicId);
$lookup->execute();
$found = $lookup->get_result();
$owned = $found && $found->fetch_assoc();
$lookup->close();

if (!$owned) {
    api_respond(['error' => true, 'message' => 'Member not found in your clinic']);
}

$delete = $conn->prepare('DELETE FROM account WHERE id = ? LIMIT 1');
if (!$delete) {
    api_respond(['error' => true, 'message' => 'Failed to prepare account deletion: ' . $conn->error]);
}
$delete->bind_param('i', $memberAccountId);
if (!$delete->execute()) {
    $delete->close();
    api_respond(['error' => true, 'message' => 'Failed to delete member account: ' . $delete->error]);
}
$affected = intval($delete->affected_rows);
$delete->close();

if ($affected <= 0) {
    api_respond(['error' => true, 'message' => 'No account deleted']);
}

api_respond([
    'error' => false,
    'message' => ucfirst($memberRole) . ' deleted successfully',
    'member_account_id' => $memberAccountId,
]);

