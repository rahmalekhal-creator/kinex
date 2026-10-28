<?php
require_once 'api_common.php';
require_once 'stripe_config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    api_respond(['error' => true, 'message' => 'Method not allowed']);
}

$clinicAccountId = isset($_POST['clinic_account_id']) ? intval($_POST['clinic_account_id']) : 0;
$reference = isset($_POST['reference']) ? trim((string)$_POST['reference']) : ''; // Stripe session ID (cs_test_...)

if ($clinicAccountId <= 0 || $reference === '') {
    api_respond(['error' => true, 'message' => 'clinic_account_id and reference are required']);
}

$clinicId = require_active_clinic_account($conn, $clinicAccountId);

// Look up latest pending subscription row for this clinic.
$subStmt = $conn->prepare(
    "SELECT id, clinic_id, plan, amount, start_date, end_date, status
     FROM subscription
     WHERE clinic_id = ?
       AND LOWER(TRIM(COALESCE(status, 'pending'))) = 'pending'
     ORDER BY id DESC
     LIMIT 1"
);
if (!$subStmt) {
    api_respond(['error' => true, 'message' => 'Failed to prepare subscription lookup: ' . $conn->error]);
}
$subStmt->bind_param('i', $clinicId);
$subStmt->execute();
$subRes = $subStmt->get_result();
$subscription = $subRes ? $subRes->fetch_assoc() : null;
$subStmt->close();

if (!$subscription) {
    api_respond(['error' => true, 'message' => 'Payment reference not found for this clinic']);
}

if (strpos(STRIPE_SECRET_KEY, 'REPLACE') !== false) {
    api_respond(['error' => true, 'message' => 'Stripe is not configured. Edit stripe_config.php.']);
}

// Verify the Stripe Checkout Session
$ch = curl_init('https://api.stripe.com/v1/checkout/sessions/' . rawurlencode($reference));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_USERPWD, STRIPE_SECRET_KEY . ':');
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
    api_respond(['error' => true, 'message' => 'Stripe verification failed: ' . $curlError]);
}

$decoded = json_decode((string)$result, true);
if ($httpCode < 200 || $httpCode >= 300) {
    $msg = isset($decoded['error']['message']) ? (string)$decoded['error']['message'] : 'Stripe session lookup failed';
    api_respond(['error' => true, 'message' => $msg, 'stripe_http' => $httpCode]);
}

// Stripe payment_status: 'paid' | 'unpaid' | 'no_payment_required'
$paymentStatus = isset($decoded['payment_status']) ? strtolower(trim((string)$decoded['payment_status'])) : '';
$isPaid = ($paymentStatus === 'paid');

if (!$isPaid) {
    $updatePending = $conn->prepare('UPDATE subscription SET status = ? WHERE id = ? AND clinic_id = ?');
    if ($updatePending) {
        $pending = 'pending';
        $subscriptionId = intval($subscription['id']);
        $updatePending->bind_param('sii', $pending, $subscriptionId, $clinicId);
        $updatePending->execute();
        $updatePending->close();
    }
    api_respond([
        'error'           => false,
        'message'         => 'Payment is not completed yet. Finish checkout and try again.',
        'status'          => 'pending',
        'payment_status'  => $paymentStatus,
        'reference'       => $reference,
    ]);
}

$conn->begin_transaction();
try {
    $updatePaid = $conn->prepare('UPDATE subscription SET status = ? WHERE id = ? AND clinic_id = ?');
    if (!$updatePaid) {
        throw new Exception('Failed to prepare subscription update: ' . $conn->error);
    }
    $newStatus = 'active';
    $subscriptionId = intval($subscription['id']);
    $updatePaid->bind_param('sii', $newStatus, $subscriptionId, $clinicId);
    if (!$updatePaid->execute()) {
        $updatePaid->close();
        throw new Exception('Failed to update subscription status');
    }
    $updatePaid->close();

    $fetchStatus = $conn->prepare('SELECT status, start_date, end_date FROM subscription WHERE id = ? LIMIT 1');
    if (!$fetchStatus) {
        throw new Exception('Failed to read updated subscription: ' . $conn->error);
    }
    $fetchStatus->bind_param('i', $subscriptionId);
    $fetchStatus->execute();
    $statusRes = $fetchStatus->get_result();
    $statusRow = $statusRes ? $statusRes->fetch_assoc() : null;
    $fetchStatus->close();

    if (!$statusRow) {
        throw new Exception('Updated subscription not found');
    }

    $conn->commit();

    api_respond([
        'error'           => false,
        'message'         => 'Payment confirmed. Subscription activated successfully.',
        'status'          => (string)$statusRow['status'],
        'reference'       => $reference,
        'subscription_id' => $subscriptionId,
        'start_date'      => $statusRow['start_date'],
        'end_date'        => $statusRow['end_date'],
    ]);
} catch (Exception $e) {
    $conn->rollback();
    api_respond(['error' => true, 'message' => $e->getMessage()]);
}

