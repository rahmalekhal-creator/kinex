<?php
/**
 * The exercises the live camera assistant follows (e1-e4), their body regions, and the e4 range data.
 *
 *   body_region        shoulder / hip: label and display order
 *   tracked_exercise   e1..e4: region, order, name, side question, instructions, classes, model files
 *                      (seeded from data/exercise_catalog.json = e4_app_bundle/exercise_catalog.json)
 *   patientexercise.target_deg   e4: the physiotherapist's target lift angle (degrees, NULL = not set)
 *   live_rep           one row per rep of a live set: label, status, confidence, peak_deg, target_deg
 *   live_set.below_target / wrong_side   counts per set
 *
 * Everything is created on first use (ensure_tracking_schema), like the AI columns; the same changes are in
 * migrations/2026_10_27_0*.up.sql (and .down.sql to undo them). Running the seed twice changes nothing.
 */

const TRACKED_SIDES = array('left', 'right');
const TRACKED_REP_STATUSES = array('good', 'mistake', 'unsure', 'not_scored', 'below_target', 'wrong_side');
const TRACKED_REP_LABELS = array('good', 'elb', 'rngdown', 'imb', 'shld', 'lean', 'wrong', 'knee', 'leanin', 'leanout',
    'not_scored', 'wrong_side');
const E4_TARGET_MIN_DEG = 5.0;
const E4_TARGET_MAX_DEG = 90.0;

function tracking_column_exists($conn, $table, $column)
{
    $res = $conn->query("SHOW COLUMNS FROM `$table` LIKE '" . $conn->real_escape_string($column) . "'");
    return $res && $res->num_rows > 0;
}

function tracking_table_exists($conn, $table)
{
    $res = $conn->query("SHOW TABLES LIKE '" . $conn->real_escape_string($table) . "'");
    return $res && $res->num_rows > 0;
}

/** The catalogue (regions + exercises) of data/exercise_catalog.json. */
function tracked_catalog()
{
    static $catalog = null;
    if ($catalog === null) {
        $raw = @file_get_contents(__DIR__ . '/data/exercise_catalog.json');
        $catalog = $raw ? json_decode($raw, true) : null;
        if (!is_array($catalog)) {
            $catalog = array('regions' => array(), 'exercises' => array());
        }
    }
    return $catalog;
}

/** Upserts the regions and exercises of the catalogue: running it again changes nothing. */
function seed_tracked_exercises($conn)
{
    $cat = tracked_catalog();
    $r = $conn->prepare('INSERT INTO body_region (id, label, display_order) VALUES (?, ?, ?)
                         ON DUPLICATE KEY UPDATE label = VALUES(label), display_order = VALUES(display_order)');
    foreach ($cat['regions'] as $reg) {
        $id = (string)$reg['id'];
        $label = (string)$reg['label'];
        $order = intval($reg['order']);
        $r->bind_param('ssi', $id, $label, $order);
        $r->execute();
    }
    $r->close();
    $e = $conn->prepare('INSERT INTO tracked_exercise (id, body_region, display_order, name, side_kind, side_question,
                           side_meaning, camera, instructions, classes, model_bundle, model_config, model_file)
                         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                         ON DUPLICATE KEY UPDATE body_region = VALUES(body_region), display_order = VALUES(display_order),
                           name = VALUES(name), side_kind = VALUES(side_kind), side_question = VALUES(side_question),
                           side_meaning = VALUES(side_meaning), camera = VALUES(camera), instructions = VALUES(instructions),
                           classes = VALUES(classes), model_bundle = VALUES(model_bundle),
                           model_config = VALUES(model_config), model_file = VALUES(model_file)');
    foreach ($cat['exercises'] as $ex) {
        $id = (string)$ex['id'];
        $region = (string)$ex['region'];
        $order = intval($ex['order']);
        $name = (string)$ex['name'];
        $sideKind = $region === 'hip' ? 'leg' : 'arm';
        $q = (string)$ex['side_question'];
        $meaning = (string)$ex['side_meaning'];
        $camera = isset($ex['camera']) ? (string)$ex['camera'] : null;
        // compact JSON, as tool/tracked_exercises/make_migrations.py writes it (same seed both ways)
        $instr = json_encode($ex['instructions'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        $classes = json_encode($ex['classes'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        $bundle = (string)$ex['model']['bundle'];
        $config = (string)$ex['model']['config'];
        $file = (string)$ex['model']['file'];
        $e->bind_param('ssissssssssss', $id, $region, $order, $name, $sideKind, $q, $meaning, $camera, $instr, $classes,
            $bundle, $config, $file);
        $e->execute();
    }
    $e->close();
}

/**
 * Creates what is missing (tables, columns) and seeds the catalogue. Needs live_set (notif_init) for its
 * columns: they are added only if that table exists.
 */
function ensure_tracking_schema($conn)
{
    static $done = false;
    if ($done) {
        return;
    }
    $done = true;
    $conn->query("CREATE TABLE IF NOT EXISTS body_region (
        id VARCHAR(16) NOT NULL PRIMARY KEY,
        label VARCHAR(64) NOT NULL,
        display_order INT NOT NULL
    ) DEFAULT CHARSET=utf8mb4");
    $conn->query("CREATE TABLE IF NOT EXISTS tracked_exercise (
        id VARCHAR(8) NOT NULL PRIMARY KEY,
        body_region VARCHAR(16) NOT NULL,
        display_order INT NOT NULL,
        name VARCHAR(255) NOT NULL,
        side_kind VARCHAR(8) NOT NULL,
        side_question VARCHAR(255) NOT NULL,
        side_meaning VARCHAR(255) NOT NULL,
        camera TEXT NULL,
        instructions TEXT NOT NULL,
        classes TEXT NOT NULL,
        model_bundle VARCHAR(64) NOT NULL,
        model_config VARCHAR(64) NOT NULL,
        model_file VARCHAR(64) NOT NULL,
        KEY idx_tracked_region (body_region, display_order),
        CONSTRAINT fk_tracked_region FOREIGN KEY (body_region) REFERENCES body_region (id),
        CONSTRAINT chk_tracked_side_kind CHECK (side_kind IN ('arm', 'leg'))
    ) DEFAULT CHARSET=utf8mb4");
    seed_tracked_exercises($conn);
    if (!tracking_column_exists($conn, 'patientexercise', 'target_deg')) {
        $conn->query('ALTER TABLE patientexercise ADD COLUMN target_deg DECIMAL(5,1) NULL DEFAULT NULL');
    }
    $conn->query("CREATE TABLE IF NOT EXISTS live_rep (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        live_set_id INT NOT NULL,
        ppid INT NOT NULL,
        patient_id INT NOT NULL,
        ai_exercise VARCHAR(8) NULL,
        rep INT NOT NULL,
        label VARCHAR(16) NOT NULL,
        status VARCHAR(16) NOT NULL,
        confidence FLOAT NULL,
        peak_deg FLOAT NULL,
        target_deg FLOAT NULL,
        created_at DATETIME NOT NULL,
        UNIQUE KEY uq_live_rep (live_set_id, rep),
        KEY idx_live_rep_patient (patient_id, ai_exercise, label),
        CONSTRAINT chk_live_rep_status CHECK (status IN ('" . implode("','", TRACKED_REP_STATUSES) . "')),
        CONSTRAINT chk_live_rep_label CHECK (label IN ('" . implode("','", TRACKED_REP_LABELS) . "'))
    ) DEFAULT CHARSET=utf8mb4");
    ensure_aifeedback_set_link($conn);
    if (tracking_table_exists($conn, 'live_set')) {
        foreach (array('below_target', 'wrong_side') as $col) {
            if (!tracking_column_exists($conn, 'live_set', $col)) {
                $conn->query("ALTER TABLE live_set ADD COLUMN `$col` INT NOT NULL DEFAULT 0");
            }
        }
    }
}

/** e1..e4 (the ids of the catalogue). */
function tracked_exercise_ids()
{
    return array_map(function ($e) {
        return (string)$e['id'];
    }, tracked_catalog()['exercises']);
}

function tracked_region_of($id)
{
    foreach (tracked_catalog()['exercises'] as $e) {
        if ($e['id'] === $id) {
            return (string)$e['region'];
        }
    }
    return null;
}

function tracked_is_leg($id)
{
    return tracked_region_of($id) === 'hip';
}

/**
 * The physiotherapist's target angle from a form value: null when empty; false when invalid. Only for e4.
 */
function parse_target_deg($raw)
{
    $raw = trim((string)$raw);
    if ($raw === '') {
        return null;
    }
    $raw = str_replace(',', '.', $raw);
    if (!is_numeric($raw)) {
        return false;
    }
    $v = round(floatval($raw), 1);
    if ($v < E4_TARGET_MIN_DEG || $v > E4_TARGET_MAX_DEG) {
        return false;
    }
    return $v;
}

function tracked_median(array $values)
{
    $v = array_values(array_filter($values, 'is_finite'));
    $n = count($v);
    if ($n === 0) {
        return null;
    }
    sort($v);
    return $n % 2 ? $v[intdiv($n, 2)] : 0.5 * ($v[$n / 2 - 1] + $v[$n / 2]);
}

/**
 * The patient's usual e4 lift: the median peak angle of all their good-form reps (label good, judged with
 * confidence: status good or below_target). Null while there is none. Computed from the history, so it is
 * always up to date after each set.
 */
function e4_usual_lift($conn, $patientId)
{
    $st = $conn->prepare("SELECT peak_deg FROM live_rep WHERE patient_id = ? AND ai_exercise = 'e4' AND label = 'good'
                          AND status IN ('good', 'below_target') AND peak_deg IS NOT NULL");
    $st->bind_param('i', $patientId);
    $st->execute();
    $res = $st->get_result();
    $peaks = array();
    while ($row = $res->fetch_assoc()) {
        $peaks[] = floatval($row['peak_deg']);
    }
    $st->close();
    $m = tracked_median($peaks);
    return $m === null ? null : round($m, 1);
}

/** The reps of one set (JSON list from the phone), validated; unknown labels / statuses are dropped. */
function parse_live_reps($raw)
{
    $list = json_decode((string)$raw, true);
    if (!is_array($list)) {
        return array();
    }
    $num = function ($v) {
        return ($v === null || $v === '' || !is_numeric($v) || !is_finite(floatval($v))) ? null : floatval($v);
    };
    $out = array();
    foreach (array_slice($list, 0, 200) as $r) {
        if (!is_array($r)) {
            continue;
        }
        $label = isset($r['label']) ? (string)$r['label'] : '';
        $status = isset($r['status']) ? (string)$r['status'] : '';
        $rep = isset($r['rep']) ? intval($r['rep']) : 0;
        if ($rep <= 0 || !in_array($label, TRACKED_REP_LABELS, true) || !in_array($status, TRACKED_REP_STATUSES, true)) {
            continue;
        }
        $peak = $num(isset($r['peak_deg']) ? $r['peak_deg'] : null);
        $target = $num(isset($r['target_deg']) ? $r['target_deg'] : null);
        $out[] = array(
            'rep' => $rep,
            'label' => $label,
            'status' => $status,
            'confidence' => $num(isset($r['confidence']) ? $r['confidence'] : null),
            'peak_deg' => ($peak !== null && $peak >= -90 && $peak <= 180) ? $peak : null,
            'target_deg' => ($target !== null && $target >= 0 && $target <= 180) ? $target : null,
        );
    }
    return $out;
}

/**
 * e4 progress of a patient, one entry per day with e4 sets (oldest first): reps per class (scored reps), reps per
 * status, the share of good-form reps, the median peak angle of the good-form reps and the median target used;
 * plus the patient's usual lift and the target of their latest e4 assignment.
 */
function e4_progress($conn, $patientId)
{
    $sessions = array();
    if (tracking_table_exists($conn, 'live_set')) {
        $st = $conn->prepare("SELECT DATE(ls.created_at) AS day, lr.label, lr.status, lr.peak_deg, lr.target_deg
                              FROM live_rep lr INNER JOIN live_set ls ON ls.id = lr.live_set_id
                              WHERE lr.patient_id = ? AND lr.ai_exercise = 'e4'
                              ORDER BY ls.created_at ASC, lr.rep ASC");
        $st->bind_param('i', $patientId);
        $st->execute();
        $res = $st->get_result();
        $days = array();
        while ($row = $res->fetch_assoc()) {
            $d = (string)$row['day'];
            if (!isset($days[$d])) {
                $days[$d] = array('by_label' => array('good' => 0, 'knee' => 0, 'leanin' => 0, 'leanout' => 0),
                    'by_status' => array(), 'peaks' => array(), 'targets' => array(), 'scored' => 0, 'good_form' => 0);
            }
            $s = (string)$row['status'];
            $days[$d]['by_status'][$s] = (isset($days[$d]['by_status'][$s]) ? $days[$d]['by_status'][$s] : 0) + 1;
            if (in_array($s, array('good', 'below_target', 'mistake', 'unsure'), true)) {
                $days[$d]['scored']++;
                $l = (string)$row['label'];
                $days[$d]['by_label'][$l] = (isset($days[$d]['by_label'][$l]) ? $days[$d]['by_label'][$l] : 0) + 1;
            }
            if ($s === 'good' || $s === 'below_target') {
                $days[$d]['good_form']++;
                if ($row['peak_deg'] !== null) {
                    $days[$d]['peaks'][] = floatval($row['peak_deg']);
                }
            }
            if ($row['target_deg'] !== null) {
                $days[$d]['targets'][] = floatval($row['target_deg']);
            }
        }
        $st->close();
        foreach ($days as $day => $v) {
            $median = tracked_median($v['peaks']);
            $target = tracked_median($v['targets']);
            $sessions[] = array(
                'date' => $day,
                'scored' => $v['scored'],
                'by_label' => $v['by_label'],
                'by_status' => $v['by_status'],
                'good_share' => $v['scored'] > 0 ? round($v['good_form'] / $v['scored'], 3) : null,
                'median_peak_deg' => $median === null ? null : round($median, 1),
                'target_deg' => $target === null ? null : round($target, 1),
            );
        }
    }
    $tg = $conn->prepare("SELECT target_deg FROM patientexercise WHERE patient_id = ? AND ai_exercise = 'e4'
                          ORDER BY assigned_date DESC, id DESC LIMIT 1");
    $tg->bind_param('i', $patientId);
    $tg->execute();
    $row = $tg->get_result()->fetch_assoc();
    $tg->close();
    return array(
        'sessions' => $sessions,
        'usual_lift_deg' => e4_usual_lift($conn, $patientId),
        'target_deg' => ($row && $row['target_deg'] !== null) ? floatval($row['target_deg']) : null,
    );
}

/** aifeedback.live_set_id: the set an AI feedback row belongs to (NULL for rows written before it existed). */
function ensure_aifeedback_set_link($conn)
{
    if (tracking_table_exists($conn, 'aifeedback') && !tracking_column_exists($conn, 'aifeedback', 'live_set_id')) {
        $conn->query('ALTER TABLE aifeedback ADD COLUMN live_set_id INT NULL DEFAULT NULL');
    }
}

/**
 * One session (a progress report = an exercise on a day; its live sets add up) with everything the feedback screen
 * shows: the report (reps, pain, notes), the exercise (tracked id, side), and each live set with its counts, pain,
 * score / text analysis and its reps (label, status, confidence, e4 peak and target). Null if not found.
 */
function session_feedback($conn, $progressId)
{
    $st = $conn->prepare('SELECT pr.id, pr.date, pr.reps_done, pr.pain_level, pr.notes, pr.ppid, pe.patient_id,
                                 pe.ai_exercise, pe.side, pe.sets, pe.reps, e.name AS exercise_name
                          FROM progressreport pr
                          INNER JOIN patientexercise pe ON pe.id = pr.ppid
                          LEFT JOIN exercise e ON e.id = pe.exercise_id
                          WHERE pr.id = ? LIMIT 1');
    $st->bind_param('i', $progressId);
    $st->execute();
    $pr = $st->get_result()->fetch_assoc();
    $st->close();
    if (!$pr) {
        return null;
    }
    $sets = array();
    if (tracking_table_exists($conn, 'live_set')) {
        $cols = 'id, created_at, judged, good, mistakes, unsure, pain_reported, pain_level, events';
        foreach (array('below_target', 'wrong_side') as $c) {
            $cols .= tracking_column_exists($conn, 'live_set', $c) ? ", $c" : ", 0 AS $c";
        }
        $ls = $conn->prepare("SELECT $cols FROM live_set WHERE progress_id = ? ORDER BY created_at, id");
        $ls->bind_param('i', $progressId);
        $ls->execute();
        $res = $ls->get_result();
        while ($row = $res->fetch_assoc()) {
            $sets[] = $row;
        }
        $ls->close();
    }
    // the AI feedback rows (score, text analysis): by their set, else in the same order as the sets (older rows)
    $fb = array();
    $hasLink = tracking_column_exists($conn, 'aifeedback', 'live_set_id');
    $af = $conn->prepare('SELECT id, score, analysis' . ($hasLink ? ', live_set_id' : ', NULL AS live_set_id') .
                         ' FROM aifeedback WHERE progressreport_id = ? ORDER BY generated_at, id');
    $af->bind_param('i', $progressId);
    $af->execute();
    $res = $af->get_result();
    while ($row = $res->fetch_assoc()) {
        $fb[] = $row;
    }
    $af->close();
    $bySet = array();
    $unlinked = array();
    foreach ($fb as $row) {
        if ($row['live_set_id'] !== null) {
            $bySet[intval($row['live_set_id'])] = $row;
        } else {
            $unlinked[] = $row;
        }
    }
    $out = array();
    foreach ($sets as $i => $s) {
        $sid = intval($s['id']);
        $f = isset($bySet[$sid]) ? $bySet[$sid] : (count($sets) === count($unlinked) ? $unlinked[$i] : null);
        $reps = array();
        if (tracking_table_exists($conn, 'live_rep')) {
            $lr = $conn->prepare('SELECT rep, label, status, confidence, peak_deg, target_deg FROM live_rep
                                  WHERE live_set_id = ? ORDER BY rep');
            $lr->bind_param('i', $sid);
            $lr->execute();
            $r2 = $lr->get_result();
            while ($row = $r2->fetch_assoc()) {
                $reps[] = array(
                    'rep' => intval($row['rep']),
                    'label' => (string)$row['label'],
                    'status' => (string)$row['status'],
                    'confidence' => $row['confidence'] !== null ? floatval($row['confidence']) : null,
                    'peak_deg' => $row['peak_deg'] !== null ? floatval($row['peak_deg']) : null,
                    'target_deg' => $row['target_deg'] !== null ? floatval($row['target_deg']) : null,
                );
            }
            $lr->close();
        }
        $events = json_decode((string)$s['events'], true);
        $out[] = array(
            'id' => $sid,
            'created_at' => (string)$s['created_at'],
            'judged' => intval($s['judged']),
            'good' => intval($s['good']),
            'mistakes' => intval($s['mistakes']),
            'unsure' => intval($s['unsure']),
            'below_target' => intval($s['below_target']),
            'wrong_side' => intval($s['wrong_side']),
            'pain_reported' => intval($s['pain_reported']) === 1,
            'pain_level' => $s['pain_level'] !== null ? intval($s['pain_level']) : null,
            'events' => is_array($events) ? $events : array(),
            'score' => ($f && $f['score'] !== null) ? floatval($f['score']) : null,
            'analysis' => $f ? (string)$f['analysis'] : '',
            'reps' => $reps,
        );
    }
    return array(
        'progress' => array(
            'id' => intval($pr['id']),
            'date' => (string)$pr['date'],
            'reps_done' => intval($pr['reps_done']),
            'pain_level' => $pr['pain_level'] !== null ? intval($pr['pain_level']) : null,
            'notes' => $pr['notes'] !== null ? (string)$pr['notes'] : '',
        ),
        'exercise' => array(
            'ppid' => intval($pr['ppid']),
            'patient_id' => intval($pr['patient_id']),
            'name' => $pr['exercise_name'] !== null ? (string)$pr['exercise_name'] : 'Exercise',
            'ai_exercise' => ($pr['ai_exercise'] !== null && $pr['ai_exercise'] !== '') ? (string)$pr['ai_exercise'] : null,
            'side' => ($pr['side'] !== null && $pr['side'] !== '') ? (string)$pr['side'] : null,
            'sets' => intval($pr['sets']),
            'reps' => intval($pr['reps']),
        ),
        'sets' => $out,
    );
}
