#!/usr/bin/env python3
# patch-toggle3.sh — UI 언어 토글 패치 (Void 1.4.x)
# Usage: python3 patch-toggle3.sh

import sys, os, hashlib, base64, json

OUT_FILE = "/tmp/patch-result.txt"

# SonCode.app → Void.app 순서로 탐색
_BASE = "/Applications"
for _APP in ("SonCode.app", "Void.app"):
    _CANDIDATE = f"{_BASE}/{_APP}/Contents/Resources/app"
    if os.path.isdir(_CANDIDATE):
        APP_DIR = _CANDIDATE
        break
else:
    APP_DIR = f"{_BASE}/SonCode.app/Contents/Resources/app"  # 에러 메시지용

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

    if "korean-ag.toggleUiLocale" in content:
        write_out("Already patched")
        sys.exit(0)

    # ── Void 1.4.x 패치 ──────────────────────────────────────────
    # ce = Action2 base, Pde = ILocaleService token,
    # CO.value() = current locale, F.CommandPalette = menu id
    toggle_cls = (
        ',KoreanAgToggle1494=class extends ce{'
        'static{this.ID="korean-ag.toggleUiLocale"}'
        'constructor(){'
        'super({id:KoreanAgToggle1494.ID,'
        'title:{value:"SonCode: Toggle UI Language",'
        'original:"SonCode: Toggle UI Language"},'
        'menu:{id:F.CommandPalette}})}'
        'async run(e){'
        'const s=e.get(Pde),isKo=CO.value().startsWith("ko");'
        'await s.setLocale({id:isKo?"en":"ko",'
        'label:isKo?"English":"\\ud55c\\uad6d\\uc5b4"})}}'
    )
    anchor_old = (
        'async run(e){await e.get(Pde).clearLocalePreference()}},'
        'zzs=class extends z{constructor(){super(),X(Wzs),X(Uzs),'
    )
    anchor_new = (
        'async run(e){await e.get(Pde).clearLocalePreference()}}'
        + toggle_cls
        + ',zzs=class extends z{constructor(){super(),X(Wzs),X(Uzs),X(KoreanAgToggle1494),'
    )

    if anchor_old not in content:
        write_out("ERROR: search string not found (version mismatch?)")
        sys.exit(1)

    content = content.replace(anchor_old, anchor_new, 1)

    content_bytes = content.encode("utf-8")
    with open(WBJS, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)

    b64 = update_checksum(content_bytes)
    write_out(f"OK:{b64}")

except Exception as e:
    write_out(f"ERROR:{e}")
    sys.exit(1)
