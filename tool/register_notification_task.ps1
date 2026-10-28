# Registers the daily notification job (inactivity check) with the Windows Task Scheduler, for the current user.
# Run once:  powershell -ExecutionPolicy Bypass -File D:\startup\kinex\Kinex\tool\register_notification_task.ps1
# Remove:    schtasks /Delete /TN KinexNotificationJobs /F
param([string]$Time = '00:15')
$php = Get-ChildItem 'C:\wamp64\bin\php' -Directory | Sort-Object Name -Descending |
    ForEach-Object { Join-Path $_.FullName 'php.exe' } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $php) { Write-Host 'PHP not found under C:\wamp64\bin\php'; exit 1 }
$script = 'D:\startup\kinex\Kinex\reed\cron\run_notification_jobs.php'
$log = 'D:\startup\kinex\Kinex\reed\cron\notification_jobs.log'
$cmd = "cmd /c `"`"$php`" `"$script`" >> `"$log`" 2>&1`""
schtasks /Create /F /SC DAILY /ST $Time /TN KinexNotificationJobs /TR $cmd
schtasks /Query /TN KinexNotificationJobs /FO LIST | Select-String 'TaskName|Next Run Time|Status'
