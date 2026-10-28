<?php
require_once 'api_common.php';

$adminAccountId = isset($_GET['account_id']) ? intval($_GET['account_id']) : 0;
if ($adminAccountId <= 0) {
    api_respond(['error' => true, 'message' => 'account_id is required']);
}
require_admin_account($conn, $adminAccountId);

$scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$host = isset($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : 'localhost';
$basePath = rtrim(dirname($_SERVER['SCRIPT_NAME']), '/\\');
$baseUrl = $scheme . '://' . $host . ($basePath !== '' ? $basePath . '/' : '/');

$toPublicUrl = function ($path) use ($baseUrl) {
    $v = trim((string)$path);
    if ($v === '') return '';
    if (stripos($v, 'http://') === 0 || stripos($v, 'https://') === 0) return $v;
    $normalized = ltrim(str_replace('\\', '/', $v), '/');
    return $baseUrl . $normalized;
};

$counts = [
    'accounts' => 0,
    'clinics' => 0,
    'patients' => 0,
    'therapists' => 0,
    'pending_clinics' => 0,
];

$queries = [
    'accounts' => 'SELECT COUNT(*) AS cnt FROM account',
    'clinics' => 'SELECT COUNT(*) AS cnt FROM clinic',
    'patients' => 'SELECT COUNT(*) AS cnt FROM patient',
    'therapists' => 'SELECT COUNT(*) AS cnt FROM physiotherapist',
    'pending_clinics' => "SELECT COUNT(*) AS cnt FROM account WHERE role = 'clinic' AND is_active = 0",
];

foreach ($queries as $k => $sql) {
    $res = $conn->query($sql);
    if ($res && ($row = $res->fetch_assoc())) {
        $counts[$k] = intval($row['cnt']);
    }
}

$pending = [];
$pendingStmt = $conn->prepare(
    "SELECT a.id AS account_id, a.email, a.created_at, a.is_active,
            c.id AS clinic_id, c.name, c.address, c.phone, " .
    (table_has_column($conn, 'clinic', 'justif') ? 'c.justif' : 'NULL AS justif') .
    " FROM account a
      JOIN clinic c ON c.account_id = a.id
      WHERE a.role = 'clinic' AND a.is_active = 0
      ORDER BY a.created_at DESC"
);
if ($pendingStmt) {
    $pendingStmt->execute();
    $res = $pendingStmt->get_result();
    while ($row = $res->fetch_assoc()) {
        $row['justif_url'] = $toPublicUrl(isset($row['justif']) ? $row['justif'] : '');
        $pending[] = $row;
    }
    $pendingStmt->close();
}

$accounts = [];
$accStmt = $conn->prepare(
    "SELECT a.id, a.email, a.role, a.is_active, a.created_at,
            CASE
                WHEN a.role = 'clinic' THEN COALESCE(c.name, '')
                WHEN a.role = 'patient' THEN COALESCE(p.name, '')
                WHEN a.role = 'therapist' THEN COALESCE(ph.name, '')
                ELSE ''
            END AS display_name
     FROM account a
     LEFT JOIN clinic c ON c.account_id = a.id
     LEFT JOIN patient p ON p.account_id = a.id
     LEFT JOIN physiotherapist ph ON ph.account_id = a.id
     WHERE a.role <> 'admin'
     ORDER BY a.id DESC
     LIMIT 300"
);
if ($accStmt) {
    $accStmt->execute();
    $res = $accStmt->get_result();
    while ($row = $res->fetch_assoc()) {
        $accounts[] = [
            'id' => intval($row['id']),
            'email' => (string)$row['email'],
            'role' => (string)$row['role'],
            'is_active' => intval($row['is_active']),
            'created_at' => (string)$row['created_at'],
            'display_name' => (string)$row['display_name'],
        ];
    }
    $accStmt->close();
}

$clinics = [];
$photoSelect = table_has_column($conn, 'account', 'photo')
    ? 'COALESCE(a.photo, "") AS photo_url'
    : (table_has_column($conn, 'account', 'Photo') ? 'COALESCE(a.Photo, "") AS photo_url' : '"" AS photo_url');
$clinicStmt = $conn->prepare(
    "SELECT c.id, c.account_id, c.name, c.address, c.phone, a.email, $photoSelect, " .
    (table_has_column($conn, 'clinic', 'justif') ? 'c.justif' : 'NULL AS justif') .
    " FROM clinic c JOIN account a ON a.id = c.account_id ORDER BY c.id DESC LIMIT 300"
);
if ($clinicStmt) {
    $clinicStmt->execute();
    $res = $clinicStmt->get_result();
    while ($row = $res->fetch_assoc()) {
        $row['justif_url'] = $toPublicUrl(isset($row['justif']) ? $row['justif'] : '');
        $clinics[] = $row;
    }
    $clinicStmt->close();
}

api_respond([
    'error' => false,
    'counts' => $counts,
    'pending_clinics' => $pending,
    'accounts' => $accounts,
    'clinics' => $clinics,
]);

