<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>KInex – Payment</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
           display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;
           background:#f4f6fb; }
    .card { background:#fff;border-radius:16px;padding:40px 32px;text-align:center;
            box-shadow:0 4px 24px rgba(0,0,0,.08);max-width:360px;width:90%; }
    .icon { font-size:52px;margin-bottom:16px; }
    h2 { margin:0 0 8px;font-size:22px; }
    p  { color:#555;margin:0 0 24px;font-size:15px; }
    .ref { font-family:monospace;font-size:12px;color:#888;word-break:break-all; }
  </style>
</head>
<body>
<?php
$status    = isset($_GET['status']) ? $_GET['status'] : '';
$sessionId = isset($_GET['session_id']) ? htmlspecialchars($_GET['session_id']) : '';

if ($status === 'success') {
    echo '<div class="card">';
    echo '<div class="icon">✅</div>';
    echo '<h2>Payment received!</h2>';
    echo '<p>Go back to the KInex app and tap <strong>"Verify my payment"</strong> to activate your subscription.</p>';
    if ($sessionId) {
        echo '<p class="ref">Ref: ' . $sessionId . '</p>';
    }
    echo '</div>';
} else {
    echo '<div class="card">';
    echo '<div class="icon">❌</div>';
    echo '<h2>Payment cancelled</h2>';
    echo '<p>No charge was made. Go back to the KInex app and try again when you\'re ready.</p>';
    echo '</div>';
}
?>
</body>
</html>

