<?php
require_once 'api_common.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_respond(['error' => true, 'message' => 'Method not allowed']);
}

$accountId = isset($_POST['account_id']) ? intval($_POST['account_id']) : 0;
$progressReportId = isset($_POST['progressreport_id']) ? intval($_POST['progressreport_id']) : 0;
$analysis = isset($_POST['analysis']) ? trim((string)$_POST['analysis']) : null;
$score = isset($_POST['score']) ? floatval($_POST['score']) : null;

if ($accountId <= 0 || $progressReportId <= 0) {
    api_respond(['error' => true, 'message' => 'account_id and progressreport_id are required']);
}
if (!isset($_FILES['video']) || !is_array($_FILES['video']) || intval($_FILES['video']['error']) !== UPLOAD_ERR_OK) {
    api_respond(['error' => true, 'message' => 'video file is required']);
}

$patientId = resolve_patient_id_from_account($conn, $accountId);
if ($patientId <= 0) {
    api_respond(['error' => true, 'message' => 'Patient account not found']);
}

$clinicId = 0;
$clinicStmt = $conn->prepare('SELECT clinic_id FROM patient WHERE id = ? LIMIT 1');
if ($clinicStmt) {
    $clinicStmt->bind_param('i', $patientId);
    $clinicStmt->execute();
    $res = $clinicStmt->get_result();
    if ($row = $res->fetch_assoc()) {
        $clinicId = intval($row['clinic_id']);
    }
    $clinicStmt->close();
}

if ($clinicId <= 0 || !clinic_is_premium($conn, $clinicId)) {
    api_respond(['error' => true, 'message' => 'Premium subscription required for video upload']);
}

$ownershipStmt = $conn->prepare(
    "SELECT pr.id
     FROM progressreport pr
     JOIN patientexercise pe ON pe.id = pr.ppid
     WHERE pr.id = ? AND pe.patient_id = ?
     LIMIT 1"
);
if (!$ownershipStmt) {
    api_respond(['error' => true, 'message' => 'Failed to prepare ownership check: ' . $conn->error]);
}
$ownershipStmt->bind_param('ii', $progressReportId, $patientId);
$ownershipStmt->execute();
$ownershipRes = $ownershipStmt->get_result();
$ownsReport = $ownershipRes && $ownershipRes->fetch_assoc();
$ownershipStmt->close();
if (!$ownsReport) {
    api_respond(['error' => true, 'message' => 'Progress report not found for this patient']);
}

$uploadDir = __DIR__ . DIRECTORY_SEPARATOR . 'uploads' . DIRECTORY_SEPARATOR . 'aifeedback';
if (!is_dir($uploadDir)) {
    mkdir($uploadDir, 0777, true);
}

$original = (string)$_FILES['video']['name'];
$tmpPath = (string)$_FILES['video']['tmp_name'];
$ext = strtolower(pathinfo($original, PATHINFO_EXTENSION));
$allowed = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
if (!in_array($ext, $allowed, true)) {
    api_respond(['error' => true, 'message' => 'Unsupported video format']);
}

$filename = 'aifeedback_' . $patientId . '_' . time() . '_' . bin2hex(random_bytes(4)) . '.' . $ext;
$targetPath = $uploadDir . DIRECTORY_SEPARATOR . $filename;
if (!move_uploaded_file($tmpPath, $targetPath)) {
    api_respond(['error' => true, 'message' => 'Failed to upload video file']);
}

$videoUrl = 'uploads/aifeedback/' . $filename;

$insert = $conn->prepare('INSERT INTO aifeedback (analysis, score, generated_at, progressreport_id, Vid_url) VALUES (?, ?, NOW(), ?, ?)');
if (!$insert) {
    api_respond(['error' => true, 'message' => 'Failed to prepare AI feedback insert: ' . $conn->error]);
}
$insert->bind_param('sdis', $analysis, $score, $progressReportId, $videoUrl);
if (!$insert->execute()) {
    $insert->close();
    api_respond(['error' => true, 'message' => 'Failed to save AI feedback video: ' . $insert->error]);
}
$feedbackId = intval($conn->insert_id);
$insert->close();

api_respond([
    'error' => false,
    'message' => 'AI feedback video uploaded successfully',
    'id' => $feedbackId,
    'video_url' => $videoUrl,
]);

