<?php
require_once 'api_common.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_respond(['error' => true, 'message' => 'Method not allowed']);
}

$clinicAccountId = isset($_POST['clinic_account_id']) ? intval($_POST['clinic_account_id']) : 0;
$role = isset($_POST['role']) ? strtolower(trim((string)$_POST['role'])) : '';
$email = isset($_POST['email']) ? trim((string)$_POST['email']) : '';
$password = isset($_POST['password']) ? trim((string)$_POST['password']) : '';
$name = isset($_POST['name']) ? trim((string)$_POST['name']) : '';
$phone = isset($_POST['phone']) ? trim((string)$_POST['phone']) : '';

if ($clinicAccountId <= 0 || $email === '' || $password === '' || $name === '' || $role === '') {
    api_respond(['error' => true, 'message' => 'clinic_account_id, role, email, password, name are required']);
}
if (!in_array($role, ['patient', 'therapist'], true)) {
    api_respond(['error' => true, 'message' => 'role must be patient or therapist']);
}
if (!is_valid_email($email)) {
    api_respond(['error' => true, 'message' => 'Invalid email format']);
}
if (strlen($password) < 6) {
    api_respond(['error' => true, 'message' => 'Password must be at least 6 characters']);
}
if (strlen($name) < 2) {
    api_respond(['error' => true, 'message' => 'Name must be at least 2 characters']);
}
if (!is_valid_phone($phone)) {
    api_respond(['error' => true, 'message' => 'Invalid phone format']);
}

$clinicId = require_active_clinic_account($conn, $clinicAccountId);

$check = $conn->prepare('SELECT id FROM account WHERE email = ? LIMIT 1');
if (!$check) {
    api_respond(['error' => true, 'message' => 'Failed to prepare account check: ' . $conn->error]);
}
$check->bind_param('s', $email);
$check->execute();
$res = $check->get_result();
$exists = $res && $res->fetch_assoc();
$check->close();
if ($exists) {
    api_respond(['error' => true, 'message' => 'Email already exists']);
}

$conn->begin_transaction();
try {
    $hash = password_hash($password, PASSWORD_BCRYPT);
    $insertAcc = $conn->prepare('INSERT INTO account (email, password_hash, role, is_active, Photo) VALUES (?, ?, ?, 1, "")');
    if (!$insertAcc) {
        throw new Exception('Failed to prepare account insert: ' . $conn->error);
    }
    $insertAcc->bind_param('sss', $email, $hash, $role);
    if (!$insertAcc->execute()) {
        $insertAcc->close();
        throw new Exception('Failed to create account: ' . $insertAcc->error);
    }
    $newAccountId = intval($conn->insert_id);
    $insertAcc->close();

    if ($role === 'therapist') {
        $specialization = isset($_POST['specialization']) ? trim((string)$_POST['specialization']) : null;
        $insertTher = $conn->prepare('INSERT INTO physiotherapist (account_id, clinic_id, name, specialization, phone) VALUES (?, ?, ?, ?, ?)');
        if (!$insertTher) {
            throw new Exception('Failed to prepare therapist insert: ' . $conn->error);
        }
        $insertTher->bind_param('iisss', $newAccountId, $clinicId, $name, $specialization, $phone);
        if (!$insertTher->execute()) {
            $insertTher->close();
            throw new Exception('Failed to create physiotherapist: ' . $insertTher->error);
        }
        $newRoleId = intval($conn->insert_id);
        $insertTher->close();
    } else {
        $birthDate = isset($_POST['birth_date']) ? trim((string)$_POST['birth_date']) : null;
        if (!is_valid_date_yyyy_mm_dd($birthDate)) {
            throw new Exception('Birth date must use YYYY-MM-DD format');
        }
        $therapistId = isset($_POST['therapist_id']) ? intval($_POST['therapist_id']) : 0;
        $assignedTherapistId = null;

        if ($therapistId > 0) {
            $therapistCheck = $conn->prepare('SELECT id FROM physiotherapist WHERE id = ? AND clinic_id = ? LIMIT 1');
            if (!$therapistCheck) {
                throw new Exception('Failed to prepare therapist check: ' . $conn->error);
            }
            $therapistCheck->bind_param('ii', $therapistId, $clinicId);
            $therapistCheck->execute();
            $therRes = $therapistCheck->get_result();
            $validTherapist = $therRes && $therRes->fetch_assoc();
            $therapistCheck->close();
            if (!$validTherapist) {
                throw new Exception('Selected physiotherapist does not belong to this clinic');
            }
            $assignedTherapistId = $therapistId;
        }

        $insertPatient = $conn->prepare('INSERT INTO patient (account_id, clinic_id, therapist_id, name, phone, birth_date) VALUES (?, ?, ?, ?, ?, ?)');
        if (!$insertPatient) {
            throw new Exception('Failed to prepare patient insert: ' . $conn->error);
        }
        $insertPatient->bind_param('iiisss', $newAccountId, $clinicId, $assignedTherapistId, $name, $phone, $birthDate);
        if (!$insertPatient->execute()) {
            $insertPatient->close();
            throw new Exception('Failed to create patient: ' . $insertPatient->error);
        }
        $newRoleId = intval($conn->insert_id);
        $insertPatient->close();
    }

    $conn->commit();
    api_respond([
        'error' => false,
        'message' => ucfirst($role) . ' account created successfully',
        'account_id' => $newAccountId,
        'id' => $newRoleId,
        'role' => $role,
    ]);
} catch (Exception $e) {
    $conn->rollback();
    api_respond(['error' => true, 'message' => $e->getMessage()]);
}

