#!/usr/bin/env python3
"""
watcher.py — tails nginx access log, detects pool flips and high error rates,
and posts alerts to Slack via incoming webhook.
"""

import os
import time
import re
import json
import collections
import threading
from datetime import datetime, timezone
import requests

# Configuration from env
SLACK_WEBHOOK = os.getenv("SLACK_WEBHOOK_URL")
ERROR_RATE_THRESHOLD = float(os.getenv("ERROR_RATE_THRESHOLD", "2.0"))  # percent
WINDOW_SIZE = int(os.getenv("WINDOW_SIZE", "200"))
ALERT_COOLDOWN_SEC = int(os.getenv("ALERT_COOLDOWN_SEC", "300"))
MAINTENANCE_MODE = os.getenv("MAINTENANCE_MODE", "false").lower() in ("1", "true", "yes")
NGINX_LOG_PATH = os.getenv("NGINX_LOG_PATH", "/var/log/nginx/access.log")

if not SLACK_WEBHOOK:
    print("ERROR: SLACK_WEBHOOK_URL not set. Exiting.")
    raise SystemExit(1)

# Rolling window of recent statuses (True for error (5xx), False for ok)
window = collections.deque(maxlen=WINDOW_SIZE)

# Track last seen pool to detect flips
last_seen_pool = None

# Cooldown trackers
last_alert_time = {"failover": 0, "error_rate": 0}

# Regex to parse log line based on our nginx log_format
# Example line snippet: pool="blue" release="blue-v1" upstream_status="200" upstream_addr="app_blue:3000" req_time=0.012 up_resp_time=0.010
POOL_RE = re.compile(r'pool="(?P<pool>[^"]+)"')
RELEASE_RE = re.compile(r'release="(?P<release>[^"]+)"')
UPSTREAM_STATUS_RE = re.compile(r'upstream_status="(?P<upstat>[^"]+)"')
STATUS_RE = re.compile(r'\s(?P<status>\d{3})\s')  # request status code in main block
UPSTREAM_ADDR_RE = re.compile(r'upstream_addr="(?P<upaddr>[^"]+)"')

def post_slack(text, blocks=None):
    payload = {"text": text}
    if blocks:
        payload["blocks"] = blocks
    try:
        resp = requests.post(SLACK_WEBHOOK, json=payload, timeout=6)
        resp.raise_for_status()
        print(f"[{datetime.now().isoformat()}] Slack alert posted")
    except Exception as e:
        print(f"Failed to send Slack alert: {e}")

def is_error_status(status_str):
    # upstream_status may be "-" if not available; use request status too.
    try:
        s = int(status_str)
        return 500 <= s <= 599
    except Exception:
        return False

def handle_failover(new_pool, release, upaddr):
    global last_alert_time
    if MAINTENANCE_MODE:
        print("Maintenance mode on; suppressing failover alert.")
        return
    now = time.time()
    if now - last_alert_time["failover"] < ALERT_COOLDOWN_SEC:
        print("Failover alert suppressed by cooldown")
        return
    last_alert_time["failover"] = now
    text = f":rotating_light: *Failover detected* — traffic switched to *{new_pool}*\nRelease: `{release}`\nUpstream: `{upaddr}`\nTime: {datetime.now(timezone.utc).isoformat()}"
    post_slack(text)

def handle_error_rate(rate_pct, window_n):
    global last_alert_time
    if MAINTENANCE_MODE:
        print("Maintenance mode on; suppressing error-rate alert.")
        return
    now = time.time()
    if now - last_alert_time["error_rate"] < ALERT_COOLDOWN_SEC:
        print("Error-rate alert suppressed by cooldown")
        return
    last_alert_time["error_rate"] = now
    text = f":warning: *High error rate detected* — {rate_pct:.2f}% 5xx over last {window_n} requests (threshold {ERROR_RATE_THRESHOLD}%)\nTime: {datetime.now(timezone.utc).isoformat()}"
    post_slack(text)

def tail_f(filename):
    # generator that yields lines as they appear
    with open(filename, "r") as fh:
        # Go to end of file
        fh.seek(0, 2)
        while True:
            line = fh.readline()
            if not line:
                time.sleep(0.1)
                continue
            yield line

def process_line(line):
    global last_seen_pool

    pool = None
    release = None
    upstat = None
    status = None
    upaddr = None

    m = POOL_RE.search(line)
    if m:
        pool = m.group("pool")
    m = RELEASE_RE.search(line)
    if m:
        release = m.group("release")
    m = UPSTREAM_STATUS_RE.search(line)
    if m:
        upstat = m.group("upstat")
    m = STATUS_RE.search(line)
    if m:
        status = m.group("status")
    m = UPSTREAM_ADDR_RE.search(line)
    if m:
        upaddr = m.group("upaddr")

    # Determine whether request is a 5xx
    # Prefer upstream_status if available; else fall back to request status
    is_err = False
    if upstat and upstat != "-":
        is_err = is_error_status(upstat)
    elif status:
        is_err = is_error_status(status)

    window.append(bool(is_err))

    # Evaluate error rate threshold
    if len(window) >= WINDOW_SIZE:
        num_errors = sum(window)
        rate = (num_errors / len(window)) * 100.0
        if rate >= ERROR_RATE_THRESHOLD:
            handle_error_rate(rate, len(window))

    # Detect pool flip
    if pool:
        if last_seen_pool is None:
            last_seen_pool = pool
        elif pool != last_seen_pool:
            # pool changed -> failover
            print(f"Pool changed from {last_seen_pool} to {pool}")
            handle_failover(pool, release or "unknown", upaddr or "unknown")
            last_seen_pool = pool

def watcher_main():
    # Ensure log file exists (nginx creates it)
    retries = 0
    while not os.path.exists(NGINX_LOG_PATH) and retries < 600:
        print(f"Waiting for log file {NGINX_LOG_PATH} ...")
        time.sleep(0.5)
        retries += 1
    if not os.path.exists(NGINX_LOG_PATH):
        print("Log file never appeared; exiting.")
        return

    for line in tail_f(NGINX_LOG_PATH):
        try:
            process_line(line)
        except Exception as e:
            print(f"Error processing line: {e}")

if __name__ == "__main__":
    print("Starting alert_watcher...")
    print(f"Config: WINDOW_SIZE={WINDOW_SIZE} ERROR_RATE_THRESHOLD={ERROR_RATE_THRESHOLD} ALERT_COOLDOWN_SEC={ALERT_COOLDOWN_SEC} MAINT={MAINTENANCE_MODE}")
    watcher_main()
