#!/usr/bin/env bash
# ============================================================
# create-alias.sh — SonCode macOS 바탕화면 별칭 + Dock 추가
# (Windows create-desktop-shortcut.ps1 Mac 대응판)
# ------------------------------------------------------------
# 사용: bash scripts/create-alias.sh
#       bash scripts/create-alias.sh --dock-only
#       bash scripts/create-alias.sh --no-dock
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }

DOCK_ONLY=false
NO_DOCK=false
for arg in "$@"; do
    case "$arg" in
        --dock-only) DOCK_ONLY=true ;;
        --no-dock)   NO_DOCK=true ;;
    esac
done

# 앱 번들 탐색
APP_BUNDLE=""
for bundle in "/Applications/SonCode.app" "/Applications/Void.app"; do
    if [ -d "$bundle" ]; then
        APP_BUNDLE="$bundle"
        break
    fi
done

if [ -z "$APP_BUNDLE" ]; then
    echo -e "${RED}[✗]${NC} SonCode.app 또는 Void.app이 /Applications에 없습니다."
    echo "  install.sh 를 먼저 실행하세요."
    exit 1
fi

APP_NAME=$(basename "$APP_BUNDLE" .app)
DESKTOP="$HOME/Desktop"
ALIAS_PATH="$DESKTOP/$APP_NAME.app"

# ---- 바탕화면 별칭 생성 ----
if ! $DOCK_ONLY; then
    info "바탕화면 별칭 생성: $ALIAS_PATH"

    # 기존 별칭 제거
    [ -e "$ALIAS_PATH" ] && rm -rf "$ALIAS_PATH"

    # osascript로 Finder 별칭 생성
    osascript << APPLES
tell application "Finder"
    set srcFile to POSIX file "$APP_BUNDLE" as alias
    set destFolder to POSIX file "$DESKTOP" as alias
    make new alias file to srcFile at destFolder
    set name of result to "$APP_NAME"
end tell
APPLES

    if [ -e "$ALIAS_PATH" ]; then
        success "바탕화면 별칭 생성 완료: $ALIAS_PATH"
    else
        # 폴백: 심볼릭 링크
        ln -sf "$APP_BUNDLE" "$ALIAS_PATH"
        warn "Finder 별칭 실패 — 심볼릭 링크로 대체: $ALIAS_PATH"
    fi
fi

# ---- Dock에 추가 ----
if ! $NO_DOCK; then
    info "Dock에 $APP_NAME 추가..."
    DOCK_PLIST="$HOME/Library/Preferences/com.apple.dock.plist"

    # 이미 Dock에 있는지 확인
    if defaults read com.apple.dock persistent-apps 2>/dev/null | grep -q "$APP_BUNDLE"; then
        warn "이미 Dock에 등록되어 있습니다."
    else
        ENTRY="<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$APP_BUNDLE</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"

        # Python으로 plist 수정 (plistlib 사용)
        python3 - << PYEOF
import plistlib, subprocess, os

plist_path = os.path.expanduser("~/Library/Preferences/com.apple.dock.plist")
try:
    # 현재 Dock 설정 읽기
    result = subprocess.run(
        ["plutil", "-convert", "xml1", "-o", "-", plist_path],
        capture_output=True
    )
    plist = plistlib.loads(result.stdout)

    apps = plist.get("persistent-apps", [])

    # 이미 있으면 스킵
    for app in apps:
        tile = app.get("tile-data", {}).get("file-data", {})
        if "$APP_BUNDLE" in tile.get("_CFURLString", ""):
            print("  이미 Dock에 등록됨")
            exit(0)

    # 추가
    new_entry = {
        "tile-data": {
            "file-data": {
                "_CFURLString": "$APP_BUNDLE",
                "_CFURLStringType": 0
            }
        }
    }
    apps.append(new_entry)
    plist["persistent-apps"] = apps

    # 저장
    with open(plist_path, "wb") as f:
        plistlib.dump(plist, f)

    # Dock 재시작
    subprocess.run(["killall", "Dock"], check=False)
    print("  Dock에 추가 완료")
except Exception as e:
    print(f"  Dock 추가 실패: {e}")
    print("  수동으로 /Applications/$APP_NAME.app을 Dock에 드래그하세요.")
PYEOF

        success "Dock에 $APP_NAME 추가 완료 (Dock 재시작됨)"
    fi
fi

echo ""
success "완료! 바탕화면의 $APP_NAME 아이콘으로 실행하세요."
