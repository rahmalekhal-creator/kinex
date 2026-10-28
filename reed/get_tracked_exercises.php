<?php
/**
 * The exercises the live camera assistant follows, grouped by body region in catalogue order.
 * GET -> {error: false, regions: [{id, label, order, exercises: [{id, name, body_region, order, side_kind,
 *         side_question, side_meaning, instructions, classes}]}]}
 */
ob_start();
ini_set('display_errors', '0');
error_reporting(E_ALL);
header('Content-Type: application/json; charset=UTF-8');

require_once 'db.php';
require_once 'ai_columns.php';

function respond($payload)
{
    if (ob_get_length()) {
        ob_clean();
    }
    echo json_encode($payload);
    exit;
}

if (!isset($conn) || !($conn instanceof mysqli)) {
    respond(['error' => true, 'message' => 'Database connection not initialized']);
}
ensure_ai_columns($conn);

$regions = [];
$res = $conn->query('SELECT id, label, display_order FROM body_region ORDER BY display_order, id');
while ($res && ($row = $res->fetch_assoc())) {
    $regions[$row['id']] = ['id' => $row['id'], 'label' => $row['label'], 'order' => intval($row['display_order']),
                            'exercises' => []];
}
$res = $conn->query('SELECT id, body_region, display_order, name, side_kind, side_question, side_meaning, instructions,
                            classes FROM tracked_exercise ORDER BY display_order, id');
while ($res && ($row = $res->fetch_assoc())) {
    if (!isset($regions[$row['body_region']])) {
        continue;
    }
    $regions[$row['body_region']]['exercises'][] = [
        'id' => $row['id'],
        'name' => $row['name'],
        'body_region' => $row['body_region'],
        'order' => intval($row['display_order']),
        'side_kind' => $row['side_kind'],
        'side_question' => $row['side_question'],
        'side_meaning' => $row['side_meaning'],
        'instructions' => json_decode($row['instructions'], true),
        'classes' => json_decode($row['classes'], true),
    ];
}
respond(['error' => false, 'regions' => array_values($regions)]);
