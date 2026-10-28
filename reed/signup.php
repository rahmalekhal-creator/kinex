<?php
require_once 'api_common.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_respond(['error' => true, 'message' => 'Method not allowed']);
}

$email = isset($_POST['email']) ? trim((string)$_POST['email']) : '';
$password = isset($_POST['password']) ? trim((string)$_POST['password']) : '';
$clinicName = isset($_POST['clinic_name']) ? trim((string)$_POST['clinic_name']) : '';
$address = isset($_POST['address']) ? trim((string)$_POST['address']) : '';
$phone = isset($_POST['phone']) ? trim((string)$_POST['phone']) : '';

if ($email === '' || $password === '' || $clinicName === '') {
    api_respond(['error' => true, 'message' => 'email, password and clinic_name are required']);
}
if (!is_valid_email($email)) {
    api_respond(['error' => true, 'message' => 'Invalid email format']);
}
if (strlen($password) < 6) {
    api_respond(['error' => true, 'message' => 'Password must be at least 6 characters']);
}
if (strlen($clinicName) < 3) {
    api_respond(['error' => true, 'message' => 'Clinic name must be at least 3 characters']);
}
if (!is_valid_phone($phone)) {
    api_respond(['error' => true, 'message' => 'Invalid phone format']);
}

$check = $conn->prepare('SELECT id FROM account WHERE email = ? LIMIT 1');
if (!$check) {
    api_respond(['error' => true, 'message' => 'Failed to prepare account check: ' . $conn->error]);
}
$check->bind_param('s', $email);
$check->execute();
$checkRes = $check->get_result();
$exists = $checkRes && $checkRes->fetch_assoc();
$check->close();
if ($exists) {
    api_respond(['error' => true, 'message' => 'Email already exists']);
}

$justifPath = null;
if (!isset($_FILES['justif']) || !is_array($_FILES['justif'])) {
    api_respond(['error' => true, 'message' => 'Justification file is required']);
}

$justifError = intval($_FILES['justif']['error']);
if ($justifError !== UPLOAD_ERR_OK) {
    api_respond(['error' => true, 'message' => 'Justification upload failed']);
}

if (intval($_FILES['justif']['size']) > 8 * 1024 * 1024) {
    api_respond(['error' => true, 'message' => 'Justification file must be <= 8MB']);
}

if (is_array($_FILES['justif']) && $justifError === UPLOAD_ERR_OK) {
    $uploadDir = __DIR__ . DIRECTORY_SEPARATOR . 'uploads' . DIRECTORY_SEPARATOR . 'justif';
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0777, true);
    }

    $original = (string)$_FILES['justif']['name'];
    $tmpPath = (string)$_FILES['justif']['tmp_name'];
    $ext = strtolower(pathinfo($original, PATHINFO_EXTENSION));
    $allowed = ['pdf', 'png', 'jpg', 'jpeg'];
    if (!in_array($ext, $allowed, true)) {
        api_respond(['error' => true, 'message' => 'Justification file must be PDF/JPG/PNG']);
    }

    $safeName = 'justif_' . time() . '_' . bin2hex(random_bytes(4)) . '.' . $ext;
    $target = $uploadDir . DIRECTORY_SEPARATOR . $safeName;
    if (!move_uploaded_file($tmpPath, $target)) {
        api_respond(['error' => true, 'message' => 'Failed to upload justification file']);
    }
    $justifPath = 'uploads/justif/' . $safeName;
}

$conn->begin_transaction();
try {
    $hash = password_hash($password, PASSWORD_BCRYPT);
    $insertAcc = $conn->prepare("INSERT INTO account (email, password_hash, role, is_active, Photo) VALUES (?, ?, 'clinic', 0, '')");
    if (!$insertAcc) {
        throw new Exception('Failed to prepare account insert: ' . $conn->error);
    }
    $insertAcc->bind_param('ss', $email, $hash);
    if (!$insertAcc->execute()) {
        $insertAcc->close();
        throw new Exception('Failed to create account: ' . $insertAcc->error);
    }
    $accountId = intval($conn->insert_id);
    $insertAcc->close();

    if (table_has_column($conn, 'clinic', 'justif')) {
        $insertClinic = $conn->prepare('INSERT INTO clinic (account_id, name, address, phone, justif) VALUES (?, ?, ?, ?, ?)');
        if (!$insertClinic) {
            throw new Exception('Failed to prepare clinic insert: ' . $conn->error);
        }
        $insertClinic->bind_param('issss', $accountId, $clinicName, $address, $phone, $justifPath);
    } else {
        $insertClinic = $conn->prepare('INSERT INTO clinic (account_id, name, address, phone) VALUES (?, ?, ?, ?)');
        if (!$insertClinic) {
            throw new Exception('Failed to prepare clinic insert: ' . $conn->error);
        }
        $insertClinic->bind_param('isss', $accountId, $clinicName, $address, $phone);
    }

    if (!$insertClinic->execute()) {
        $insertClinic->close();
        throw new Exception('Failed to create clinic profile: ' . $insertClinic->error);
    }
    $clinicId = intval($conn->insert_id);
    $insertClinic->close();

    $conn->commit();
    api_respond([
        'error' => false,
        'message' => 'Clinic registered. Waiting for admin approval.',
        'account_id' => $accountId,
        'clinic_id' => $clinicId,
        'is_active' => 0,
    ]);
} catch (Exception $e) {
    $conn->rollback();
    api_respond(['error' => true, 'message' => $e->getMessage()]);
}



