#!/usr/bin/env python3
# fix-children.sh — Mac equivalent of fix-children.ps1
# Usage: python3 fix-children.sh

import sys, os, hashlib, base64, json, re, subprocess

OUT_FILE = "/tmp/fix-children-result.txt"
WBJS     = "/Applications/SonCode.app/Contents/Resources/app/out/vs/workbench/workbench.desktop.main.js"
PROD     = "/Applications/SonCode.app/Contents/Resources/app/product.json"

def write_out(msg):
    with open(OUT_FILE, "w", encoding="ascii", errors="replace") as f:
        f.write(msg + "\n")
    print(msg)

def update_checksum(content_bytes):
    digest = hashlib.sha256(content_bytes).digest()
    b64 = base64.b64encode(digest).rstrip(b"=").decode()
    with open(PROD, "r", encoding="utf-8") as f:
        prod = f.read()
    data = json.loads(prod)
    old_cs = data.get("checksums", {}).get("vs/workbench/workbench.desktop.main.js", "")
    if old_cs:
        prod = prod.replace(old_cs, b64)
        with open(PROD, "w", encoding="utf-8") as f:
            f.write(prod)
    return b64

try:
    if not os.path.exists(WBJS):
        write_out(f"ERROR: SonCode not found at {WBJS}")
        sys.exit(1)

    with open(WBJS, "r", encoding="utf-8") as f:
        content = f.read()

    # Normalize CRLF -> LF
    content = content.replace("\r\n", "\n")

    # Fix broken children encoding (encoding artifacts)
    broken = 'children: "??\n'
    fixed  = 'children: "+"\n'
    if broken not in content:
        write_out("ERROR: broken pattern not found (already fixed or different encoding)")
        sys.exit(1)
    content = content.replace(broken, fixed)

    # Normalize any remaining label encoding artifacts
    content = content.replace('label: "? File"',    'label: "[F] File"')
    content = content.replace('label: "? Folder"',  'label: "[D] Folder"')
    content = content.replace('label: "? Image"',   'label: "[I] Image"')
    content = content.replace('label: "? Connect"', 'label: "[C] Connect"')
    content = content.replace('label: "? Plugin"',  'label: "[P] Plugin"')

    content_bytes = content.encode("utf-8")
    with open(WBJS, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)

    b64 = update_checksum(content_bytes)

    # Syntax-check the PlusButtonW19 function with node
    idx = content.find("function PlusButtonW19")
    end_idx = content.find("var VoidChatArea2", idx) if idx >= 0 else -1
    node_exit = "skipped"
    node_out = ""
    if idx >= 0 and end_idx > idx:
        fn_code = content[idx:end_idx]
        tmp = "/tmp/plusFunc_check.js"
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(fn_code)
        result = subprocess.run(["node", "--check", tmp], capture_output=True, text=True)
        node_exit = result.returncode
        node_out = result.stdout + result.stderr

    write_out(f"OK:checksum={b64}\nnodeExit={node_exit}\nnodeOut={node_out}")

except Exception as e:
    write_out(f"ERROR:{e}")
    sys.exit(1)
