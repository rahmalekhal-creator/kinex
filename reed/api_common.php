<?php
ob_start();
ini_set('display_errors', '0');
error_reporting(E_ALL);

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Content-Type: application/json; charset=UTF-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'db.php';

function api_respond($payload)
{
    if (ob_get_length()) {
        ob_clean();
    }
    echo json_encode($payload);
    exit;
}

if (!isset($conn) || !($conn instanceof mysqli)) {
    api_respond(['error' => true, 'message' => 'Database connection not initialized']);
}

function table_has_column(mysqli $conn, $table, $column)
{
    $tableSafe = $conn->real_escape_string($table);
    $columnSafe = $conn->real_escape_string($column);
    $res = $conn->query("SHOW COLUMNS FROM `{$tableSafe}` LIKE '{$columnSafe}'");
    return $res && $res->num_rows > 0;
}

function ensure_schema(mysqli $conn)
{
    if (!table_has_column($conn, 'clinic', 'justif')) {
        $conn->query("ALTER TABLE clinic ADD COLUMN justif VARCHAR(255) DEFAULT NULL");
    }

    // Enable admin role if it is not already included in the enum.
    $enumRes = $conn->query("SHOW COLUMNS FROM account LIKE 'role'");
    if ($enumRes && ($row = $enumRes->fetch_assoc())) {
        $type = strtolower((string)$row['Type']);
        if (strpos($type, "'admin'") === false) {
            $conn->query("ALTER TABLE account MODIFY role ENUM('clinic','therapist','patient','admin') NOT NULL");
        }
    }

}

function is_valid_email($email)
{
    return $email !== '' && filter_var($email, FILTER_VALIDATE_EMAIL) !== false;
}

function is_valid_phone($phone)
{
    if ($phone === '' || $phone === null) {
        return true; // optional field
    }
    return preg_match('/^[0-9+()\-\s]{6,20}$/', (string)$phone) === 1;
}

function is_valid_date_yyyy_mm_dd($date)
{
    if ($date === '' || $date === null) {
        return true; // optional field
    }
    $d = DateTime::createFromFormat('Y-m-d', (string)$date);
    return $d && $d->format('Y-m-d') === (string)$date;
}

function sync_subscription_statuses(mysqli $conn, $clinicId)
{
    // Keep function for compatibility; status management is manual/status-driven.
    return;
}

function clinic_is_premium(mysqli $conn, $clinicId)
{
    $stmt = $conn->prepare(
        "SELECT id FROM subscription
         WHERE clinic_id = ?
           AND LOWER(TRIM(COALESCE(status, 'active'))) = 'active'
         LIMIT 1"
    );
    if (!$stmt) {
        return false;
    }
    $stmt->bind_param('i', $clinicId);
    $stmt->execute();
    $res = $stmt->get_result();
    $ok = $res && $res->fetch_assoc();
    $stmt->close();
    return $ok ? true : false;
}

function resolve_clinic_id_from_account(mysqli $conn, $accountId)
{
    $stmt = $conn->prepare('SELECT id FROM clinic WHERE account_id = ? LIMIT 1');
    if (!$stmt) {
        return 0;
    }
    $stmt->bind_param('i', $accountId);
    $stmt->execute();
    $res = $stmt->get_result();
    $clinicId = 0;
    if ($row = $res->fetch_assoc()) {
        $clinicId = intval($row['id']);
    }
    $stmt->close();
    return $clinicId;
}

function resolve_patient_id_from_account(mysqli $conn, $accountId)
{
    $stmt = $conn->prepare('SELECT id FROM patient WHERE account_id = ? LIMIT 1');
    if (!$stmt) {
        return 0;
    }
    $stmt->bind_param('i', $accountId);
    $stmt->execute();
    $res = $stmt->get_result();
    $patientId = 0;
    if ($row = $res->fetch_assoc()) {
        $patientId = intval($row['id']);
    }
    $stmt->close();
    return $patientId;
}

function resolve_therapist_id_from_account(mysqli $conn, $accountId)
{
    $stmt = $conn->prepare('SELECT id FROM physiotherapist WHERE account_id = ? LIMIT 1');
    if (!$stmt) {
        return 0;
    }
    $stmt->bind_param('i', $accountId);
    $stmt->execute();
    $res = $stmt->get_result();
    $therapistId = 0;
    if ($row = $res->fetch_assoc()) {
        $therapistId = intval($row['id']);
    }
    $stmt->close();
    return $therapistId;
}

function require_admin_account(mysqli $conn, $accountId)
{
    $stmt = $conn->prepare("SELECT id FROM account WHERE id = ? AND role = 'admin' LIMIT 1");
    if (!$stmt) {
        api_respond(['error' => true, 'message' => 'Failed to prepare admin lookup: ' . $conn->error]);
    }
    $stmt->bind_param('i', $accountId);
    $stmt->execute();
    $res = $stmt->get_result();
    $ok = $res && $res->fetch_assoc();
    $stmt->close();

    if (!$ok) {
        api_respond(['error' => true, 'message' => 'Admin access required']);
    }
}

function require_active_clinic_account(mysqli $conn, $accountId)
{
    $stmt = $conn->prepare(
        "SELECT c.id AS clinic_id
         FROM account a
         JOIN clinic c ON c.account_id = a.id
         WHERE a.id = ?
           AND a.role = 'clinic'
           AND a.is_active = 1
         LIMIT 1"
    );
    if (!$stmt) {
        api_respond(['error' => true, 'message' => 'Failed to prepare clinic lookup: ' . $conn->error]);
    }
    $stmt->bind_param('i', $accountId);
    $stmt->execute();
    $res = $stmt->get_result();
    $row = $res ? $res->fetch_assoc() : null;
    $stmt->close();

    if (!$row) {
        api_respond(['error' => true, 'message' => 'Clinic account must be approved before using this feature']);
    }

    return intval($row['clinic_id']);
}

ensure_schema($conn);

