<?php
/**
 * Stripe Configuration
 *
 * TESTING:
 *  - Use sk_test_... keys from https://dashboard.stripe.com/test/apikeys
 *  - Test card: 4242 4242 4242 4242  |  Any future date  |  Any CVC  |  Any ZIP
 *  - More test cards: https://stripe.com/docs/testing#cards
 *
 * PRODUCTION:
 *  - Replace sk_test_... with sk_live_...
 *  - Update SUCCESS_URL / CANCEL_URL to real return URLs
 */

// Per-machine settings (not committed): copy stripe_config.local.php and set your keys.
if (file_exists(__DIR__ . '/stripe_config.local.php')) {
    include __DIR__ . '/stripe_config.local.php';
}

if (!defined('STRIPE_SECRET_KEY')) {
    define('STRIPE_SECRET_KEY', getenv('STRIPE_SECRET_KEY') ?: '');
}
if (!defined('STRIPE_PUBLISHABLE_KEY')) {
    define('STRIPE_PUBLISHABLE_KEY', getenv('STRIPE_PUBLISHABLE_KEY') ?: '');
}
if (!defined('STRIPE_CURRENCY')) {
    define('STRIPE_CURRENCY', getenv('STRIPE_CURRENCY') ?: 'eur'); // change to 'usd' or 'mad' etc.
}

// --- Auto-detect server base URL so the app works on any network/IP ---
if (!defined('STRIPE_BASE_URL')) {
    $__scheme = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $__host   = isset($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : 'localhost';
    define('STRIPE_BASE_URL', $__scheme . '://' . $__host);
}
if (!defined('STRIPE_SUCCESS_URL')) {
    define('STRIPE_SUCCESS_URL',
        getenv('STRIPE_SUCCESS_URL') ?:
        STRIPE_BASE_URL . '/reed/payment_return.php?status=success&session_id={CHECKOUT_SESSION_ID}'
    );
}
if (!defined('STRIPE_CANCEL_URL')) {
    define('STRIPE_CANCEL_URL',
        getenv('STRIPE_CANCEL_URL') ?:
        STRIPE_BASE_URL . '/reed/payment_return.php?status=cancel'
    );
}

// Local WAMP often misses root CA chain; keep this configurable for TEST mode.
if (!defined('STRIPE_DISABLE_SSL_VERIFY')) {
    $envDisable = getenv('STRIPE_DISABLE_SSL_VERIFY');
    if ($envDisable !== false && $envDisable !== '') {
        define('STRIPE_DISABLE_SSL_VERIFY', $envDisable === '1');
    } else {
        $host = isset($_SERVER['HTTP_HOST']) ? (string)$_SERVER['HTTP_HOST'] : 'localhost';
        define('STRIPE_DISABLE_SSL_VERIFY', $host === 'localhost' || $host === '127.0.0.1' || str_starts_with($host, '192.168.'));
    }
}
