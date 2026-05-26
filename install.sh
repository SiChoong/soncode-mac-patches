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

# ── PATCH 1: UI 언어 토글 (Void 1.4.x) ────────────────────────
# ce = Action2 base class, Pde = ILocaleService token,
# CO.value() = current locale, F.CommandPalette = menu id
if "korean-ag.toggleUiLocale" not in content:
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
    # Anchor: end of clearLocalePreference action → zzs registration class
    p1_old = ('async run(e){await e.get(Pde).clearLocalePreference()}},'
              'zzs=class extends z{constructor(){super(),X(Wzs),X(Uzs),')
    p1_new = ('async run(e){await e.get(Pde).clearLocalePreference()}}'
              + toggle_cls
              + ',zzs=class extends z{constructor(){super(),X(Wzs),X(Uzs),X(KoreanAgToggle1494),')
    if p1_old in content:
        content = content.replace(p1_old, p1_new, 1)
        print("[P1] UI Language Toggle: OK")
    else:
        errors.append("P1: localization anchor not found (version mismatch?)")
else:
    print("[P1] UI Language Toggle: already patched")

# ── PATCH 2: + 버튼 (Void 1.4.x) ─────────────────────────────
# WPi = VoidChatArea, gt = JSX runtime, hh = React hooks
if "korean-ag.plusButton" not in content:
    has_wpi = "WPi=({children:" in content
    has_gt  = "(0,gt.jsxs)" in content
    has_hh  = "(0,hh.useCallback)" in content
    if not (has_wpi and has_gt and has_hh):
        errors.append(f"P2: refs missing (WPi={has_wpi} gt={has_gt} hh={has_hh}) — version mismatch")
    else:
        ok2 = True

        # P2a: Add toolbarLeft prop to WPi component signature
        p2a_old = "featureName:S,loadingIcon:_})=>(0,gt.jsxs)"
        p2a_new = "featureName:S,loadingIcon:_,toolbarLeft:C=null})=>(0,gt.jsxs)"
        if p2a_old not in content:
            errors.append("P2a: WPi prop anchor not found"); ok2 = False
        else:
            content = content.replace(p2a_old, p2a_new, 1)

        if ok2:
            # P2b: Add C (toolbarLeft) as first child in the toolbar row
            p2b_old = 'void-text-nowrap ",children:[S==="Chat"&&(0,gt.jsx)(rcs,'
            p2b_new = 'void-text-nowrap ",children:[C,S==="Chat"&&(0,gt.jsx)(rcs,'
            if p2b_old not in content:
                errors.append("P2b: toolbar children anchor not found"); ok2 = False
            else:
                content = content.replace(p2b_old, p2b_new, 1)

        if ok2:
            # P2c: Pass toolbarLeft to WPi in the Chat component render
            p2c_old = ('onClickAnywhere:()=>{i.current?.focus()},'
                       'children:(0,gt.jsx)(TPi,{enableAtToMention:!0,')
            p2c_new = ('onClickAnywhere:()=>{i.current?.focus()},'
                       'toolbarLeft:PlusButtonW19(i,hh,gt),'
                       'children:(0,gt.jsx)(TPi,{enableAtToMention:!0,')
            if p2c_old not in content:
                errors.append("P2c: Chat toolbarLeft anchor not found"); ok2 = False
            else:
                content = content.replace(p2c_old, p2c_new, 1)

        if ok2:
            # P2d: Insert PlusButtonW19 function just before the qe= assignment
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
            # Insert before the 'Se=' callback assignment (right before qe=WPi render)
            p2d_old = '),Se=(0,hh.useCallback)(It=>{I(!It)},[I]),'
            p2d_new = ')\n' + plus_code + 'Se=(0,hh.useCallback)(It=>{I(!It)},[I]),'
            if p2d_old not in content:
                errors.append("P2d: qe insertion anchor not found"); ok2 = False
            else:
                content = content.replace(p2d_old, p2d_new, 1)
                print("[P2] Plus Button: OK")
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
