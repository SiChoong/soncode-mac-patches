#!/usr/bin/env python3
# patch-plus-button.sh — 채팅 + 버튼 패치 (Void 1.0.2)
# <details>/<summary> 네이티브 드롭다운 — React hooks 불필요, P2d 주입 없음
# Usage: python3 patch-plus-button.sh

import sys, os, hashlib, base64, json

OUT_FILE = "/tmp/patch-plus-result.txt"

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
    APP_DIR = f"/Applications/SonCode.app/Contents/Resources/app"

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

    if "korean-ag.plusButton" in content:
        write_out("Already patched")
        sys.exit(0)

    # ── 버전 확인 ───────────────────────────────────────────────
    has_vdi = "vdi=({children:i,onSubmit:e," in content
    has_ci  = "(0,ci.jsxs)" in content
    has_mh  = "(0,Mh.useCallback)" in content
    if not (has_vdi and has_ci and has_mh):
        write_out(f"ERROR: module refs missing vdi={has_vdi} ci={has_ci} Mh={has_mh}")
        sys.exit(1)

    # ── P2a: vdi에 toolbarLeft prop 추가 ──────────────────────────
    p2a_old = ",featureName:w,loadingIcon:C})=>(0,ci.jsxs)"
    p2a_new = ",featureName:w,loadingIcon:C,toolbarLeft:TL=null})=>(0,ci.jsxs)"
    if p2a_old not in content:
        write_out("ERROR: P2a anchor not found")
        sys.exit(1)
    content = content.replace(p2a_old, p2a_new, 1)

    # ── P2b: 툴바 children에 TL 삽입 ─────────────────────────────
    p2b_old = '"void-flex void-items-center void-flex-wrap void-gap-x-2 void-gap-y-1",children:[w==="Chat"&&(0,ci.jsx)(tFs,'
    p2b_new = '"void-flex void-items-center void-flex-wrap void-gap-x-2 void-gap-y-1",children:[TL,w==="Chat"&&(0,ci.jsx)(tFs,'
    if p2b_old not in content:
        write_out("ERROR: P2b anchor not found")
        sys.exit(1)
    content = content.replace(p2b_old, p2b_new, 1)

    # ── P2c: toolbarLeft에 <details> 드롭다운 버튼 직접 주입 ──────
    # React hooks 불필요 — <details>/<summary> HTML 네이티브 드롭다운
    # i (textarea ref)는 외부 Chat 컴포넌트 클로저로 접근
    btn = (
        '(0,ci.jsxs)("details",{'
        '"data-soncode":"korean-ag.plusButton",'
        'style:{position:"relative",display:"inline-flex",alignItems:"center"},'
        'onClick:(e)=>{if(e.target.tagName==="BUTTON")e.currentTarget.removeAttribute("open")},'
        'children:['
        '(0,ci.jsx)("summary",{'
        'style:{listStyle:"none",display:"flex",alignItems:"center",'
        'padding:"1px 5px",borderRadius:"4px",cursor:"pointer",'
        'color:"var(--vscode-foreground)",opacity:0.6,fontSize:"17px",'
        'userSelect:"none",lineHeight:1},'
        'title:"Add file / slash mention",'
        'children:"+"'
        '}),'
        '(0,ci.jsxs)("div",{'
        'style:{position:"absolute",bottom:"calc(100% + 4px)",left:0,'
        'zIndex:9999,background:"var(--vscode-editor-background)",'
        'border:"1px solid var(--vscode-widget-border)",'
        'borderRadius:"6px",padding:"4px 0",minWidth:"170px",'
        'boxShadow:"0 4px 16px rgba(0,0,0,0.35)"},'
        'children:['
        '(0,ci.jsx)("button",{type:"button",'
        'style:{display:"flex",alignItems:"center",gap:"8px",width:"100%",'
        'padding:"5px 14px",border:"none",background:"transparent",'
        'cursor:"pointer",color:"var(--vscode-foreground)",'
        'fontSize:"13px",textAlign:"left"},'
        'onMouseEnter:e=>{e.currentTarget.style.background="var(--vscode-list-hoverBackground)"},'
        'onMouseLeave:e=>{e.currentTarget.style.background="transparent"},'
        'onClick:()=>{const ta=i.current;if(!ta)return;ta.focus();'
        'const p=ta.selectionStart!=null?ta.selectionStart:ta.value.length;'
        'ta.value=ta.value.slice(0,p)+"@"+ta.value.slice(p);'
        'ta.setSelectionRange(p+1,p+1);'
        'ta.dispatchEvent(new InputEvent("input",{data:"@",bubbles:!0,cancelable:!0}))},'
        'children:"@ File / Folder"}),'
        '(0,ci.jsx)("button",{type:"button",'
        'style:{display:"flex",alignItems:"center",gap:"8px",width:"100%",'
        'padding:"5px 14px",border:"none",background:"transparent",'
        'cursor:"pointer",color:"var(--vscode-foreground)",'
        'fontSize:"13px",textAlign:"left"},'
        'onMouseEnter:e=>{e.currentTarget.style.background="var(--vscode-list-hoverBackground)"},'
        'onMouseLeave:e=>{e.currentTarget.style.background="transparent"},'
        'onClick:()=>{const ta=i.current;if(!ta)return;ta.focus();'
        'const p=ta.selectionStart!=null?ta.selectionStart:ta.value.length;'
        'ta.value=ta.value.slice(0,p)+"/"+ta.value.slice(p);'
        'ta.setSelectionRange(p+1,p+1);'
        'ta.dispatchEvent(new Event("input",{bubbles:!0}))},'
        'children:"/ Slash command"}'
        ')]})'
        ']})'
    )
    p2c_old = 'onClickAnywhere:()=>{i.current?.focus()},children:(0,ci.jsx)(hdi,'
    p2c_new = f'onClickAnywhere:()=>{{i.current?.focus()}},toolbarLeft:{btn},children:(0,ci.jsx)(hdi,'
    if p2c_old not in content:
        write_out("ERROR: P2c anchor not found")
        sys.exit(1)
    content = content.replace(p2c_old, p2c_new, 1)

    content_bytes = content.encode("utf-8")
    with open(WBJS, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)

    b64 = update_checksum(content_bytes)
    write_out(f"OK:{b64}")

except Exception as e:
    write_out(f"ERROR:{e}")
    sys.exit(1)
