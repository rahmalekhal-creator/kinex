<?php
/**
 * Daily notification job (command line only, run by the system scheduler - not by the app):
 *   php reed/cron/run_notification_jobs.php                  checks yesterday (the default daily run, e.g. 00:15)
 *   php reed/cron/run_notification_jobs.php --date=2026-10-12 [--patient=ID] [--force]
 * A day is only checked once it is over (--force checks a day in progress; --patient limits the check to one patient,
 * for tests).
 *
 * D. Inactivity: a physiotherapist is told when one of their patients, who had exercises to do that day, recorded
 * no progress at all. Running it twice for the same day creates nothing new.
 * Windows: tool\register_notification_task.ps1 creates the scheduled task. Linux: 15 0 * * * php .../run_notification_jobs.php
 */
if (PHP_SAPI !== 'cli') {
    http_response_code(403);
    exit('command line only');
}
chdir(__DIR__ . '/..');
require_once __DIR__ . '/../notifications_lib.php';

notif_init($conn);
$day = null;
$patient = 0;
$force = false;
foreach ($argv as $arg) {
    if (preg_match('/^--date=(\d{4}-\d{2}-\d{2})$/', $arg, $m)) {
        $day = $m[1];
    } elseif (preg_match('/^--patient=(\d+)$/', $arg, $m)) {
        $patient = intval($m[1]);
    } elseif ($arg === '--force') {
        $force = true;
    }
}
$today = (new DateTime('today', kinex_timezone()))->format('Y-m-d');
if ($day === null) {
    $day = (new DateTime('yesterday', kinex_timezone()))->format('Y-m-d');
}
if ($day >= $today && !$force) {
    echo date('c') . " $day is not over yet: nothing checked (use --force)\n";
    exit(0);
}
$n = check_inactivity($conn, $day, $patient);
echo date('c') . " inactivity check for $day" . ($patient ? " (patient $patient)" : '') . ": $n new notification(s)\n";
