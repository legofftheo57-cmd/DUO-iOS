#!/usr/bin/env python3
"""Écrit Local.xcconfig avec l'adresse et la clé publique, sans barre oblique inversée.
xcconfig traite // comme un commentaire : on écrit https:/$()/ (la variable vide $() est effacée à la compilation)."""
import subprocess, sys, os
out = subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__), "normaliser-supabase.py")], capture_output=True, text=True)
if out.returncode != 0:
    sys.stderr.write(out.stderr); sys.exit(out.returncode)
lines = (out.stdout.splitlines() + ["", ""])[:2]
url, key = lines[0].strip(), lines[1].strip()
url_x = url.replace("https://", "https:/$()/", 1) if url else ""
open("Local.xcconfig", "w").write(f"SUPABASE_URL = {url_x}\nSUPABASE_PUBLISHABLE_KEY = {key}\n")
print("Mode foyer : Supabase configure" if url else "Mode local : aucun Supabase configure")
