#!/usr/bin/env bash
# ============================================================
# 손코드 Anthropic 자동 설정 + 깨끗한 재시작 — macOS
# 사용: bash scripts/setup-anthropic-quick.sh [API_KEY]
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SONCODE_APP="/Applications/SonCode.app"
VOID_APP="/Applications/Void.app"
FRESH_DIR="$ROOT/.fresh-userdata"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║   손코드 Anthropic 자동 설정 (macOS) ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

API_KEY="${1:-}"
if [ -z "$API_KEY" ]; then
    echo -n "Anthropic API Key를 입력하세요 (sk-ant-...): "
    read -r API_KEY
fi
[ -z "$API_KEY" ] && error "API Key가 입력되지 않았습니다."

# 1. SonCode 프로세스 종료
info "1. SonCode 종료..."
pkill -x "SonCode" 2>/dev/null || true
pkill -x "Electron" 2>/dev/null || true
sleep 2
success "   종료 완료"

# 2. fresh-userdata 초기화
[ -d "$FRESH_DIR" ] && rm -rf "$FRESH_DIR"
mkdir -p "$FRESH_DIR/extensions"
success "2. Fresh user data 초기화 완료"

# 3. 환경변수 설정 + .env.local 저장
export CLAUDE_CODE_OAUTH_TOKEN="$API_KEY"
export ANTHROPIC_AUTH_TOKEN="$API_KEY"
export ANTHROPIC_API_KEY="$API_KEY"
cat > "$ROOT/.env.local" << EOF
ANTHROPIC_API_KEY=$API_KEY
ANTHROPIC_AUTH_TOKEN=$API_KEY
CLAUDE_CODE_OAUTH_TOKEN=$API_KEY
EOF
success "3. 환경변수 설정 + .env.local 저장 완료"

# 4. SonCode 실행 (SonCode.app → Void.app 폴백)
info "4. SonCode 실행..."
TARGET=""
if [ -d "$SONCODE_APP" ]; then
    TARGET="$SONCODE_APP"
elif [ -d "$VOID_APP" ]; then
    TARGET="$VOID_APP"
    warn "SonCode.app 없음 — Void.app으로 실행합니다."
else
    error "SonCode.app 또는 Void.app을 찾을 수 없습니다.
  install.sh 를 먼저 실행하세요."
fi

open -a "$TARGET" --args \
    --user-data-dir="$FRESH_DIR" \
    --extensions-dir="$FRESH_DIR/extensions"

sleep 5

# 실행 확인
if pgrep -f "SonCode\|Void" > /dev/null 2>&1; then
    echo ""
    success "SonCode 실행 확인"
    echo ""
    echo -e "${YELLOW}다음 단계:${NC}"
    echo "  1. '시작하기' 클릭"
    echo "  2. 'AI 제공자 추가' 화면에서 'Paid' 탭 선택"
    echo "  3. Anthropic 입력란에 키 붙여넣기:"
    echo -e "     ${BLUE}$API_KEY${NC}"
    echo "  4. '다음' 클릭"
    echo "  5. 채팅 모델: claude-3-5-haiku-latest 선택"
else
    warn "SonCode 프로세스 미확인 — 앱이 백그라운드에서 시작 중일 수 있습니다."
fi
