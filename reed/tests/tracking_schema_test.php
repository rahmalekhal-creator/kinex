<?php
/**
 * Tests of the tracked-exercise schema (e4 + body regions), on a scratch database that is created and dropped here:
 *   - the migrations: up files idempotent where they say so, e1-e3 rows unchanged, down files restore the schema
 *   - the PHP path (ensure_tracking_schema): idempotent seed, catalogue order and regions
 *   - the e4 prescription field (target_deg) and the per-rep results (labels, statuses, peak_deg)
 *   - the usual lift (median of the good-form reps) and the e4 progress per day
 *
 *   php reed/tests/tracking_schema_test.php
 * Connection: KINEX_TEST_DB_HOST (127.0.0.1), KINEX_TEST_DB_PORT (3306), KINEX_TEST_DB_USER (root),
 * KINEX_TEST_DB_PASS (''). The user must be allowed to create / drop the database kinex_tracking_test.
 */
if (PHP_SAPI !== 'cli') { // reed/ is served by the web server: this file only runs from the command line
    http_response_code(404);
    exit;
}
error_reporting(E_ALL);
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

$root = dirname(__DIR__);
require_once $root . '/notifications_lib.php';
require_once $root . '/tracked_exercises_lib.php';

$failures = 0;
$checks = 0;
function check($cond, $what)
{
    global $failures, $checks;
    $checks++;
    if ($cond) {
        echo "  ok   $what\n";
    } else {
        $failures++;
        echo "  FAIL $what\n";
    }
}

function env_or($k, $d)
{
    $v = getenv($k);
    return ($v === false || $v === '') ? $d : $v;
}

$db = 'kinex_tracking_test';
$conn = new mysqli(env_or('KINEX_TEST_DB_HOST', '127.0.0.1'), env_or('KINEX_TEST_DB_USER', 'root'),
    env_or('KINEX_TEST_DB_PASS', ''), '', intval(env_or('KINEX_TEST_DB_PORT', '3306')));
$conn->set_charset('utf8mb4');

function run_sql_file($conn, $path)
{
    $sql = file_get_contents($path);
    $conn->multi_query($sql);
    do {
        if ($r = $conn->store_result()) {
            $r->free();
        }
    } while ($conn->more_results() && $conn->next_result());
}

function rows($conn, $sql)
{
    $out = array();
    $res = $conn->query($sql);
    while ($res && ($row = $res->fetch_assoc())) {
        $out[] = $row;
    }
    return $out;
}

function schema($conn)
{
    $out = array();
    foreach (rows($conn, 'SHOW TABLES') as $t) {
        $name = array_values($t)[0];
        $c = rows($conn, "SHOW CREATE TABLE `$name`")[0]['Create Table'];
        $out[$name] = preg_replace('/ AUTO_INCREMENT=\d+/', '', $c);
    }
    ksort($out);
    return $out;
}

function fresh_db($conn, $db, $root)
{
    $conn->query("DROP DATABASE IF EXISTS `$db`");
    $conn->query("CREATE DATABASE `$db` CHARACTER SET utf8mb4");
    $conn->select_db($db);
    run_sql_file($conn, $root . '/physio_clinic.sql');
    notif_ensure_schema($conn); // live_set, notification, ... as the endpoints create them
    // an e1 and an e2 assignment, as the app stores them today
    $conn->query("UPDATE patientexercise SET ai_exercise = 'e2', side = 'left' WHERE id = 9");
    $conn->query("UPDATE patientexercise SET ai_exercise = 'e1', side = 'right' WHERE id = 8");
}

$mig = $root . '/migrations/';
try {
    // ------------------------------------------------------------------------------------------ SQL migrations
    echo "SQL migrations\n";
    fresh_db($conn, $db, $root);
    $before = schema($conn);
    $peBefore = rows($conn, 'SELECT * FROM patientexercise ORDER BY id');
    $setBefore = rows($conn, 'SELECT * FROM live_set ORDER BY id');

    run_sql_file($conn, $mig . '2026_10_27_01_tracked_exercises.up.sql');
    $seed1 = rows($conn, 'SELECT * FROM tracked_exercise ORDER BY id');
    run_sql_file($conn, $mig . '2026_10_27_01_tracked_exercises.up.sql');
    $seed2 = rows($conn, 'SELECT * FROM tracked_exercise ORDER BY id');
    check($seed1 === $seed2, '01 up run twice: the seed is unchanged');
    check(array_column($seed1, 'id') === array('e1', 'e2', 'e3', 'e4'), '01 up: e1..e4 seeded');
    $regions = array_column($seed1, 'body_region', 'id');
    check($regions === array('e1' => 'shoulder', 'e2' => 'shoulder', 'e3' => 'shoulder', 'e4' => 'hip'),
        '01 up: e1-e3 shoulder, e4 hip');
    check($seed1[3]['side_kind'] === 'leg' && $seed1[0]['side_kind'] === 'arm', '01 up: e4 asks a leg, e1 an arm');
    check($seed1[3]['name'] === 'Standing hip abduction (chair support)', '01 up: e4 name from the catalogue');
    check(json_decode($seed1[3]['classes'], true) === array('good', 'knee', 'leanin', 'leanout'), '01 up: e4 classes');

    run_sql_file($conn, $mig . '2026_10_27_02_e4_prescription.up.sql');
    run_sql_file($conn, $mig . '2026_10_27_03_live_rep.up.sql');
    run_sql_file($conn, $mig . '2026_10_28_04_aifeedback_set_link.up.sql');
    check(tracking_column_exists($conn, 'aifeedback', 'live_set_id'), '04 up: aifeedback.live_set_id');
    $peAfter = rows($conn, 'SELECT * FROM patientexercise ORDER BY id');
    $unchanged = count($peAfter) === count($peBefore);
    foreach ($peAfter as $i => $row) {
        $t = $row['target_deg'];
        unset($row['target_deg']);
        $unchanged = $unchanged && $row === $peBefore[$i] && $t === null;
    }
    check($unchanged, '02 up: existing assignments (e1 / e2) unchanged, target_deg NULL');
    check(rows($conn, 'SELECT * FROM live_set ORDER BY id') === array_map(function ($r) {
        return $r + array('below_target' => '0', 'wrong_side' => '0');
    }, $setBefore), '03 up: existing sets unchanged, new counts 0');

    // the check constraints accept the e4 labels / statuses and reject others
    $conn->query("INSERT INTO live_rep (live_set_id, ppid, patient_id, ai_exercise, rep, label, status, peak_deg,
                  target_deg, created_at) VALUES (1, 7, 2, 'e4', 1, 'leanin', 'mistake', 30, 27.4, NOW()),
                  (1, 7, 2, 'e4', 2, 'good', 'below_target', 12, 27.4, NOW()),
                  (1, 7, 2, 'e2', 3, 'wrong_side', 'wrong_side', NULL, NULL, NOW())");
    check(count(rows($conn, 'SELECT id FROM live_rep')) === 3, '03 up: live_rep accepts knee/leanin/leanout, below_target, wrong_side');
    $rejected = false;
    try {
        $conn->query("INSERT INTO live_rep (live_set_id, ppid, patient_id, rep, label, status, created_at)
                      VALUES (1, 7, 2, 4, 'good', 'excellent', NOW())");
    } catch (mysqli_sql_exception $e) {
        $rejected = true;
    }
    check($rejected, '03 up: an unknown status is rejected');
    $conn->query('DELETE FROM live_rep');

    run_sql_file($conn, $mig . '2026_10_28_04_aifeedback_set_link.down.sql');
    run_sql_file($conn, $mig . '2026_10_27_03_live_rep.down.sql');
    run_sql_file($conn, $mig . '2026_10_27_02_e4_prescription.down.sql');
    run_sql_file($conn, $mig . '2026_10_27_01_tracked_exercises.down.sql');
    check(schema($conn) === $before, 'down 03, 02, 01: the schema is back to what it was');
    check(rows($conn, 'SELECT * FROM patientexercise ORDER BY id') === $peBefore, 'down: assignments unchanged');

    // ------------------------------------------------------------------------------------------ PHP path
    echo "PHP schema (ensure_tracking_schema)\n";
    // the same database, back to its original schema by the down files (notif_ensure_schema runs once per process)
    ensure_tracking_schema($conn);
    $s1 = rows($conn, 'SELECT * FROM tracked_exercise ORDER BY id');
    seed_tracked_exercises($conn);
    seed_tracked_exercises($conn);
    check(rows($conn, 'SELECT * FROM tracked_exercise ORDER BY id') === $s1, 'seed run again: nothing changes');
    check(count(rows($conn, 'SELECT * FROM body_region')) === 2, 'two regions');
    $migrated = rows($conn, 'SELECT * FROM tracked_exercise ORDER BY id');
    run_sql_file($conn, $mig . '2026_10_27_01_tracked_exercises.up.sql');
    check(rows($conn, 'SELECT * FROM tracked_exercise ORDER BY id') === $migrated, 'PHP seed = SQL migration seed');
    $grouped = rows($conn, 'SELECT t.id, t.body_region FROM tracked_exercise t JOIN body_region r ON r.id = t.body_region
                            ORDER BY r.display_order, t.display_order');
    check(array_column($grouped, 'id') === array('e1', 'e2', 'e3', 'e4'), 'grouped: Shoulder (e1, e2, e3) then Hip (e4)');
    check(tracking_column_exists($conn, 'patientexercise', 'target_deg'), 'target_deg added');
    check(tracking_column_exists($conn, 'live_set', 'below_target') && tracking_column_exists($conn, 'live_set', 'wrong_side'),
        'live_set counts added');
    check(tracking_column_exists($conn, 'aifeedback', 'live_set_id'), 'aifeedback.live_set_id added');
    check(tracked_exercise_ids() === array('e1', 'e2', 'e3', 'e4') && tracked_is_leg('e4') && !tracked_is_leg('e2'),
        'catalogue ids and leg exercise');

    // ------------------------------------------------------------------------------------------ fields
    echo "e4 prescription and rep fields\n";
    check(parse_target_deg('') === null, 'target_deg empty -> NULL (not set)');
    check(parse_target_deg('35') === 35.0 && parse_target_deg('27,5') === 27.5, 'target_deg 35 / 27,5 accepted');
    check(parse_target_deg('2') === false && parse_target_deg('120') === false && parse_target_deg('abc') === false,
        'target_deg out of range / not a number rejected');
    $reps = parse_live_reps(json_encode(array(
        array('rep' => 1, 'label' => 'good', 'status' => 'below_target', 'confidence' => 0.9, 'peak_deg' => 12.3, 'target_deg' => 27.4),
        array('rep' => 2, 'label' => 'knee', 'status' => 'mistake', 'confidence' => 0.8),
        array('rep' => 3, 'label' => 'dance', 'status' => 'good'),
        array('rep' => 4, 'label' => 'wrong_side', 'status' => 'wrong_side'),
    )));
    check(count($reps) === 3 && $reps[0]['peak_deg'] === 12.3 && $reps[1]['peak_deg'] === null, 'reps: unknown label dropped');

    // ------------------------------------------------------------------------------------------ usual lift, progress
    echo "usual lift and e4 progress\n";
    $conn->query("UPDATE patientexercise SET ai_exercise = 'e4', side = 'left', target_deg = 30.0 WHERE id = 11");
    check(e4_usual_lift($conn, 2) === null, 'no e4 rep yet: usual lift unknown');
    $conn->query("INSERT INTO live_set (set_uid, ppid, patient_id, judged, created_at) VALUES
                  ('t1', 11, 2, 4, '2026-10-01 10:00:00'), ('t2', 11, 2, 3, '2026-10-08 10:00:00')");
    $ids = array_column(rows($conn, "SELECT id FROM live_set WHERE set_uid IN ('t1','t2') ORDER BY set_uid"), 'id');
    $conn->query("INSERT INTO live_rep (live_set_id, ppid, patient_id, ai_exercise, rep, label, status, confidence, peak_deg,
                  target_deg, created_at) VALUES
                  ({$ids[0]}, 11, 2, 'e4', 1, 'good', 'below_target', 0.9, 20, 27.4, NOW()),
                  ({$ids[0]}, 11, 2, 'e4', 2, 'good', 'good', 0.9, 40, 27.4, NOW()),
                  ({$ids[0]}, 11, 2, 'e4', 3, 'knee', 'mistake', 0.8, 50, 27.4, NOW()),
                  ({$ids[0]}, 11, 2, 'e4', 4, 'good', 'unsure', 0.4, 90, 27.4, NOW()),
                  ({$ids[1]}, 11, 2, 'e4', 1, 'good', 'good', 0.9, 44, 30, NOW()),
                  ({$ids[1]}, 11, 2, 'e4', 2, 'good', 'good', 0.9, 46, 30, NOW()),
                  ({$ids[1]}, 11, 2, 'e4', 3, 'wrong_side', 'wrong_side', NULL, NULL, NULL, NOW())");
    check(e4_usual_lift($conn, 2) === 42.0, 'usual lift = median of good-form reps (20, 40, 44, 46) = 42');
    $p = e4_progress($conn, 2);
    check(count($p['sessions']) === 2 && $p['sessions'][0]['date'] === '2026-10-01', 'progress: one entry per day, oldest first');
    check($p['sessions'][0]['median_peak_deg'] === 30.0 && $p['sessions'][1]['median_peak_deg'] === 45.0,
        'progress: median peak of good-form reps per day (30, then 45)');
    check($p['sessions'][0]['by_label']['knee'] === 1 && $p['sessions'][0]['scored'] === 4, 'progress: reps per class');
    check($p['sessions'][0]['good_share'] === 0.5 && $p['sessions'][1]['good_share'] === 1.0, 'progress: good-form share');
    check($p['sessions'][1]['by_status']['wrong_side'] === 1, 'progress: wrong-side reps listed, not scored');
    check($p['target_deg'] === 30.0 && $p['usual_lift_deg'] === 42.0, 'progress: current target and usual lift');

    // ------------------------------------------------------------------------------------------ session feedback
    echo "session feedback (session log)
";
    $conn->query("INSERT INTO progressreport (id, date, reps_done, pain_level, notes, ppid) VALUES
                  (50, '2026-10-20 10:00:00', 6, 3, 'two sets', 11)");
    $conn->query("INSERT INTO live_set (set_uid, ppid, patient_id, progress_id, judged, good, mistakes, unsure, below_target,
                  wrong_side, pain_reported, events, created_at) VALUES
                  ('f1', 11, 2, 50, 3, 1, 1, 0, 1, 1, 1, '[{\"time\":\"0:12\",\"source\":\"voice\"}]', '2026-10-20 10:00:00'),
                  ('f2', 11, 2, 50, 2, 2, 0, 0, 0, 0, 0, '[]', '2026-10-20 10:05:00')");
    $f = array_column(rows($conn, "SELECT id FROM live_set WHERE set_uid IN ('f1','f2') ORDER BY set_uid"), 'id');
    $conn->query("INSERT INTO aifeedback (analysis, score, generated_at, progressreport_id, vid_url, live_set_id) VALUES
                  ('second set text', 100, '2026-10-20 10:05:01', 50, '', {$f[1]}),
                  ('first set text', 33.3, '2026-10-20 10:00:01', 50, '', {$f[0]})");
    $conn->query("INSERT INTO live_rep (live_set_id, ppid, patient_id, ai_exercise, rep, label, status, confidence, peak_deg,
                  target_deg, created_at) VALUES
                  ({$f[0]}, 11, 2, 'e4', 1, 'good', 'good', 0.9, 40, 30, NOW()),
                  ({$f[0]}, 11, 2, 'e4', 2, 'knee', 'mistake', 0.8, 42, 30, NOW()),
                  ({$f[0]}, 11, 2, 'e4', 3, 'wrong_side', 'wrong_side', NULL, NULL, NULL, NOW())");
    $sf = session_feedback($conn, 50);
    check($sf !== null && $sf['progress']['reps_done'] === 6 && $sf['progress']['pain_level'] === 3, 'the report');
    check($sf['exercise']['ai_exercise'] === 'e4' && $sf['exercise']['side'] === 'left', 'the tracked exercise and side');
    check(count($sf['sets']) === 2 && $sf['sets'][0]['good'] === 1 && $sf['sets'][0]['below_target'] === 1
        && $sf['sets'][0]['wrong_side'] === 1, 'the sets in order with their counts');
    check($sf['sets'][0]['analysis'] === 'first set text' && $sf['sets'][1]['analysis'] === 'second set text'
        && $sf['sets'][0]['score'] === 33.3, 'each set gets its own AI feedback (linked by live_set_id)');
    check(count($sf['sets'][0]['reps']) === 3 && $sf['sets'][0]['reps'][1]['label'] === 'knee'
        && $sf['sets'][0]['reps'][0]['peak_deg'] === 40.0 && $sf['sets'][1]['reps'] === array(), 'the reps of each set');
    check($sf['sets'][0]['pain_reported'] === true && count($sf['sets'][0]['events']) === 1, 'pain reported during a set');
    $conn->query("UPDATE aifeedback SET live_set_id = NULL WHERE progressreport_id = 50");
    $sf = session_feedback($conn, 50);
    check($sf['sets'][0]['analysis'] === 'first set text', 'older rows without a link: matched in order');
    check(session_feedback($conn, 99999) === null, 'unknown report -> null');
} finally {
    $conn->query("DROP DATABASE IF EXISTS `$db`");
}

echo "\n$checks checks, $failures failed\n";
exit($failures === 0 ? 0 : 1);
