<?php
ob_start();
ini_set('display_errors', '0');
error_reporting(E_ALL);
header('Content-Type: application/json; charset=UTF-8');

require_once 'db.php';

function respond($payload)
{
    if (ob_get_length()) ob_clean();
    echo json_encode($payload);
    exit;
}

if (!isset($conn) || !($conn instanceof mysqli)) {
    respond(['error' => true, 'message' => 'Database connection not initialized']);
}

$accountId = isset($_GET['account_id']) ? intval($_GET['account_id']) : 0;
if ($accountId <= 0) {
    respond(['error' => true, 'message' => 'account_id is required']);
}

// Resolve patient_id
$patientId = 0;
$stmt = $conn->prepare("SELECT id FROM patient WHERE account_id = ? LIMIT 1");
if ($stmt) {
    $stmt->bind_param('i', $accountId);
    $stmt->execute();
    $res = $stmt->get_result();
    if ($row = $res->fetch_assoc()) $patientId = intval($row['id']);
    $stmt->close();
}
if ($patientId <= 0) {
    respond(['error' => true, 'message' => 'Patient profile not found']);
}

// Current week bounds (Monday to Sunday) — reliable ISO weekday arithmetic
// date('N') = ISO weekday: Mon=1 … Sun=7
$todayTs   = strtotime('today');
$dow       = (int)date('N', $todayTs);          // 1 (Mon) … 7 (Sun)
$weekStart = date('Y-m-d', strtotime('-' . ($dow - 1) . ' days', $todayTs));
$weekEnd   = date('Y-m-d', strtotime('+' . (7  - $dow) . ' days', $todayTs));

// Total exercises assigned this week
$totalStmt = $conn->prepare(
    "SELECT COUNT(*) AS cnt FROM patientexercise WHERE patient_id = ? AND DATE(assigned_date) BETWEEN ? AND ?"
);
$totalCount = 0;
if ($totalStmt) {
    $totalStmt->bind_param('iss', $patientId, $weekStart, $weekEnd);
    $totalStmt->execute();
    $res = $totalStmt->get_result();
    if ($row = $res->fetch_assoc()) $totalCount = intval($row['cnt']);
    $totalStmt->close();
}

// Completed exercises this week (based on assignment status)
$reportedStmt = $conn->prepare(
    "SELECT COUNT(DISTINCT pe.id) AS cnt
     FROM patientexercise pe
     WHERE pe.patient_id = ?
       AND DATE(pe.assigned_date) BETWEEN ? AND ?
       AND LOWER(TRIM(COALESCE(pe.status, 'pending'))) IN ('completed', 'done')"
);
$reportedCount = 0;
if ($reportedStmt) {
    $reportedStmt->bind_param('iss', $patientId, $weekStart, $weekEnd);
    $reportedStmt->execute();
    $res = $reportedStmt->get_result();
    if ($row = $res->fetch_assoc()) $reportedCount = intval($row['cnt']);
    $reportedStmt->close();
}

// Per-day completion % for the current week (for chart)
$dailyStmt = $conn->prepare(
    "SELECT DAYOFWEEK(pe.assigned_date) AS dow,
            SUM(CASE WHEN LOWER(TRIM(COALESCE(pe.status, 'pending'))) IN ('completed', 'done') THEN 1 ELSE 0 END) AS done_count,
            COUNT(*) AS day_total
     FROM patientexercise pe
     WHERE pe.patient_id = ? AND DATE(pe.assigned_date) BETWEEN ? AND ?
     GROUP BY DATE(pe.assigned_date), DAYOFWEEK(pe.assigned_date)"
);

// Build 7-day array (Mon=1...Sun=7)
$dailyPercents = array_fill(1, 7, 0);
if ($dailyStmt) {
    $dailyStmt->bind_param('iss', $patientId, $weekStart, $weekEnd);
    $dailyStmt->execute();
    $res = $dailyStmt->get_result();
    while ($row = $res->fetch_assoc()) {
        // MySQL DAYOFWEEK: 1=Sun, 2=Mon ... 7=Sat → convert to Mon=1..Sun=7
        $dow = intval($row['dow']);
        $monBased = ($dow === 1) ? 7 : ($dow - 1); // Sun=7, Mon=1
        $dayTotal = intval($row['day_total']);
        $doneCount = intval($row['done_count']);
        $rawPercent = $dayTotal > 0 ? intval(round($doneCount * 100 / $dayTotal)) : 0;
        $dailyPercents[$monBased] = max(0, min(100, $rawPercent));
    }
    $dailyStmt->close();
}

$weekPercent = $totalCount > 0 ? intval(round($reportedCount * 100 / $totalCount)) : 0;
$weekPercent = max(0, min(100, $weekPercent));

respond([
    'error'          => false,
    'week_start'     => $weekStart,
    'week_end'       => $weekEnd,
    'total'          => $totalCount,
    'reported'       => $reportedCount,
    'week_percent'   => $weekPercent,
    'daily_percents' => array_values($dailyPercents), // index 0=Mon ... 6=Sun
]);

