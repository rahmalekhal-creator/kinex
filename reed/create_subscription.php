<?php
require_once 'api_common.php';
require_once 'stripe_config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_respond(['error' => true, 'message' => 'Method not allowed']);
}

$clinicAccountId = isset($_POST['clinic_account_id']) ? intval($_POST['clinic_account_id']) : 0;
$plan = isset($_POST['plan']) ? strtolower(trim((string)$_POST['plan'])) : 'monthly';

if ($clinicAccountId <= 0) {
    api_respond(['error' => true, 'message' => 'clinic_account_id is required']);
}

if (!in_array($plan, ['monthly', 'yearly'], true)) {
    api_respond(['error' => true, 'message' => 'plan must be monthly or yearly']);
}

$clinicId = require_active_clinic_account($conn, $clinicAccountId);

if (strpos(STRIPE_SECRET_KEY, 'REPLACE') !== false) {
    api_respond(['error' => true, 'message' => 'Stripe is not configured. Edit stripe_config.php and set your test key (sk_test_...).']);
}

// Pricing policy (EUR):
// monthly = 5 + 0.1 * patient_count
// yearly  = 50 + 0.1 * patient_count
$baseAmount = ($plan === 'yearly') ? 50.0 : 5.0;
$perPatientAmount = 0.1;
$durationDays = ($plan === 'yearly') ? 365 : 30;

$patientCount = 0;
$patientStmt = $conn->prepare('SELECT COUNT(*) AS cnt FROM patient WHERE clinic_id = ?');
if ($patientStmt) {
    $patientStmt->bind_param('i', $clinicId);
    $patientStmt->execute();
    $res = $patientStmt->get_result();
    if ($row = $res->fetch_assoc()) {
        $patientCount = intval($row['cnt']);
    }
    $patientStmt->close();
}

$amount = $baseAmount + ($perPatientAmount * $patientCount);
$amountCents = intval(round($amount * 100)); // Stripe uses cents
$startDate = date('Y-m-d');
$endDate = date('Y-m-d', strtotime('+' . $durationDays . ' days'));

$postData = http_build_query([
    'mode'                                                 => 'payment',
    'line_items[0][price_data][currency]'                  => STRIPE_CURRENCY,
    'line_items[0][price_data][product_data][name]'        => 'KInex ' . ucfirst($plan) . ' plan',
    'line_items[0][price_data][product_data][description]' => 'Base ' . number_format($baseAmount, 2) . ' + ' . number_format($perPatientAmount, 2) . ' x ' . $patientCount . ' patients',
    'line_items[0][price_data][unit_amount]'               => $amountCents,
    'line_items[0][quantity]'                              => 1,
    'success_url'                                          => STRIPE_SUCCESS_URL,
    'cancel_url'                                           => STRIPE_CANCEL_URL,
    'metadata[clinic_id]'                                  => $clinicId,
    'metadata[plan]'                                       => $plan,
    'metadata[duration_days]'                              => $durationDays,
    'metadata[patient_count]'                              => $patientCount,
]);

$ch = curl_init('https://api.stripe.com/v1/checkout/sessions');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_USERPWD, STRIPE_SECRET_KEY . ':');
curl_setopt($ch, CURLOPT_POSTFIELDS, $postData);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/x-www-form-urlencoded']);
if (STRIPE_DISABLE_SSL_VERIFY) {
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
} elseif (STRIPE_CAINFO_PATH !== '' && file_exists(STRIPE_CAINFO_PATH)) {
    curl_setopt($ch, CURLOPT_CAINFO, STRIPE_CAINFO_PATH);
}

$result    = curl_exec($ch);
$curlError = curl_error($ch);
$httpCode  = intval(curl_getinfo($ch, CURLINFO_HTTP_CODE));
curl_close($ch);

if ($result === false) {
    api_respond(['error' => true, 'message' => 'Stripe request failed: ' . $curlError]);
}

$decoded = json_decode((string)$result, true);
if ($httpCode < 200 || $httpCode >= 300) {
    $msg = isset($decoded['error']['message']) ? (string)$decoded['error']['message'] : 'Stripe checkout creation failed';
    api_respond(['error' => true, 'message' => $msg, 'stripe_http' => $httpCode]);
}

$sessionId   = isset($decoded['id'])  ? (string)$decoded['id']  : '';
$checkoutUrl = isset($decoded['url']) ? (string)$decoded['url'] : '';

if (!$sessionId || !$checkoutUrl) {
    api_respond(['error' => true, 'message' => 'Stripe returned no checkout session or URL']);
}

$clearPending = $conn->prepare("DELETE FROM subscription WHERE clinic_id = ? AND LOWER(TRIM(COALESCE(status,''))) = 'pending'");
if ($clearPending) {
    $clearPending->bind_param('i', $clinicId);
    $clearPending->execute();
    $clearPending->close();
}

$store = $conn->prepare(
    'INSERT INTO subscription (clinic_id, plan, amount, start_date, end_date, status)
     VALUES (?, ?, ?, ?, ?, ?)'
);
if (!$store) {
    api_respond(['error' => true, 'message' => 'Failed to prepare subscription insert: ' . $conn->error]);
}
$pending = 'pending';
$store->bind_param('isdsss', $clinicId, $plan, $amount, $startDate, $endDate, $pending);
if (!$store->execute()) {
    $store->close();
    api_respond(['error' => true, 'message' => 'Failed to store pending subscription: ' . $store->error]);
}
$subscriptionId = intval($conn->insert_id);
$store->close();

api_respond([
    'error'        => false,
    'message'      => 'Stripe checkout ready. Complete payment then tap Verify.',
    'status'       => 'pending',
    'plan'         => $plan,
    'patient_count'=> $patientCount,
    'amount'       => round($amount, 2),
    'start_date'   => $startDate,
    'end_date'     => $endDate,
    'subscription_id' => $subscriptionId,
    'reference'    => $sessionId,
    'checkout_url' => $checkoutUrl,
]);

