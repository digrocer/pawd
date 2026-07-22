#!/usr/bin/env python3
"""Apply a .sql file to the pawd Supabase project via the Management API.

Requires env vars:
  SUPABASE_ACCESS_TOKEN   personal access token (sbp_...)
  SUPABASE_PROJECT_REF    project ref (default: the pawd project)

Usage:  python scripts/apply_sql.py supabase/migrations/0001_init.sql
"""
import os, sys, json, urllib.request, urllib.error

TOKEN = os.environ.get("SUPABASE_ACCESS_TOKEN")
REF = os.environ.get("SUPABASE_PROJECT_REF", "vaeiskltcpzthaffyejg")
URL = f"https://api.supabase.com/v1/projects/{REF}/database/query"

def run_sql(sql: str):
    if not TOKEN:
        raise SystemExit("Set SUPABASE_ACCESS_TOKEN in the environment first.")
    body = json.dumps({"query": sql}).encode()
    req = urllib.request.Request(URL, data=body, method="POST", headers={
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json",
        "User-Agent": "curl/8.0",
    })
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()

if __name__ == "__main__":
    path = sys.argv[1]
    with open(path, "r", encoding="utf-8") as f:
        sql = f.read()
    status, out = run_sql(sql)
    print(f"[{status}] {path}")
    print(out[:2000])
    sys.exit(0 if status < 400 else 1)
