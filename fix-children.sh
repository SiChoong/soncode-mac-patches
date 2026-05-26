#!/usr/bin/env python3
# fix-children.sh — + 버튼 패치 후 인코딩 깨짐 복구 (필요시)
# Usage: python3 fix-children.sh

import sys, os, hashlib, base64, json, subprocess

OUT_FILE = "/tmp/fix-children-result.txt"

# SonCode.app → Void.app 순서로 탐색
_BASE = "/Applications"
for _APP in ("SonCode.app", "Void.app"):
    _CANDIDATE = f"{_BASE}/{_APP}/Contents/Resources/app"
    if os.path.isdir(_CANDIDATE):
        APP_DIR = _CANDIDATE
        break
else:
    APP_DIR = f"{_BASE}/SonCode.app/Contents/Resources/app"

WBJS = f"{APP_DIR}/out/vs/workbench/workbench.desktop.main.js"
PROD = f"{APP_DIR}/product.json"

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
        write_out(f"ERROR: workbench.js not found at {WBJS}")
        sys.exit(1)

    with open(WBJS, "r", encoding="utf-8") as f:
        content = f.read()
    content = content.replace("\r\n", "\n")

    modified = False

    # 인코딩 깨짐 복구 (+ 버튼 children이 깨진 경우)
    broken = 'children: "??\n'
    if broken in content:
        content = content.replace(broken, 'children: "+"\n')
        modified = True

    # 레이블 인코딩 아티팩트 정규화
    label_fixes = [
        ('label: "? File"',    'label: "[F] File"'),
        ('label: "? Folder"',  'label: "[D] Folder"'),
        ('label: "? Image"',   'label: "[I] Image"'),
        ('label: "? Connect"', 'label: "[C] Connect"'),
        ('label: "? Plugin"',  'label: "[P] Plugin"'),
    ]
    for old, new in label_fixes:
        if old in content:
            content = content.replace(old, new)
            modified = True

    if not modified:
        write_out("Not needed (OK) — no encoding issues found")
        sys.exit(0)

    content_bytes = content.encode("utf-8")
    with open(WBJS, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)

    b64 = update_checksum(content_bytes)

    # PlusButtonW19 함수 구문 검사 (node가 있는 경우)
    node_result = "skipped"
    func_start = content.find("function PlusButtonW19")
    if func_start >= 0:
        # 함수 끝 탐색: 다음 최상위 function/var 선언 전까지
        import re
        m = re.search(r'\n(?:function |var )', content[func_start + 20:])
        func_end = func_start + 20 + m.start() if m else func_start + 5000
        fn_code = content[func_start:func_end]
        tmp = "/tmp/plusFunc_check.js"
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(fn_code)
        result = subprocess.run(["node", "--check", tmp],
                                capture_output=True, text=True)
        node_result = "OK" if result.returncode == 0 else result.stderr.strip()

    write_out(f"OK:checksum={b64}\nnodeCheck={node_result}")

except Exception as e:
    write_out(f"ERROR:{e}")
    sys.exit(1)
