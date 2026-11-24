#!/usr/bin/env python3
"""Normalise l'adresse Supabase et refuse toute clé secrète.
Usage : python3 normaliser-supabase.py  (lit SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY, écrit URL et clé propres sur 2 lignes)."""
import os, re, sys, json, base64
u = re.sub(r"\s+", "", os.environ.get("SUPABASE_URL", ""))
k = re.sub(r"\s+", "", os.environ.get("SUPABASE_PUBLISHABLE_KEY", ""))
if not u:
    print(""); print(""); sys.exit(0)
ref = None
m = re.search(r"([a-z0-9]{15,30})\.supabase\.co", u)
if m: ref = m.group(1)
m2 = re.search(r"supabase\.com/dashboard/project/([a-z0-9]{15,30})", u)
if not ref and m2: ref = m2.group(1)
if not ref and re.fullmatch(r"[a-z0-9]{15,30}", u): ref = u
if not ref:
    print("::error::SUPABASE_URL ne ressemble pas a une adresse de projet Supabase (https://xxxx.supabase.co).", file=sys.stderr); sys.exit(2)
if k.startswith("sb_secret_"):
    print("::error::La cle fournie est la cle SECRETE (sb_secret_). Mettre la cle publishable (sb_publishable_) dans SUPABASE_PUBLISHABLE_KEY.", file=sys.stderr); sys.exit(3)
if k.count(".") == 2:
    try:
        part = k.split(".")[1]; part += "=" * (-len(part) % 4)
        if json.loads(base64.urlsafe_b64decode(part)).get("role") == "service_role":
            print("::error::La cle fournie est service_role (secrete). Mettre la cle anon/publishable.", file=sys.stderr); sys.exit(3)
    except Exception: pass
print(f"https://{ref}.supabase.co"); print(k)
