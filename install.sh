#!/usr/bin/env bash
# SonCode Mac 설치 스크립트
# 사용법: bash install.sh
# 또는 (원라이너):
#   curl -fsSL https://raw.githubusercontent.com/SiChoong/soncode-mac-patches/main/install.sh | bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
APP_NAME="SonCode"
VOID_APP="/Applications/Void.app"
SONCODE_APP="/Applications/SonCode.app"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

install_void() {
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        ARCH_KEY="arm64"
    else
        ARCH_KEY="x64"
    fi

    info "Void 최신 버전을 GitHub에서 다운로드합니다... (arch: $ARCH_KEY)"

    # releases 목록 전체를 순회 → DMG 파일이 있는 가장 최신 릴리스 탐색
    # (latest API는 빈 릴리스를 가리킬 수 있으므로 전체 목록 사용)
    RELEASES_URL="https://api.github.com/repos/voideditor/void/releases"
    DOWNLOAD_URL=$(curl -fsSL "$RELEASES_URL" 2>/dev/null \
        | python3 -c "
import sys, json
try:
    rels = json.load(sys.stdin)
    arch = '$ARCH_KEY'
    for rel in rels:
        for a in rel.get('assets', []):
            name = a['name'].lower()
            if name.endswith('.dmg') and arch in name and 'darwin' in name:
                print(a['browser_download_url']); sys.exit(0)
except Exception:
    pass
" 2>/dev/null || true)

    if [ -z "$DOWNLOAD_URL" ]; then
        echo ""
        warn "Void 자동 다운로드 실패. 수동으로 설치해 주세요:"
        echo ""
        echo "  ┌─────────────────────────────────────────────────────┐"
        echo "  │  1. https://voideditor.com 에서 Mac 버전 다운로드   │"
        echo "  │  2. DMG 열어서 Void.app을 /Applications 에 복사     │"
        echo "  │  3. 아래 명령으로 패치만 적용:                       │"
        echo "  │     bash apply-all.sh                               │"
        echo "  └─────────────────────────────────────────────────────┘"
        echo ""
        exit 1
    fi

    info "다운로드 중: $DOWNLOAD_URL"
    TMP_DMG=$(mktemp /tmp/void_XXXXXX.dmg)
    if ! curl -fsSL --progress-bar -o "$TMP_DMG" "$DOWNLOAD_URL"; then
        echo ""
        warn "다운로드 실패. 수동으로 설치해 주세요:"
        echo ""
        echo "  1. https://voideditor.com 에서 Mac 버전 다운로드"
        echo "  2. /Applications 에 Void.app 설치"
        echo "  3. bash apply-all.sh"
        echo ""
        rm -f "$TMP_DMG"
        exit 1
    fi

    info "Void.app 설치 중..."
    TMP_MNT=$(mktemp -d /tmp/void_mnt_XXXXXX)
    hdiutil attach "$TMP_DMG" -mountpoint "$TMP_MNT" -quiet -nobrowse
    cp -R "$TMP_MNT"/Void.app /Applications/
    hdiutil detach "$TMP_MNT" -quiet
    rm -f "$TMP_DMG"
    success "Void.app 설치 완료"
}

echo ""
echo "  ╔══════════════════════════════════╗"
echo "  ║     SonCode Mac 설치 스크립트    ║"
echo "  ║     (Void + Korean AG patches)   ║"
echo "  ╚══════════════════════════════════╝"
echo ""

# ── 1. 권한 확인 ──────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    warn "관리자 권한이 필요합니다. sudo로 재실행합니다..."
    # curl | bash 방식이면 $0이 파일이 아님 → 스크립트를 임시파일로 받아서 재실행
    if [ -f "$0" ]; then
        exec sudo bash "$0" "$@"
    else
        TMP=$(mktemp /tmp/soncode_install_XXXXXX)  # macOS mktemp: X는 맨 끝에
        curl -fsSL "https://raw.githubusercontent.com/SiChoong/soncode-mac-patches/main/install.sh" -o "$TMP"
        exec sudo bash "$TMP" "$@"
    fi
fi

# ── 2. 설치 대상 결정 ─────────────────────────────────────────────
if [ -d "$SONCODE_APP" ]; then
    TARGET="$SONCODE_APP"
    info "SonCode.app 발견: $SONCODE_APP"
elif [ -d "$VOID_APP" ]; then
    TARGET="$VOID_APP"
    info "Void.app 발견: $VOID_APP"
    warn "SonCode 브랜딩 없이 Void에 패치를 적용합니다."
else
    info "Void.app을 자동으로 다운로드합니다..."
    TARGET="$VOID_APP"
    install_void
fi

WBJS="$TARGET/Contents/Resources/app/out/vs/workbench/workbench.desktop.main.js"
PROD="$TARGET/Contents/Resources/app/product.json"

if [ ! -f "$WBJS" ]; then
    error "workbench.desktop.main.js 를 찾을 수 없습니다: $WBJS"
    exit 1
fi

# ── 3. 패치 적용 ──────────────────────────────────────────────────
info "패치를 적용합니다..."

python3 - "$WBJS" "$PROD" <<'PYEOF'
import sys, os, hashlib, base64, json

wbjs, prod_path = sys.argv[1], sys.argv[2]

def update_checksum(content_bytes):
    digest = hashlib.sha256(content_bytes).digest()
    b64 = base64.b64encode(digest).rstrip(b"=").decode()
    with open(prod_path, "r", encoding="utf-8") as f:
        prod = f.read()
    data = json.loads(prod)
    old_cs = data.get("checksums", {}).get("vs/workbench/workbench.desktop.main.js", "")
    if old_cs:
        prod = prod.replace(old_cs, b64)
        with open(prod_path, "w", encoding="utf-8") as f:
            f.write(prod)
    return b64

with open(wbjs, "r", encoding="utf-8") as f:
    content = f.read()
content = content.replace("\r\n", "\n")

errors = []

# ── PATCH 1: UI 언어 토글 ──────────────────────────────────────
if "korean-ag.toggleUiLocale" not in content:
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
    anchor = "\n// out-build/vs/workbench/contrib/localization/common/localization.contribution.js"
    if anchor in content:
        content = content.replace(anchor, new_code + anchor, 1)
        old_reg = "    registerAction2(ClearDisplayLanguageAction);"
        new_reg = old_reg + "\n    registerAction2(KoreanAgToggleLocaleAction);"
        content = content.replace(old_reg, new_reg, 1)
        print("[P1] UI Language Toggle: OK")
    else:
        errors.append("P1: localization anchor not found (version mismatch?)")
else:
    print("[P1] UI Language Toggle: already patched")

# ── PATCH 2: + 버튼 ───────────────────────────────────────────
if "korean-ag.plusButton" not in content:
    has_r83  = "import_react83"       in content
    has_r163 = "import_react163"      in content
    has_jsx  = "import_jsx_runtime123" in content
    if not (has_r83 and has_r163 and has_jsx):
        errors.append(f"P2: module refs missing (react83={has_r83} react163={has_r163} jsx123={has_jsx}) — version mismatch")
    else:
        patches = [
            # P2-a: VoidChatArea2 props
            ("  featureName,\n  loadingIcon\n}) => {",
             "  featureName,\n  loadingIcon,\n  toolbarLeft\n}) => {", "P2a"),
            # P2-b: bottom row restructure
            ('void-flex void-flex-row void-justify-between void-items-end void-gap-1", children: [\n'
             '          showModelDropdown && /* @__PURE__ */ (0, import_jsx_runtime123.jsxs)("div", { className: "void-flex void-flex-col void-gap-y-1", children: [\n'
             '            /* @__PURE__ */ (0, import_jsx_runtime123.jsx)(ReasoningOptionSlider2, { featureName }),\n'
             '            /* @__PURE__ */ (0, import_jsx_runtime123.jsxs)("div", { className: "void-flex void-items-center void-flex-wrap void-gap-x-2 void-gap-y-1 void-text-nowrap ", children: [\n'
             '              featureName === "Chat" && /* @__PURE__ */ (0, import_jsx_runtime123.jsx)(ChatModeDropdown2, { className: "void-text-xs void-text-void-fg-3 void-bg-void-bg-1 void-border void-border-void-border-2 void-rounded void-py-0.5 void-px-1" }),\n'
             '              /* @__PURE__ */ (0, import_jsx_runtime123.jsx)(ModelDropdown3, { featureName, className: "void-text-xs void-text-void-fg-3 void-bg-void-bg-1 void-rounded" })\n'
             '            ] })\n'
             '          ] }),',
             'void-flex void-flex-row void-justify-between void-items-end void-gap-1", children: [\n'
             '          /* @__PURE__ */ (0, import_jsx_runtime123.jsxs)("div", { className: "void-flex void-flex-col void-gap-y-1", children: [\n'
             '            showModelDropdown && /* @__PURE__ */ (0, import_jsx_runtime123.jsx)(ReasoningOptionSlider2, { featureName }),\n'
             '            /* @__PURE__ */ (0, import_jsx_runtime123.jsxs)("div", { className: "void-flex void-items-center void-flex-wrap void-gap-x-2 void-gap-y-1 void-text-nowrap", children: [\n'
             '              toolbarLeft,\n'
             '              showModelDropdown && featureName === "Chat" && /* @__PURE__ */ (0, import_jsx_runtime123.jsx)(ChatModeDropdown2, { className: "void-text-xs void-text-void-fg-3 void-bg-void-bg-1 void-border void-border-void-border-2 void-rounded void-py-0.5 void-px-1" }),\n'
             '              showModelDropdown && /* @__PURE__ */ (0, import_jsx_runtime123.jsx)(ModelDropdown3, { featureName, className: "void-text-xs void-text-void-fg-3 void-bg-void-bg-1 void-rounded" })\n'
             '            ] })\n'
             '          ] }),', "P2b"),
            # P2-c: openAtMenuWithPathRef ref
            ("const textAreaRef = (0, import_react163.useRef)(null);\n"
             "  const textAreaFnsRef = (0, import_react163.useRef)(null);\n"
             "  const accessor = useAccessor4();",
             "const textAreaRef = (0, import_react163.useRef)(null);\n"
             "  const textAreaFnsRef = (0, import_react163.useRef)(null);\n"
             "  const openAtMenuWithPathRef = (0, import_react163.useRef)(null);\n"
             "  const accessor = useAccessor4();", "P2c"),
            # P2-d: toolbarLeft prop
            ("    {\n"
             '      featureName: "Chat",\n'
             "      onSubmit: () => onSubmit(),\n"
             "      onAbort,\n"
             "      isStreaming: !!isRunning,\n"
             "      isDisabled,\n"
             "      showSelections: true,\n"
             "      selections,\n"
             "      setSelections,\n"
             "      onClickAnywhere: () => {\n"
             "        textAreaRef.current?.focus();\n"
             "      },",
             "    {\n"
             '      featureName: "Chat",\n'
             "      onSubmit: () => onSubmit(),\n"
             "      onAbort,\n"
             "      isStreaming: !!isRunning,\n"
             "      isDisabled,\n"
             "      showSelections: true,\n"
             "      selections,\n"
             "      setSelections,\n"
             "      onClickAnywhere: () => {\n"
             "        textAreaRef.current?.focus();\n"
             "      },\n"
             "      toolbarLeft: PlusButtonW19(textAreaRef, openAtMenuWithPathRef, commandService),", "P2d"),
            # P2-e: openAtMenuWithPathRef in VoidInputBox23 call
            ("fnsRef: textAreaFnsRef,\n"
             "          multiline: true\n"
             "        }\n"
             "      )\n"
             "    }\n"
             "  );\n"
             "  const isLandingPage = previousMessages.length === 0;",
             "fnsRef: textAreaFnsRef,\n"
             "          openAtMenuWithPathRef,\n"
             "          multiline: true\n"
             "        }\n"
             "      )\n"
             "    }\n"
             "  );\n"
             "  const isLandingPage = previousMessages.length === 0;", "P2e"),
            # P2-f: VoidInputBox23 function signature
            ("function X23({ initValue, placeholder, multiline, enableAtToMention, fnsRef, className: className2, onKeyDown, onFocus, onBlur, onChangeText }, ref) {",
             "function X23({ initValue, placeholder, multiline, enableAtToMention, fnsRef, openAtMenuWithPathRef, className: className2, onKeyDown, onFocus, onBlur, onChangeText }, ref) {", "P2f"),
        ]
        ok = True
        for (old, new, label) in patches:
            if old not in content:
                errors.append(f"P2-{label}: anchor not found (version mismatch?)")
                ok = False
                break
            content = content.replace(old, new, 1)

        if ok:
            # P2-g: useEffect in VoidInputBox23
            vib23_idx = content.find("var VoidInputBox23")
            if vib23_idx >= 0:
                region = content[vib23_idx:vib23_idx + 50000]
                close_off = region.find("const onCloseOptionMenu = () => {")
                if close_off >= 0:
                    abs_idx = vib23_idx + close_off
                    p7_old = ("const onCloseOptionMenu = () => {\n"
                              "    setIsMenuOpen(false);\n"
                              "  };")
                    p7_new = (p7_old + "\n"
                              "  (0, import_react83.useEffect)(() => {\n"
                              "    if (!openAtMenuWithPathRef) return;\n"
                              "    openAtMenuWithPathRef.current = async (path) => {\n"
                              '      currentPathRef.current = JSON.stringify(path);\n'
                              '      const newOpts = await getOptionsAtPath3(accessor, path, "") || [];\n'
                              "      if (currentPathRef.current !== JSON.stringify(path)) return;\n"
                              '      setOptionPath(path); setOptionText(""); setIsMenuOpen(true);\n'
                              "      setOptionIdx(0); setOptions2(newOpts); setDidLoadInitialOptions(true);\n"
                              "    };\n"
                              "    return () => { if (openAtMenuWithPathRef) openAtMenuWithPathRef.current = null; };\n"
                              "  }, [openAtMenuWithPathRef, accessor]);")
                    before = content[:abs_idx]
                    after  = content[abs_idx:]
                    if after.startswith(p7_old):
                        content = before + p7_new + after[len(p7_old):]

            # P2-h: insert PlusButtonW19 function
            plus_code = (
                "// [SonCode W19+] Plus button\n"
                "function PlusButtonW19(textAreaRef, openAtMenuWithPathRef, commandService) {\n"
                "  const [isOpen, setIsOpen] = (0, import_react163.useState)(false);\n"
                "  const btnRef = (0, import_react163.useRef)(null);\n"
                "  const menuRef = (0, import_react163.useRef)(null);\n"
                "  (0, import_react163.useEffect)(() => {\n"
                "    if (!isOpen) return;\n"
                "    const handle = (e) => {\n"
                "      if (btnRef.current && btnRef.current.contains(e.target)) return;\n"
                "      if (menuRef.current && menuRef.current.contains(e.target)) return;\n"
                "      setIsOpen(false);\n"
                "    };\n"
                '    document.addEventListener("mousedown", handle);\n'
                '    return () => document.removeEventListener("mousedown", handle);\n'
                "  }, [isOpen]);\n"
                "  const items = [\n"
                '    { label: "[F] File",    desc: "Code/Text",  action: () => openAtMenuWithPathRef.current && openAtMenuWithPathRef.current(["files"]) },\n'
                '    { label: "[D] Folder",  desc: "Folder ref", action: () => openAtMenuWithPathRef.current && openAtMenuWithPathRef.current(["folders"]) },\n'
                '    { label: "[I] Image",   desc: "Image file", action: () => openAtMenuWithPathRef.current && openAtMenuWithPathRef.current(["files"]) },\n'
                '    { label: "/ Slash",     desc: "Quick cmd",  action: () => {\n'
                "      const ta = textAreaRef.current; if (!ta) return;\n"
                "      ta.focus(); const p = ta.selectionStart != null ? ta.selectionStart : ta.value.length;\n"
                '      ta.value = ta.value.slice(0,p) + "/" + ta.value.slice(p);\n'
                "      ta.setSelectionRange(p+1,p+1);\n"
                '      ta.dispatchEvent(new Event("input", { bubbles: true }));\n'
                "    }},\n"
                '    { label: "[C] Connect", desc: "MCP",        action: () => commandService.executeCommand("workbench.action.openSettings", "void mcp") },\n'
                '    { label: "[P] Plugin",  desc: "Extensions", action: () => commandService.executeCommand("workbench.view.extensions") }\n'
                "  ];\n"
                "  const _jsx = import_jsx_runtime123.jsx;\n"
                "  const _jsxs = import_jsx_runtime123.jsxs;\n"
                "  const _Fragment = import_react163.Fragment;\n"
                '  return _jsxs(_Fragment, { children: [\n'
                '    _jsx("button", {\n'
                '      ref: btnRef, type: "button",\n'
                '      "data-korean-ag": "korean-ag.plusButton",\n'
                '      title: "Add: file/folder/image/slash/connect/plugin",\n'
                "      onClick: () => setIsOpen(v => !v),\n"
                "      style: {\n"
                '        display: "flex", alignItems: "center", padding: "1px 3px",\n'
                '        borderRadius: "4px", border: "none", background: "transparent",\n'
                '        cursor: "pointer", color: "var(--vscode-foreground)",\n'
                '        opacity: isOpen ? 1 : 0.55, fontSize: "14px", lineHeight: 1\n'
                "      },\n"
                '      children: "+"\n'
                "    }),\n"
                '    isOpen && _jsx("div", {\n'
                "      ref: menuRef,\n"
                "      style: {\n"
                '        position: "fixed", zIndex: 9999,\n'
                '        background: "var(--vscode-editor-background)",\n'
                '        border: "1px solid var(--vscode-widget-border)",\n'
                '        borderRadius: "6px", padding: "4px 0", minWidth: "190px",\n'
                '        boxShadow: "0 4px 16px rgba(0,0,0,0.35)",\n'
                '        bottom: (btnRef.current ? (window.innerHeight - btnRef.current.getBoundingClientRect().top + 4) : 40) + "px",\n'
                '        left: (btnRef.current ? btnRef.current.getBoundingClientRect().left : 10) + "px"\n'
                "      },\n"
                '      children: items.map((item, i) => _jsx("button", {\n'
                '        key: i, type: "button",\n'
                "        onClick: () => { setIsOpen(false); item.action(); },\n"
                "        style: {\n"
                '          display: "flex", alignItems: "center", gap: "8px",\n'
                '          width: "100%", padding: "5px 14px",\n'
                '          border: "none", background: "transparent",\n'
                '          cursor: "pointer", color: "var(--vscode-foreground)",\n'
                '          fontSize: "13px", textAlign: "left"\n'
                "        },\n"
                '        onMouseEnter: e => e.currentTarget.style.background = "var(--vscode-list-hoverBackground)",\n'
                '        onMouseLeave: e => e.currentTarget.style.background = "transparent",\n'
                "        children: _jsxs(_Fragment, { children: [\n"
                '          _jsx("span", { children: item.label }),\n'
                '          _jsx("span", { style: { marginLeft: "auto", opacity: 0.5, fontSize: "11px", whiteSpace: "nowrap" }, children: item.desc })\n'
                "        ]})\n"
                "      }, i))\n"
                "    })\n"
                "  ]});\n"
                "}\n"
            )
            insert_before = "var VoidChatArea2 = ({"
            if insert_before in content:
                content = content.replace(insert_before, plus_code + insert_before, 1)
                print("[P2] Plus Button: OK")
            else:
                errors.append("P2: VoidChatArea2 marker not found")
else:
    print("[P2] Plus Button: already patched")

# ── PATCH 3: 인코딩 깨짐 복구 ────────────────────────────────────
broken = 'children: "??\n'
if broken in content:
    content = content.replace(broken, 'children: "+"\n')
    print("[P3] Encoding fix: OK")
else:
    print("[P3] Encoding fix: not needed (OK)")

# ── 결과 저장 ────────────────────────────────────────────────────
if errors:
    for e in errors:
        print(f"  ERROR: {e}", file=sys.stderr)
    sys.exit(1)

content_bytes = content.encode("utf-8")
with open(wbjs, "w", encoding="utf-8", newline="\n") as f:
    f.write(content)

b64 = update_checksum(content_bytes)
print(f"[checksum] {b64}")
print("All patches applied successfully.")
PYEOF

# ── 4. 검증 ───────────────────────────────────────────────────────
info "패치 결과 검증 중..."
python3 - "$WBJS" <<'VERIFY'
import sys
with open(sys.argv[1], encoding="utf-8") as f:
    c = f.read()
markers = {
    "korean-ag.toggleUiLocale": "UI 언어 토글",
    "korean-ag.plusButton":     "+ 버튼",
    "function PlusButtonW19":   "PlusButtonW19 함수",
}
ok = True
for k, v in markers.items():
    if k in c:
        print(f"  [✓] {v}")
    else:
        print(f"  [✗] {v} — 누락됨", file=sys.stderr)
        ok = False
sys.exit(0 if ok else 1)
VERIFY

echo ""
success "SonCode 패치 완료! 앱을 완전히 종료한 후 다시 실행하세요."
