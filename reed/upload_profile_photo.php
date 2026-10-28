<?php
require_once 'api_common.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_respond(['error' => true, 'message' => 'Method not allowed']);
}

$accountId = isset($_POST['account_id']) ? intval($_POST['account_id']) : 0;
if ($accountId <= 0) {
    api_respond(['error' => true, 'message' => 'account_id is required']);
}

if (!isset($_FILES['photo']) || !is_array($_FILES['photo']) || intval($_FILES['photo']['error']) !== UPLOAD_ERR_OK) {
    api_respond(['error' => true, 'message' => 'photo file is required']);
}

$checkAcc = $conn->prepare('SELECT id FROM account WHERE id = ? LIMIT 1');
if (!$checkAcc) {
    api_respond(['error' => true, 'message' => 'Failed to prepare account lookup: ' . $conn->error]);
}
$checkAcc->bind_param('i', $accountId);
$checkAcc->execute();
$resAcc = $checkAcc->get_result();
$exists = $resAcc && $resAcc->fetch_assoc();
$checkAcc->close();
if (!$exists) {
    api_respond(['error' => true, 'message' => 'Account not found']);
}

$original = (string)$_FILES['photo']['name'];
$tmpPath = (string)$_FILES['photo']['tmp_name'];
$ext = strtolower(pathinfo($original, PATHINFO_EXTENSION));
$allowed = ['jpg', 'jpeg', 'png', 'webp'];
if (!in_array($ext, $allowed, true)) {
    api_respond(['error' => true, 'message' => 'Photo must be JPG/PNG/WEBP']);
}

$uploadDir = __DIR__ . DIRECTORY_SEPARATOR . 'uploads' . DIRECTORY_SEPARATOR . 'profiles';
if (!is_dir($uploadDir) && !mkdir($uploadDir, 0777, true)) {
    api_respond(['error' => true, 'message' => 'Failed to create upload directory']);
}

$filename = 'profile_' . $accountId . '_' . time() . '_' . bin2hex(random_bytes(4)) . '.' . $ext;
$targetPath = $uploadDir . DIRECTORY_SEPARATOR . $filename;
if (!move_uploaded_file($tmpPath, $targetPath)) {
    api_respond(['error' => true, 'message' => 'Failed to save uploaded file']);
}

$relativePath = 'uploads/profiles/' . $filename;
$photoColumn = table_has_column($conn, 'account', 'photo') ? 'photo' : (table_has_column($conn, 'account', 'Photo') ? 'Photo' : '');
if ($photoColumn === '') {
    api_respond(['error' => true, 'message' => 'No photo column found in account table']);
}

$sql = "UPDATE account SET `" . $photoColumn . "` = ? WHERE id = ?";
$update = $conn->prepare($sql);
if (!$update) {
    api_respond(['error' => true, 'message' => 'Failed to prepare photo update: ' . $conn->error]);
}
$update->bind_param('si', $relativePath, $accountId);
if (!$update->execute()) {
    $update->close();
    api_respond(['error' => true, 'message' => 'Failed to update photo path: ' . $update->error]);
}
$update->close();

api_respond([
    'error' => false,
    'message' => 'Photo uploaded successfully',
    'photo_url' => $relativePath,
]);

