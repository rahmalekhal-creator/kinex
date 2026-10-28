<?php
require_once __DIR__ . '/tracked_exercises_lib.php';

/**
 * Live camera tracking settings of an assignment, decided by the physiotherapist:
 *   patientexercise.ai_exercise     which tracked exercise this is (e1 .. e4), NULL = not tracked
 *   patientexercise.side            the arm to follow, or for e4 the lifted leg ('left' / 'right')
 *   patientexercise.target_deg      e4 only: the target lift angle (degrees), NULL = not set
 *   patientexercise.start_date      start date of the prescription span (YYYY-MM-DD)
 *   patientexercise.end_date        end date of the prescription span (YYYY-MM-DD)
 *   patientexercise.frequency       frequency of exercise ('daily', 'weekdays', or specific days '1,3,5')
 *   patientexercise.prescription_id groups daily instances under a single prescription
 * The columns are added on first use, so an existing database needs no manual migration.
 */
function ensure_ai_columns($conn)
{
    static $done = false;
    if ($done) {
        return;
    }
    $done = true;
    foreach (array(
        'ai_exercise' => 'VARCHAR(8) NULL DEFAULT NULL',
        'side' => 'VARCHAR(8) NULL DEFAULT NULL',
        'start_date' => 'DATE NULL DEFAULT NULL',
        'end_date' => 'DATE NULL DEFAULT NULL',
        'frequency' => "VARCHAR(50) NULL DEFAULT 'daily'",
        'prescription_id' => 'VARCHAR(64) NULL DEFAULT NULL'
    ) as $col => $def) {
        $res = $conn->query("SHOW COLUMNS FROM patientexercise LIKE '$col'");
        if ($res && $res->num_rows === 0) {
            $conn->query("ALTER TABLE patientexercise ADD COLUMN `$col` $def");
        }
    }
    // Backfill legacy assignments that have no start_date / prescription_id
    $conn->query("UPDATE patientexercise SET 
        start_date = COALESCE(assigned_date, CURDATE()), 
        end_date = COALESCE(assigned_date, CURDATE()), 
        frequency = 'daily', 
        prescription_id = CONCAT('rx_legacy_', id) 
        WHERE start_date IS NULL");

    ensure_tracking_schema($conn);
}

function valid_ai_exercise($v)
{
    return in_array($v, tracked_exercise_ids(), true);
}

function valid_ai_side($v)
{
    return in_array($v, array('left', 'right'), true);
}
