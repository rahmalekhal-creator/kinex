<?php
require_once 'api_common.php';
require_once 'notifications_lib.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_respond(['error' => true, 'message' => 'Method not allowed']);
}

$email = isset($_POST['email']) ? trim((string)$_POST['email']) : '';
$password = isset($_POST['password']) ? trim((string)$_POST['password']) : '';

if ($email === '' || $password === '') {
    api_respond(['error' => true, 'message' => 'Email and password are required']);
}

if (!is_valid_email($email)) {
    api_respond(['error' => true, 'message' => 'Invalid email format']);
}

$stmt = $conn->prepare('SELECT id, password_hash, role, is_active FROM account WHERE email = ? LIMIT 1');
if (!$stmt) {
    api_respond(['error' => true, 'message' => 'Failed to prepare login lookup: ' . $conn->error]);
}
$stmt->bind_param('s', $email);
$stmt->execute();
$res = $stmt->get_result();
$account = $res ? $res->fetch_assoc() : null;
$stmt->close();

if (!$account) {
    api_respond(['error' => true, 'message' => 'No account found with this email']);
}

$accountId = intval($account['id']);
$role = strtolower(trim((string)$account['role']));
$isActive = intval($account['is_active']) === 1;

if (!password_verify($password, (string)$account['password_hash'])) {
    api_respond(['error' => true, 'message' => 'Invalid password']);
}

if (!$isActive) {
    api_respond([
        'error' => true,
        'message' => 'Waiting for approval',
        'id' => $accountId,
        'account_id' => $accountId,
        'role' => $role,
        'isPremium' => 0,
        'is_active' => 0,
    ]);
}

$entityId = $accountId;
$clinicId = 0;
if ($role === 'clinic') {
    $clinicId = resolve_clinic_id_from_account($conn, $accountId);
    if ($clinicId <= 0) {
        api_respond(['error' => true, 'message' => 'Clinic profile not found']);
    }
    $entityId = $clinicId;
} elseif ($role === 'patient') {
    $entityId = resolve_patient_id_from_account($conn, $accountId);
    if ($entityId <= 0) {
        api_respond(['error' => true, 'message' => 'Patient profile not found']);
    }

    $stmt = $conn->prepare('SELECT clinic_id FROM patient WHERE id = ? LIMIT 1');
    if ($stmt) {
        $stmt->bind_param('i', $entityId);
        $stmt->execute();
        $r = $stmt->get_result();
        if ($row = $r->fetch_assoc()) {
            $clinicId = intval($row['clinic_id']);
        }
        $stmt->close();
    }
} elseif ($role === 'therapist' || $role === 'physiotherapist') {
    $role = 'therapist';
    $entityId = resolve_therapist_id_from_account($conn, $accountId);
    if ($entityId <= 0) {
        api_respond(['error' => true, 'message' => 'Physiotherapist profile not found']);
    }

    $stmt = $conn->prepare('SELECT clinic_id FROM physiotherapist WHERE id = ? LIMIT 1');
    if ($stmt) {
        $stmt->bind_param('i', $entityId);
        $stmt->execute();
        $r = $stmt->get_result();
        if ($row = $r->fetch_assoc()) {
            $clinicId = intval($row['clinic_id']);
        }
        $stmt->close();
    }
} elseif ($role === 'admin') {
    $clinicId = 0;
} else {
    api_respond(['error' => true, 'message' => 'Unsupported account role: ' . $role]);
}

$subscription = null;
if ($clinicId > 0) {
    $subStmt = $conn->prepare(
        'SELECT id, plan, amount, start_date, end_date, status
         FROM subscription
         WHERE clinic_id = ?
         ORDER BY id DESC
         LIMIT 1'
    );
    if ($subStmt) {
        $subStmt->bind_param('i', $clinicId);
        $subStmt->execute();
        $subRes = $subStmt->get_result();
        $subscription = $subRes ? $subRes->fetch_assoc() : null;
        $subStmt->close();
    }
}

$isPremium = ($clinicId > 0 && clinic_is_premium($conn, $clinicId)) ? 1 : 0;

// token for the endpoints that check who is asking (notifications)
$token = auth_issue_token($conn, $accountId);

api_respond([
    'error' => false,
    'id' => $entityId,
    'account_id' => $accountId,
    'role' => $role,
    'is_active' => 1,
    'clinic_id' => $clinicId,
    'isPremium' => $isPremium,
    'subscription_status' => $subscription ? (string)$subscription['status'] : null,
    'subscription_start' => $subscription ? $subscription['start_date'] : null,
    'subscription_end' => $subscription ? $subscription['end_date'] : null,
    'token' => $token,
    'message' => 'Login successful',
]);

