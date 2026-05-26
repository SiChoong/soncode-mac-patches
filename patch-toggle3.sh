#!/usr/bin/env python3
# patch-toggle3.sh — Mac equivalent of patch-toggle3.ps1
# Usage: python3 patch-toggle3.sh

import sys, os, hashlib, base64, json

OUT_FILE = "/tmp/patch-result.txt"
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

    # Normalize CRLF -> LF (Mac build uses LF)
    content = content.replace("\r\n", "\n")

    if "korean-ag.toggleUiLocale" in content:
        write_out("Already patched")
        sys.exit(0)

    new_code = (
        "// [SonCode W19] UI Language Toggle\n"
        "var KoreanAgToggleLocaleAction = class extends Action2 {\n"
        "  constructor() {\n"
        '    super({ id: "korean-ag.toggleUiLocale", title: { value: "SonCode: Toggle UI Language", original: "SonCode: Toggle UI Language" }, menu: { id: MenuId.CommandPalette } });\n'
        "  }\n"
        "  async run(accessor) {\n"
        "    const localeService = accessor.get(ILocaleService);\n"
        '    const isKorean = (globalThis._VSCODE_NLS_LANGUAGE || "en").startsWith("ko");\n'
        '    await localeService.setLocale({ id: isKorean ? "en" : "ko", label: isKorean ? "English" : "\\ud55c\\uad6d\\uc5b4" });\n'
        "  }\n"
        "};\n\n"
    )

    search_str = "\n// out-build/vs/workbench/contrib/localization/common/localization.contribution.js"

    if search_str not in content:
        write_out("ERROR: search string not found")
        sys.exit(1)

    content = content.replace(search_str, new_code + search_str, 1)

    old_reg = "    registerAction2(ClearDisplayLanguageAction);"
    new_reg = (
        "    registerAction2(ClearDisplayLanguageAction);\n"
        "    registerAction2(KoreanAgToggleLocaleAction);"
    )
    if old_reg not in content:
        write_out("ERROR: registerAction2 anchor not found")
        sys.exit(1)
    content = content.replace(old_reg, new_reg, 1)

    content_bytes = content.encode("utf-8")
    with open(WBJS, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)

    b64 = update_checksum(content_bytes)
    write_out(f"OK:{b64}")

except Exception as e:
    write_out(f"ERROR:{e}")
    sys.exit(1)
