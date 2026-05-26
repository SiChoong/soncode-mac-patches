#!/usr/bin/env bash
# ============================================================
# 손코드 (SonCode) 실행 런처 — macOS
# ------------------------------------------------------------
# 환경변수 (ANTHROPIC_API_KEY 등) 자동 로드 + 실행
# 사용법:
#   bash scripts/launch-soncode.sh
#   bash scripts/launch-soncode.sh /path/to/project
#   bash scripts/launch-soncode.sh --verbose
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SONCODE_APP="/Applications/SonCode.app"
VOID_APP="/Applications/Void.app"
USER_DATA="$ROOT/.fresh-userdata"
EXT_DIR="$USER_DATA/extensions"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

OPEN_PATH=""
VERBOSE=false
for arg in "$@"; do
    case "$arg" in
        --verbose|-v) VERBOSE=true ;;
        --*) ;;
        *) OPEN_PATH="$arg" ;;
    esac
done

# .env.local 파일 로드 (있으면)
ENV_FILE="$ROOT/.env.local"
if [ -f "$ENV_FILE" ]; then
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*([A-Z_]+)[[:space:]]*=[[:space:]]*(.+)[[:space:]]*$ ]]; then
            name="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]//\"/}"
            value="${value//\'/}"
            export "$name=$value"
            $VERBOSE && info "$name 로드됨"
        fi
    done < "$ENV_FILE"
fi

# 앱 탐색: 개발 빌드 → SonCode.app → Void.app
TARGET=""
if [ -d "$ROOT/ide-shell/.build/electron/SonCode.app" ]; then
    TARGET="$ROOT/ide-shell/.build/electron/SonCode.app"
elif [ -d "$SONCODE_APP" ]; then
    TARGET="$SONCODE_APP"
elif [ -d "$VOID_APP" ]; then
    TARGET="$VOID_APP"
    warn "SonCode.app 없음 — Void.app으로 실행합니다."
else
    error "SonCode.app 또는 Void.app을 찾을 수 없습니다.
  install.sh 를 먼저 실행하세요."
fi

mkdir -p "$USER_DATA" "$EXT_DIR"
info "실행: $TARGET"

ARGS=("--user-data-dir=$USER_DATA" "--extensions-dir=$EXT_DIR")
[ -n "$OPEN_PATH" ] && ARGS+=("$OPEN_PATH")

open -a "$TARGET" --args "${ARGS[@]}"
success "SonCode 실행 완료"
