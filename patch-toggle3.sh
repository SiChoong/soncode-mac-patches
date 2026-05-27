#!/usr/bin/env python3
# patch-toggle3.sh — UI 언어 토글 패치 (Void 1.0.2)
# Usage: python3 patch-toggle3.sh

import sys, os, hashlib, base64, json

OUT_FILE = "/tmp/patch-result.txt"

# SonCode.app → Void.app, /Applications → ~/Applications 순서로 탐색
import pathlib
_HOME = str(pathlib.Path.home())
_CANDIDATES = [
    f"/Applications/SonCode.app/Contents/Resources/app",
    f"{_HOME}/Applications/SonCode.app/Contents/Resources/app",
    f"{_HOME}/Applications/Void.app/Contents/Resources/app",
    f"/Applications/Void.app/Contents/Resources/app",
]
for _CANDIDATE in _CANDIDATES:
    if os.path.isdir(_CANDIDATE):
        APP_DIR = _CANDIDATE
        break
else:
    APP_DIR = f"/Applications/SonCode.app/Contents/Resources/app"  # 에러 메시지용

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

    # ── Void 1.0.2 패치 ──────────────────────────────────────────
    # ne = Action2 base, Eae = ILocaleService token,
    # dT.value() = current locale, P.CommandPalette = menu id
    # U = registerAction2, JLn = locale contribution class
    toggle_cls = (
        ',KoreanAgToggle102=class extends ne{'
        'static{this.ID="korean-ag.toggleUiLocale"}'
        'constructor(){'
        'super({id:KoreanAgToggle102.ID,'
        'title:{value:"SonCode: Toggle UI Language",'
        'original:"SonCode: Toggle UI Language"},'
        'menu:{id:P.CommandPalette}})}'
        'async run(e){'
        'const s=e.get(Eae),isKo=dT.value().startsWith("ko");'
        'await s.setLocale({id:isKo?"en":"ko",'
        'label:isKo?"English":"\\ud55c\\uad6d\\uc5b4"})}}'
    )
    anchor_old = (
        'async run(e){await e.get(Eae).clearLocalePreference()}}'
        ',JLn=class extends V{constructor(){super(),U(YLn),U(XLn),'
    )
    anchor_new = (
        'async run(e){await e.get(Eae).clearLocalePreference()}}'
        + toggle_cls
        + ',JLn=class extends V{constructor(){super(),U(YLn),U(XLn),U(KoreanAgToggle102),'
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
