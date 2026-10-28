#!/usr/bin/env python3
"""End-to-end test of the notification system against the running backend (WAMP: http://localhost/reed/) and its
database. Creates throw-away accounts (two physiotherapists, two patients), triggers every notification through the
real endpoints, checks recipients / de-duplication / access rules / the daily inactivity job, then deletes everything
it created.

    python tool/test_notifications.py
"""
import json
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta
from pathlib import Path

BASE = 'http://localhost/reed/'
MYSQL = r'C:\wamp64\bin\mysql\mysql8.4.7\bin\mysql.exe'
PHP = sorted(Path(r'C:\wamp64\bin\php').glob('php8.3*/php.exe'))[-1]
REED = Path(__file__).resolve().parents[1] / 'reed'
PASSWORD = 'Test@12345'
TAG = 'kinex-notif-test'
failures = []


def sql(q):
    r = subprocess.run([MYSQL, '-uroot', '--host=127.0.0.1', '--port=3306', '-N', '-B', 'physio_clinic', '-e', q],
                       capture_output=True, text=True, encoding='utf8')
    if r.returncode != 0:
        raise RuntimeError(r.stderr)
    return [line.split('\t') for line in r.stdout.strip().splitlines() if line]


def http(path, data=None, token=None, method=None):
    url = BASE + path
    body = None
    if data is not None and method != 'GET':
        body = urllib.parse.urlencode(data).encode()
    elif data is not None:
        url += ('&' if '?' in url else '?') + urllib.parse.urlencode(data)
    req = urllib.request.Request(url, data=body, method=method or ('POST' if body else 'GET'))
    if token:
        req.add_header('X-Auth-Token', token)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status, json.loads(r.read().decode('utf8'))
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode('utf8') or '{}')


def check(name, cond, detail=''):
    print(('PASS ' if cond else 'FAIL ') + name + ('' if cond else f'   <- {detail}'))
    if not cond:
        failures.append(name)


def notifs(token, **kw):
    st, r = http('notifications_api.php', {'action': 'list', 'limit': 50, **kw}, token, 'GET')
    return r.get('items', []) if st == 200 else []


def setup():
    h = subprocess.run([str(PHP), '-r', f'echo password_hash("{PASSWORD}", PASSWORD_DEFAULT);'],
                       capture_output=True, text=True).stdout.strip()
    ids = {}
    for key, role in [('t1', 'therapist'), ('t2', 'therapist'), ('p1', 'patient'), ('p2', 'patient')]:
        email = f'{TAG}-{key}@example.com'
        sql(f"INSERT INTO account (email, password_hash, role, is_active, Photo) VALUES ('{email}', '{h}', '{role}', 1, '')")
        ids[key] = int(sql(f"SELECT id FROM account WHERE email = '{email}'")[0][0])
    clinic = int(sql('SELECT id FROM clinic ORDER BY id LIMIT 1')[0][0])
    for key in ('t1', 't2'):
        sql(f"INSERT INTO physiotherapist (account_id, clinic_id, name) VALUES ({ids[key]}, {clinic}, 'Test Physio {key}')")
        ids[key + '_id'] = int(sql(f'SELECT id FROM physiotherapist WHERE account_id = {ids[key]}')[0][0])
    for key, t in (('p1', 't1'), ('p2', 't2')):
        sql(f"INSERT INTO patient (account_id, clinic_id, therapist_id, name) VALUES ({ids[key]}, {clinic}, {ids[t + '_id']}, 'Test Patient {key}')")
        ids[key + '_id'] = int(sql(f'SELECT id FROM patient WHERE account_id = {ids[key]}')[0][0])
    ids['exercise'] = int(sql('SELECT id FROM exercise ORDER BY id LIMIT 1')[0][0])
    return ids


def cleanup():
    accs = [r[0] for r in sql(f"SELECT id FROM account WHERE email LIKE '{TAG}-%'")]
    if not accs:
        return
    a = ','.join(accs)
    pats = [r[0] for r in sql(f'SELECT id FROM patient WHERE account_id IN ({a})')] or ['0']
    p = ','.join(pats)
    pes = [r[0] for r in sql(f'SELECT id FROM patientexercise WHERE patient_id IN ({p})')] or ['0']
    pe = ','.join(pes)
    for q in [
        f'DELETE FROM notification WHERE recipient_account_id IN ({a}) OR related_account_id IN ({a})',
        f'DELETE FROM auth_token WHERE account_id IN ({a})',
        f'DELETE FROM notification_pref WHERE account_id IN ({a})',
        f'DELETE FROM message WHERE sender_id IN ({a}) OR receiver_id IN ({a})',
        f'DELETE FROM live_set WHERE patient_id IN ({p})',
        f'DELETE FROM aifeedback WHERE progressreport_id IN (SELECT id FROM progressreport WHERE ppid IN ({pe}))',
        f'DELETE FROM progressreport WHERE ppid IN ({pe})',
        f'DELETE FROM patientexercise WHERE id IN ({pe})',
        f'DELETE FROM patient WHERE id IN ({p})',
        f'DELETE FROM physiotherapist WHERE account_id IN ({a})',
        f'DELETE FROM account WHERE id IN ({a})',
    ]:
        sql(q)


def main():
    cleanup()
    http('notifications_api.php', {'action': 'count'}, None, 'GET')  # creates the tables if needed
    ids = setup()
    try:
        run(ids)
    finally:
        cleanup()
        left = sql(f"SELECT COUNT(*) FROM account WHERE email LIKE '{TAG}-%'")[0][0]
        print(f'cleanup: {left} test accounts left')
    print(f'\n{len(failures)} failure(s)' + (': ' + ', '.join(failures) if failures else ''))
    sys.exit(1 if failures else 0)


def run(ids):
    tok = {}
    for key in ('t1', 't2', 'p1', 'p2'):
        st, r = http('login.php', {'email': f'{TAG}-{key}@example.com', 'password': PASSWORD})
        tok[key] = r.get('token')
    check('login returns a token for every account', all(tok.values()), tok)

    # ---- access
    st, _ = http('notifications_api.php', {'action': 'list'}, None, 'GET')
    check('no token -> 401', st == 401, st)
    st, _ = http('notifications_api.php', {'action': 'list'}, '0' * 64, 'GET')
    check('unknown token -> 401', st == 401, st)

    # ---- B. messages
    st, r = http('send_patient_message.php', {'account_id': ids['p1'], 'content': 'Hello, my shoulder feels\nstiff today. ' + 'x' * 120})
    check('patient message sent', r.get('error') is False, r)
    t1 = notifs(tok['t1'], category='messages')
    check('physio gets one message notification', len(t1) == 1, t1)
    if t1:
        d = t1[0]['data']
        check('message notification: sender name + short one-line preview',
              d.get('sender_name') == 'Test Patient p1' and len(d.get('preview', '')) <= 80 and '\n' not in d['preview'], d)
        check('message notification: sender account kept for the conversation', d.get('sender_account_id') == ids['p1'], d)
    check('the sender gets no notification about their own message', len(notifs(tok['p1'], category='messages')) == 0)
    http('send_physio_message.php', {'account_id': ids['t1'], 'patient_account_id': ids['p1'], 'content': 'How are you?'})
    check('patient gets the reply notification', len(notifs(tok['p1'], category='messages')) == 1)
    # opening the conversation reads its message notifications
    http(f"get_physio_messages.php?account_id={ids['t1']}&patient_account_id={ids['p1']}", None, None, 'GET')
    check('opening the conversation marks its message notifications read',
          all(n['read'] for n in notifs(tok['t1'], category='messages')))
    # de-duplication of the same message processed twice
    mid = sql(f"SELECT MAX(id) FROM message WHERE sender_id = {ids['p1']}")[0][0]
    dup = subprocess.run([str(PHP), '-r', f"chdir('{REED.as_posix()}'); require 'notifications_lib.php'; notif_init($conn);"
                          f" echo notify_message($conn, {mid}, {ids['p1']}, {ids['t1']}, 'again');"],
                         capture_output=True, text=True).stdout.strip()
    check('the same message processed twice -> no second notification', dup == '0' and len(notifs(tok['t1'], category='messages')) == 1, dup)

    # ---- C. routine update
    st, r = http('assign_patient_exercise.php', {'account_id': ids['t1'], 'patient_id': ids['p1_id'], 'exercise_id': ids['exercise'],
                                                 'sets': 5, 'reps': 20, 'ai_exercise': 'e2', 'side': 'left'})
    ppid = r.get('patient_exercise_id')
    p1r = notifs(tok['p1'], category='routine')
    check('patient gets a routine-update notification with the assignment id', len(p1r) == 1 and p1r[0]['data'].get('ppid') == ppid, p1r)
    if p1r:
        st, c = http('notifications_api.php', {'action': 'context', 'id': p1r[0]['id']}, tok['p1'], 'GET')
        check('routine context: the exercise is available to open', st == 200 and c.get('available') is True and c.get('ppid') == ppid, c)

    # ---- E. incorrect repetitions
    def live_set(uid, good, mistakes, unsure=0, pain_events=None):
        return http('submit_live_session.php', {'account_id': ids['p1'], 'patient_exercise_id': ppid, 'set_uid': uid,
                                                'reps_done': good + mistakes + unsure, 'good': good, 'mistakes': mistakes,
                                                'unsure': unsure, 'notes': 'test set', 'analysis': 'Rep 1: test', 'score': 10,
                                                'pain_events': json.dumps(pain_events or [])})
    st, r1 = live_set('set-a', 1, 9)
    inc = notifs(tok['t1'], category='progress')
    check('9 of 10 judged reps incorrect -> one alert to the physio', len(inc) == 1 and inc[0]['type'] == 'incorrect_reps', inc)
    if inc:
        d = inc[0]['data']
        check('incorrect alert: patient, exercise, counts, set id', d.get('mistakes') == 9 and d.get('judged') == 10
              and d.get('live_set_id') and d.get('patient_id') == ids['p1_id'], d)
        st, c = http('notifications_api.php', {'action': 'context', 'id': inc[0]['id']}, tok['t1'], 'GET')
        check('incorrect context: the set with its numbers', st == 200 and c.get('set', {}).get('mistakes') == 9, c)
    st, r2 = live_set('set-a', 1, 9)
    check('the same set sent again -> recognised, nothing added', r2.get('duplicate') is True, r2)
    reps = sql(f"SELECT SUM(reps_done) FROM progressreport WHERE ppid = {ppid}")[0][0]
    check('...and the reps are not counted twice', reps == '10', reps)
    check('...and no second alert', len(notifs(tok['t1'], category='progress')) == 1)
    live_set('set-b', 1, 7)          # 8 judged, 87.5 % -> below 90 %
    live_set('set-c', 0, 6, unsure=6)  # 6 judged (unsure reps are not counted) -> too few
    check('87.5 % incorrect, or too few judged reps (unsure ones excluded) -> no alert',
          len([n for n in notifs(tok['t1'], category='progress') if n['type'] == 'incorrect_reps']) == 1)

    # ---- F. pain
    st, r = live_set('set-pain', 3, 1, pain_events=[{'time': '0:42', 'source': 'voice', 'utterance': 'it hurts'}])
    pain = notifs(tok['t1'], category='pain')
    check('pain reported during a set -> urgent alert to the physio', len(pain) == 1 and pain[0]['priority'] == 2, pain)
    check('the patient is not notified about their own pain report', len(notifs(tok['p1'], category='pain')) == 0)
    http('submit_live_session.php', {'account_id': ids['p1'], 'progress_id': r.get('progress_id'), 'pain_level': 7, 'set_uid': 'set-pain'})
    pain = notifs(tok['t1'], category='pain')
    check('the rating given after the set is added to the same alert', len(pain) == 1 and pain[0]['data'].get('pain_level') == 7, pain)
    if pain:
        st, c = http('notifications_api.php', {'action': 'context', 'id': pain[0]['id']}, tok['t1'], 'GET')
        ev = c.get('set', {}).get('events', [])
        check('pain context: the patient\'s own report (time, source, words)', st == 200 and ev and ev[0].get('utterance') == 'it hurts', c)
    st, r = http('submit_progress_report.php', {'account_id': ids['p1'], 'patient_exercise_id': ppid, 'reps_done': 3, 'pain_level': 2})
    check('a low pain rating (2/10) -> no alert', len(notifs(tok['t1'], category='pain')) == 1)
    st, r = http('submit_progress_report.php', {'account_id': ids['p1'], 'patient_exercise_id': ppid, 'reps_done': 3, 'pain_level': 6})
    check('a pain rating of 6/10 in the progress report -> alert', len(notifs(tok['t1'], category='pain')) == 2)

    # ---- D. inactivity (the daily job)
    today = sql('SELECT CURDATE()')[0][0]
    yday = (datetime.strptime(today, '%Y-%m-%d') - timedelta(days=1)).strftime('%Y-%m-%d')
    old = (datetime.strptime(today, '%Y-%m-%d') - timedelta(days=5)).strftime('%Y-%m-%d')
    sql(f"UPDATE patientexercise SET assigned_date = '{old}' WHERE id = {ppid}")
    sql(f"INSERT INTO patientexercise (patient_id, exercise_id, assigned_by, assigned_date, status, Sets, Reps) "
        f"VALUES ({ids['p2_id']}, {ids['exercise']}, {ids['t2_id']}, '{today}', 'Pending', 1, 10)")  # given today: not due yesterday
    def job(day, patient='p1', *extra):  # limited to a test patient: real accounts are never touched
        return subprocess.run([str(PHP), str(REED / 'cron' / 'run_notification_jobs.php'), f'--date={day}',
                               f'--patient={ids[patient + "_id"]}', *extra], capture_output=True, text=True).stdout.strip()
    out = job(yday)
    job(yday, 'p2')
    ina = [n for n in notifs(tok['t1'], category='progress') if n['type'] == 'inactivity']
    check('patient with exercises due and nothing done yesterday -> physio told', len(ina) == 1 and ina[0]['data'].get('date') == yday, (out, ina))
    job(yday)
    check('the job run twice for the same day -> no duplicate',
          len([n for n in notifs(tok['t1'], category='progress') if n['type'] == 'inactivity']) == 1)
    check('a patient whose only exercise was given that day is not flagged',
          len([n for n in notifs(tok['t2'], category='progress') if n['type'] == 'inactivity']) == 0)
    # an exercise finished only today was still due yesterday; one finished three days ago was not
    sql(f"INSERT INTO patientexercise (patient_id, exercise_id, assigned_by, assigned_date, status, Sets, Reps) "
        f"VALUES ({ids['p2_id']}, {ids['exercise']}, {ids['t2_id']}, '{old}', 'Completed', 1, 5)")
    done_pe = sql(f"SELECT MAX(id) FROM patientexercise WHERE patient_id = {ids['p2_id']}")[0][0]
    sql(f"INSERT INTO progressreport (ppid, reps_done, notes, date) VALUES ({done_pe}, 5, 'test', NOW())")
    job(yday, 'p2')
    check('exercise completed only today -> it was due yesterday -> physio told',
          len([n for n in notifs(tok['t2'], category='progress') if n['type'] == 'inactivity']) == 1)
    sql(f"DELETE FROM notification WHERE recipient_account_id = {ids['t2']} AND type = 'inactivity'")
    sql(f"UPDATE progressreport SET date = DATE_SUB(NOW(), INTERVAL 3 DAY) WHERE ppid = {done_pe}")
    job(yday, 'p2')
    check('exercise completed three days ago -> nothing was due yesterday -> no alert',
          len([n for n in notifs(tok['t2'], category='progress') if n['type'] == 'inactivity']) == 0)
    if ina:
        st, c = http('notifications_api.php', {'action': 'context', 'id': ina[0]['id']}, tok['t1'], 'GET')
        check('inactivity context: the day, what was prescribed, what was done', st == 200 and c.get('date') == yday
              and len(c.get('prescribed', [])) >= 1 and c.get('done_that_day') == [], c)
    check('a day that is not over is not checked without --force', 'not over' in job(today))
    # today: progress already recorded today (the sets above) -> not flagged
    job(today, 'p1', '--force')
    check('progress recorded today -> no inactivity alert for today',
          len([n for n in notifs(tok['t1'], category='progress') if n['type'] == 'inactivity' and n['data'].get('date') == today]) == 0)
    # resolution: the patient exercises again -> the open alert (yesterday) is resolved, the missed day stays listed
    check('the alert is open until the patient exercises again', ina and ina[0]['resolved'] is False, ina)
    live_set('set-later', 5, 0)
    res = [n for n in notifs(tok['t1'], category='progress') if n['type'] == 'inactivity']
    check('patient exercises again -> the inactivity alert is marked resolved', len(res) == 1 and res[0]['resolved'] is True, res)

    # ---- notification settings
    st, pr = http('notifications_api.php', {'action': 'prefs'}, tok['t1'], 'GET')
    check('physio settings: 4 types, all on by default', st == 200 and pr.get('prefs') ==
          {'pain_report': True, 'incorrect_reps': True, 'inactivity': True, 'message': True}, pr)
    st, pr = http('notifications_api.php', {'action': 'set_pref', 'type': 'message', 'enabled': '0'}, tok['t1'])
    check('physio turns message notifications off', st == 200 and pr['prefs']['message'] is False, pr)
    before = len(notifs(tok['t1'], category='messages'))
    http('send_patient_message.php', {'account_id': ids['p1'], 'content': 'while off'})
    check('...a new message creates no notification', len(notifs(tok['t1'], category='messages')) == before)
    http('notifications_api.php', {'action': 'set_pref', 'type': 'message', 'enabled': '1'}, tok['t1'])
    http('send_patient_message.php', {'account_id': ids['p1'], 'content': 'back on'})
    check('...turned on again: the next message notifies', len(notifs(tok['t1'], category='messages')) == before + 1)
    st, _ = http('notifications_api.php', {'action': 'set_pref', 'type': 'pain_report', 'enabled': '0'}, tok['p1'])
    check('a patient cannot change a physiotherapist-only type', st == 400, st)
    st, pr = http('notifications_api.php', {'action': 'prefs'}, tok['t2'], 'GET')
    check("one physio's settings do not change another's", pr.get('prefs', {}).get('message') is True, pr)

    # ---- access rules
    any_t1 = notifs(tok['t1'])[0]
    st, _ = http('notifications_api.php', {'action': 'read', 'id': any_t1['id']}, tok['t2'])
    check("another physio cannot mark someone else's notification", st == 404, st)
    st, _ = http('notifications_api.php', {'action': 'context', 'id': any_t1['id']}, tok['t2'], 'GET')
    check("another physio cannot open someone else's notification", st == 404, st)
    st, _ = http('notifications_api.php', {'action': 'context', 'id': any_t1['id']}, tok['p1'], 'GET')
    check("a patient cannot open the physio's notification", st == 404, st)
    check('every list only contains the caller\'s notifications',
          {n['id'] for n in notifs(tok['t2'])}.isdisjoint({n['id'] for n in notifs(tok['t1'])}))
    sql(f"UPDATE patient SET therapist_id = {ids['t2_id']} WHERE id = {ids['p1_id']}")
    st, c = http('notifications_api.php', {'action': 'context', 'id': inc[0]['id']}, tok['t1'], 'GET')
    check('patient moved to another physio -> old notification no longer opens patient data', st == 403, (st, c))
    sql(f"UPDATE patient SET therapist_id = {ids['t1_id']} WHERE id = {ids['p1_id']}")

    # ---- read states
    st, c0 = http('notifications_api.php', {'action': 'count'}, tok['t1'], 'GET')
    unread = c0.get('unread', 0)
    first_unread = next((n for n in notifs(tok['t1']) if not n['read']), None)
    st, c1 = http('notifications_api.php', {'action': 'read', 'id': first_unread['id']}, tok['t1'])
    check('mark one as read -> unread count goes down by one', c1.get('unread') == unread - 1, (unread, c1))
    st, c2 = http('notifications_api.php', {'action': 'read_all', 'category': 'pain'}, tok['t1'])
    check('mark all of a category as read', c2.get('unread_by_category', {}).get('pain') == 0, c2)
    st, c3 = http('notifications_api.php', {'action': 'read_all'}, tok['t1'])
    check('mark all as read', c3.get('unread') == 0, c3)
    st, pg = http('notifications_api.php', {'action': 'list', 'limit': 2, 'page': 1}, tok['t1'], 'GET')
    check('pagination: 2 per page and a next page', len(pg.get('items', [])) == 2 and pg.get('has_more') is True, pg)

    # ---- time
    created = notifs(tok['t1'])[0]['created_at']
    now = sql('SELECT NOW()')[0][0]
    delta = abs((datetime.strptime(created, '%Y-%m-%d %H:%M:%S') - datetime.strptime(now, '%Y-%m-%d %H:%M:%S')).total_seconds())
    check(f'timestamps in the clinic time zone (created {created}, database now {now})', delta < 120, delta)


if __name__ == '__main__':
    main()
