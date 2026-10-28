<?php
$servername = getenv('DB_HOST') ?: "localhost";
$username = getenv('DB_USER') ?: "root";
$password = getenv('DB_PASS') ?: "";
$dbname = getenv('DB_NAME') ?: "physio_clinic";
$port = getenv('DB_PORT') ? intval(getenv('DB_PORT')) : 3306;

// Per-machine settings (not committed): copy db.local.example.php to db.local.php and change what differs.
if (file_exists(__DIR__ . '/db.local.php')) {
    include __DIR__ . '/db.local.php';
}

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname, $port);

// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}
?>
