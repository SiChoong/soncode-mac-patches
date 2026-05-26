#!/usr/bin/env python3
# patch-plus-button.sh — Mac equivalent of patch-plus-button.ps1
# Usage: python3 patch-plus-button.sh

import sys, os, hashlib, base64, json

OUT_FILE = "/tmp/patch-plus-result.txt"
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

    if "korean-ag.plusButton" in content:
        write_out("Already patched")
        sys.exit(0)

    # Required module references check
    has_react83  = "import_react83"    in content
    has_react163 = "import_react163"   in content
    has_jsx123   = "import_jsx_runtime123" in content
    if not (has_react83 and has_react163 and has_jsx123):
        write_out(f"ERROR: Missing module refs react83={has_react83} react163={has_react163} jsx123={has_jsx123}")
        sys.exit(1)

    # P1: VoidChatArea2 props - add toolbarLeft
    p1_old = "  featureName,\n  loadingIcon\n}) => {"
    p1_new = "  featureName,\n  loadingIcon,\n  toolbarLeft\n}) => {"
    if p1_old not in content:
        write_out("ERROR: P1 - VoidChatArea2 props")
        sys.exit(1)
    content = content.replace(p1_old, p1_new, 1)

    # P2: VoidChatArea2 bottom row restructure
    p2_old = (
        'void-flex void-flex-row void-justify-between void-items-end void-gap-1", children: [\n'
        '          showModelDropdown && /* @__PURE__ */ (0, import_jsx_runtime123.jsxs)("div", { className: "void-flex void-flex-col void-gap-y-1", children: [\n'
        '            /* @__PURE__ */ (0, import_jsx_runtime123.jsx)(ReasoningOptionSlider2, { featureName }),\n'
        '            /* @__PURE__ */ (0, import_jsx_runtime123.jsxs)("div", { className: "void-flex void-items-center void-flex-wrap void-gap-x-2 void-gap-y-1 void-text-nowrap ", children: [\n'
        '              featureName === "Chat" && /* @__PURE__ */ (0, import_jsx_runtime123.jsx)(ChatModeDropdown2, { className: "void-text-xs void-text-void-fg-3 void-bg-void-bg-1 void-border void-border-void-border-2 void-rounded void-py-0.5 void-px-1" }),\n'
        '              /* @__PURE__ */ (0, import_jsx_runtime123.jsx)(ModelDropdown3, { featureName, className: "void-text-xs void-text-void-fg-3 void-bg-void-bg-1 void-rounded" })\n'
        '            ] })\n'
        '          ] }),'
    )
    p2_new = (
        'void-flex void-flex-row void-justify-between void-items-end void-gap-1", children: [\n'
        '          /* @__PURE__ */ (0, import_jsx_runtime123.jsxs)("div", { className: "void-flex void-flex-col void-gap-y-1", children: [\n'
        '            showModelDropdown && /* @__PURE__ */ (0, import_jsx_runtime123.jsx)(ReasoningOptionSlider2, { featureName }),\n'
        '            /* @__PURE__ */ (0, import_jsx_runtime123.jsxs)("div", { className: "void-flex void-items-center void-flex-wrap void-gap-x-2 void-gap-y-1 void-text-nowrap", children: [\n'
        '              toolbarLeft,\n'
        '              showModelDropdown && featureName === "Chat" && /* @__PURE__ */ (0, import_jsx_runtime123.jsx)(ChatModeDropdown2, { className: "void-text-xs void-text-void-fg-3 void-bg-void-bg-1 void-border void-border-void-border-2 void-rounded void-py-0.5 void-px-1" }),\n'
        '              showModelDropdown && /* @__PURE__ */ (0, import_jsx_runtime123.jsx)(ModelDropdown3, { featureName, className: "void-text-xs void-text-void-fg-3 void-bg-void-bg-1 void-rounded" })\n'
        '            ] })\n'
        '          ] }),'
    )
    if p2_old not in content:
        write_out("ERROR: P2 - VoidChatArea2 bottom row")
        sys.exit(1)
    content = content.replace(p2_old, p2_new, 1)

    # P3: SidebarChat - add openAtMenuWithPathRef
    p3_old = (
        "const textAreaRef = (0, import_react163.useRef)(null);\n"
        "  const textAreaFnsRef = (0, import_react163.useRef)(null);\n"
        "  const accessor = useAccessor4();"
    )
    p3_new = (
        "const textAreaRef = (0, import_react163.useRef)(null);\n"
        "  const textAreaFnsRef = (0, import_react163.useRef)(null);\n"
        "  const openAtMenuWithPathRef = (0, import_react163.useRef)(null);\n"
        "  const accessor = useAccessor4();"
    )
    if p3_old not in content:
        write_out("ERROR: P3 - SidebarChat textAreaRef")
        sys.exit(1)
    content = content.replace(p3_old, p3_new, 1)

    # P4: inputChatArea props - add toolbarLeft
    p4_old = (
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
        "      },"
    )
    p4_new = (
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
        "      toolbarLeft: PlusButtonW19(textAreaRef, openAtMenuWithPathRef, commandService),"
    )
    if p4_old not in content:
        write_out("ERROR: P4 - inputChatArea props")
        sys.exit(1)
    content = content.replace(p4_old, p4_new, 1)

    # P5: VoidInputBox23 - pass openAtMenuWithPathRef
    p5_old = (
        "fnsRef: textAreaFnsRef,\n"
        "          multiline: true\n"
        "        }\n"
        "      )\n"
        "    }\n"
        "  );\n"
        "  const isLandingPage = previousMessages.length === 0;"
    )
    p5_new = (
        "fnsRef: textAreaFnsRef,\n"
        "          openAtMenuWithPathRef,\n"
        "          multiline: true\n"
        "        }\n"
        "      )\n"
        "    }\n"
        "  );\n"
        "  const isLandingPage = previousMessages.length === 0;"
    )
    if p5_old not in content:
        write_out("ERROR: P5 - VoidInputBox23 fnsRef")
        sys.exit(1)
    content = content.replace(p5_old, p5_new, 1)

    # P6: VoidInputBox23 signature
    p6_old = "function X23({ initValue, placeholder, multiline, enableAtToMention, fnsRef, className: className2, onKeyDown, onFocus, onBlur, onChangeText }, ref) {"
    p6_new = "function X23({ initValue, placeholder, multiline, enableAtToMention, fnsRef, openAtMenuWithPathRef, className: className2, onKeyDown, onFocus, onBlur, onChangeText }, ref) {"
    if p6_old not in content:
        write_out("ERROR: P6 - VoidInputBox23 signature")
        sys.exit(1)
    content = content.replace(p6_old, p6_new, 1)

    # P7: VoidInputBox23 - add useEffect after onCloseOptionMenu
    vib23_idx = content.find("var VoidInputBox23")
    if vib23_idx < 0:
        write_out("ERROR: P7 - VoidInputBox23 not found")
        sys.exit(1)
    search_region = content[vib23_idx:vib23_idx + 50000]
    close_menu_offset = search_region.find("const onCloseOptionMenu = () => {")
    if close_menu_offset < 0:
        write_out("ERROR: P7 - onCloseOptionMenu in VoidInputBox23 not found")
        sys.exit(1)
    close_menu_abs = vib23_idx + close_menu_offset

    p7_old = (
        "const onCloseOptionMenu = () => {\n"
        "    setIsMenuOpen(false);\n"
        "  };"
    )
    p7_new = (
        "const onCloseOptionMenu = () => {\n"
        "    setIsMenuOpen(false);\n"
        "  };\n"
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
        "  }, [openAtMenuWithPathRef, accessor]);"
    )

    before_close = content[:close_menu_abs]
    after_close  = content[close_menu_abs:]
    if not after_close.startswith(p7_old):
        write_out(f"ERROR: P7 - onCloseOptionMenu text mismatch at abs {close_menu_abs}")
        sys.exit(1)
    after_close = p7_new + after_close[len(p7_old):]
    content = before_close + after_close

    # P9: Insert PlusButtonW19 before VoidChatArea2
    insert_before = "var VoidChatArea2 = ({"
    plus_code = (
        "// [SonCode W19+] Plus button: files/folders/images/slash/connect/plugin\n"
        "function PlusButtonW19(textAreaRef, openAtMenuWithPathRef, commandService) {\n"
        "  const [isOpen, setIsOpen] = (0, import_react163.useState)(false);\n"
        "  const btnRef = (0, import_react163.useRef)(null);\n"
        "  const menuRef = (0, import_react163.useRef)(null);\n"
        "  (0, import_react163.useEffect)(() => {\n"
        "    if (!isOpen) return;\n"
        "    const handle = (e) => {\n"
        "      if (btnRef.current && btnRef.current.contains(e.target)) return;\n"
        "      if (menuRef.current && menuRef.current.contains(e.target)) return;\n"
        '      setIsOpen(false);\n'
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
        "  return _jsxs(_Fragment, { children: [\n"
        "    _jsx(\"button\", {\n"
        "      ref: btnRef, type: \"button\",\n"
        '      "data-korean-ag": "korean-ag.plusButton",\n'
        '      title: "Add: file/folder/image/slash/connect/plugin",\n'
        "      onClick: () => setIsOpen(v => !v),\n"
        "      style: {\n"
        '        display: "flex", alignItems: "center", padding: "1px 3px",\n'
        '        borderRadius: "4px", border: "none", background: "transparent",\n'
        '        cursor: "pointer", color: "var(--vscode-foreground)",\n'
        "        opacity: isOpen ? 1 : 0.55, fontSize: \"14px\", lineHeight: 1\n"
        "      },\n"
        '      children: "+"\n'
        "    }),\n"
        "    isOpen && _jsx(\"div\", {\n"
        "      ref: menuRef,\n"
        "      style: {\n"
        '        position: "fixed", zIndex: 9999,\n'
        '        background: "var(--vscode-editor-background)",\n'
        '        border: "1px solid var(--vscode-widget-border)",\n'
        '        borderRadius: "6px", padding: "4px 0", minWidth: "190px",\n'
        '        boxShadow: "0 4px 16px rgba(0,0,0,0.35)",\n'
        "        bottom: (btnRef.current ? (window.innerHeight - btnRef.current.getBoundingClientRect().top + 4) : 40) + \"px\",\n"
        "        left: (btnRef.current ? btnRef.current.getBoundingClientRect().left : 10) + \"px\"\n"
        "      },\n"
        "      children: items.map((item, i) => _jsx(\"button\", {\n"
        "        key: i, type: \"button\",\n"
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
        "          _jsx(\"span\", { children: item.label }),\n"
        "          _jsx(\"span\", { style: { marginLeft: \"auto\", opacity: 0.5, fontSize: \"11px\", whiteSpace: \"nowrap\" }, children: item.desc })\n"
        "        ]})\n"
        "      }, i))\n"
        "    })\n"
        "  ]});\n"
        "}\n"
    )

    if insert_before not in content:
        write_out("ERROR: P9 - VoidChatArea2 marker not found")
        sys.exit(1)
    content = content.replace(insert_before, plus_code + insert_before, 1)

    content_bytes = content.encode("utf-8")
    with open(WBJS, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)

    b64 = update_checksum(content_bytes)
    write_out(f"OK:{b64}")

except Exception as e:
    write_out(f"ERROR:{e}")
    sys.exit(1)
