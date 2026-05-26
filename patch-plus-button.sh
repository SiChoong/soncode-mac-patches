#!/usr/bin/env python3
# patch-plus-button.sh — 채팅 + 버튼 패치 (Void 1.4.x)
# Usage: python3 patch-plus-button.sh

import sys, os, hashlib, base64, json

OUT_FILE = "/tmp/patch-plus-result.txt"

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

    if "korean-ag.plusButton" in content:
        write_out("Already patched")
        sys.exit(0)

    # ── Void 1.4.x 모듈 참조 확인 ─────────────────────────────────
    # WPi = VoidChatArea, gt = JSX runtime, hh = React hooks
    has_wpi = "WPi=({children:" in content
    has_gt  = "(0,gt.jsxs)" in content
    has_hh  = "(0,hh.useCallback)" in content
    if not (has_wpi and has_gt and has_hh):
        write_out(f"ERROR: module refs missing WPi={has_wpi} gt={has_gt} hh={has_hh} (version mismatch?)")
        sys.exit(1)

    # ── P2a: WPi에 toolbarLeft prop 추가 ─────────────────────────
    p2a_old = "featureName:S,loadingIcon:_})=>(0,gt.jsxs)"
    p2a_new = "featureName:S,loadingIcon:_,toolbarLeft:C=null})=>(0,gt.jsxs)"
    if p2a_old not in content:
        write_out("ERROR: P2a - WPi prop anchor not found")
        sys.exit(1)
    content = content.replace(p2a_old, p2a_new, 1)

    # ── P2b: 툴바 children에 C(toolbarLeft) 삽입 ─────────────────
    p2b_old = 'void-text-nowrap ",children:[S==="Chat"&&(0,gt.jsx)(rcs,'
    p2b_new = 'void-text-nowrap ",children:[C,S==="Chat"&&(0,gt.jsx)(rcs,'
    if p2b_old not in content:
        write_out("ERROR: P2b - toolbar children anchor not found")
        sys.exit(1)
    content = content.replace(p2b_old, p2b_new, 1)

    # ── P2c: Chat 컴포넌트 WPi 호출에 toolbarLeft 전달 ───────────
    p2c_old = ('onClickAnywhere:()=>{i.current?.focus()},'
               'children:(0,gt.jsx)(TPi,{enableAtToMention:!0,')
    p2c_new = ('onClickAnywhere:()=>{i.current?.focus()},'
               'toolbarLeft:PlusButtonW19(i,hh,gt),'
               'children:(0,gt.jsx)(TPi,{enableAtToMention:!0,')
    if p2c_old not in content:
        write_out("ERROR: P2c - Chat toolbarLeft anchor not found")
        sys.exit(1)
    content = content.replace(p2c_old, p2c_new, 1)

    # ── P2d: PlusButtonW19 함수 삽입 (qe= 직전) ──────────────────
    plus_code = (
        "// [SonCode W19+] Plus button\n"
        "function PlusButtonW19(textAreaRef,R,Jsx){\n"
        "  const[isOpen,setIsOpen]=R.useState(false);\n"
        "  const btnRef=R.useRef(null);\n"
        "  const menuRef=R.useRef(null);\n"
        "  R.useEffect(()=>{\n"
        "    if(!isOpen)return;\n"
        "    const handle=(e)=>{\n"
        "      if(btnRef.current&&btnRef.current.contains(e.target))return;\n"
        "      if(menuRef.current&&menuRef.current.contains(e.target))return;\n"
        "      setIsOpen(false);\n"
        "    };\n"
        '    document.addEventListener("mousedown",handle);\n'
        '    return()=>document.removeEventListener("mousedown",handle);\n'
        "  },[isOpen]);\n"
        "  const triggerAt=()=>{\n"
        "    const ta=textAreaRef.current;if(!ta)return;\n"
        "    ta.focus();\n"
        "    const p=ta.selectionStart!=null?ta.selectionStart:ta.value.length;\n"
        '    ta.value=ta.value.slice(0,p)+"@"+ta.value.slice(p);\n'
        "    ta.setSelectionRange(p+1,p+1);\n"
        '    ta.dispatchEvent(new InputEvent("input",{data:"@",bubbles:true,cancelable:true}));\n'
        "  };\n"
        "  const triggerSlash=()=>{\n"
        "    const ta=textAreaRef.current;if(!ta)return;\n"
        "    ta.focus();\n"
        "    const p=ta.selectionStart!=null?ta.selectionStart:ta.value.length;\n"
        '    ta.value=ta.value.slice(0,p)+"/"+ta.value.slice(p);\n'
        "    ta.setSelectionRange(p+1,p+1);\n"
        '    ta.dispatchEvent(new Event("input",{bubbles:true}));\n'
        "  };\n"
        "  const items=[\n"
        '    {label:"@ File / Folder",desc:"mention",action:triggerAt},\n'
        '    {label:"/ Slash command",desc:"quick cmd",action:triggerSlash}\n'
        "  ];\n"
        "  const _jsx=Jsx.jsx,_jsxs=Jsx.jsxs,_Frag=Jsx.Fragment;\n"
        "  return _jsxs(_Frag,{children:[\n"
        "    _jsx('button',{\n"
        "      ref:btnRef,type:'button',\n"
        "      'data-soncode':'korean-ag.plusButton',\n"
        "      title:'Add file / slash mention',\n"
        "      onClick:()=>setIsOpen(v=>!v),\n"
        "      style:{display:'flex',alignItems:'center',padding:'1px 4px',\n"
        "        borderRadius:'4px',border:'none',background:'transparent',\n"
        "        cursor:'pointer',color:'var(--vscode-foreground)',\n"
        "        opacity:isOpen?1:0.6,fontSize:'16px',lineHeight:1},\n"
        "      children:'+'\n"
        "    }),\n"
        "    isOpen&&_jsx('div',{\n"
        "      ref:menuRef,\n"
        "      style:{position:'fixed',zIndex:9999,\n"
        "        background:'var(--vscode-editor-background)',\n"
        "        border:'1px solid var(--vscode-widget-border)',\n"
        "        borderRadius:'6px',padding:'4px 0',minWidth:'170px',\n"
        "        boxShadow:'0 4px 16px rgba(0,0,0,0.35)',\n"
        "        bottom:(btnRef.current?(window.innerHeight-btnRef.current.getBoundingClientRect().top+4):40)+'px',\n"
        "        left:(btnRef.current?btnRef.current.getBoundingClientRect().left:10)+'px'},\n"
        "      children:items.map((item,idx)=>_jsx('button',{\n"
        "        type:'button',\n"
        "        onClick:()=>{setIsOpen(false);item.action();},\n"
        "        style:{display:'flex',alignItems:'center',gap:'8px',\n"
        "          width:'100%',padding:'5px 14px',border:'none',\n"
        "          background:'transparent',cursor:'pointer',\n"
        "          color:'var(--vscode-foreground)',fontSize:'13px',textAlign:'left'},\n"
        "        onMouseEnter:e=>e.currentTarget.style.background='var(--vscode-list-hoverBackground)',\n"
        "        onMouseLeave:e=>e.currentTarget.style.background='transparent',\n"
        "        children:_jsxs(_Frag,{children:[\n"
        "          _jsx('span',{children:item.label}),\n"
        "          _jsx('span',{style:{marginLeft:'auto',opacity:0.5,fontSize:'11px'},children:item.desc})\n"
        "        ]})\n"
        "      },idx))\n"
        "    })\n"
        "  ]});\n"
        "}\n"
    )
    p2d_old = '),Se=(0,hh.useCallback)(It=>{I(!It)},[I]),'
    p2d_new = ')\n' + plus_code + 'Se=(0,hh.useCallback)(It=>{I(!It)},[I]),'
    if p2d_old not in content:
        write_out("ERROR: P2d - PlusButtonW19 insertion anchor not found")
        sys.exit(1)
    content = content.replace(p2d_old, p2d_new, 1)

    content_bytes = content.encode("utf-8")
    with open(WBJS, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)

    b64 = update_checksum(content_bytes)
    write_out(f"OK:{b64}")

except Exception as e:
    write_out(f"ERROR:{e}")
    sys.exit(1)
