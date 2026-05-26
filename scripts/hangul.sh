#!/usr/bin/env bash
# =============================================================================
# hangul.sh — Hangul AI IDE (Korean AntiGravity) 안전 런처 (macOS)
# =============================================================================
# 목적:
#   Hangul.app은 package.json의 "main": "./out/main.js" (상대 경로) 때문에
#   반드시 ide-shell/ 을 cwd로 두고 실행되어야 한다. 어디서 호출하든
#   이 스크립트가 cwd를 ide-shell/로 보정하고 앱을 실행한다.
#
# 사용 예:
#   bash scripts/hangul.sh
#   bash scripts/hangul.sh --dev           # VSCODE_DEV=1
#   bash scripts/hangul.sh /path/to/proj   # 프로젝트 열기
# =============================================================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
IDE_SHELL="$REPO_ROOT/ide-shell"

DEV_MODE=false
EXTRA_ARGS=()
OPEN_PATH="."

for arg in "$@"; do
    case "$arg" in
        --dev|-d) DEV_MODE=true ;;
        --*) EXTRA_ARGS+=("$arg") ;;
        *) OPEN_PATH="$arg" ;;
    esac
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[*]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

SONCODE_APP="/Applications/SonCode.app"
VOID_APP="/Applications/Void.app"

# .app 번들 탐색: 개발 빌드 → SonCode.app → Void.app
APP_BUNDLE=""
for bundle in \
    "$IDE_SHELL/.build/electron/SonCode.app" \
    "$IDE_SHELL/.build/electron/Hangul.app" \
    "$SONCODE_APP" \
    "$VOID_APP"; do
    if [ -d "$bundle" ]; then
        APP_BUNDLE="$bundle"
        break
    fi
done

if [ -z "$APP_BUNDLE" ]; then
    error "앱 번들을 찾지 못했습니다.
  먼저 'bash scripts/first-build.sh' 로 빌드하거나 install.sh 를 실행하세요."
fi

USER_DATA="$REPO_ROOT/.fresh-userdata"
EXT_DIR="$USER_DATA/extensions"
mkdir -p "$USER_DATA" "$EXT_DIR"

info "cwd = $IDE_SHELL"
info "exec: $APP_BUNDLE $OPEN_PATH"

if $DEV_MODE; then
    info "VSCODE_DEV=1 (dev 모드)"
    export VSCODE_DEV=1
    export VSCODE_CLI=1
fi

pushd "$IDE_SHELL" > /dev/null
open -a "$APP_BUNDLE" --args \
    "$OPEN_PATH" \
    --user-data-dir="$USER_DATA" \
    --extensions-dir="$EXT_DIR" \
    "${EXTRA_ARGS[@]}"
popd > /dev/null

if $DEV_MODE; then
    unset VSCODE_DEV VSCODE_CLI
fi
