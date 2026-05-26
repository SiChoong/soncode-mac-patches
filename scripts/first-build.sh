#!/usr/bin/env bash
# ============================================================
# Hangul AI IDE — 첫 빌드 스크립트 (macOS)
# 사용법: bash scripts/first-build.sh
#         (setup-env.sh 완료 후 실행)
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IDE_SHELL="$ROOT/ide-shell"
LOGS_DIR="$ROOT/logs"
mkdir -p "$LOGS_DIR"

echo ""
echo "==== Hangul AI IDE 첫 빌드 (macOS) ===="
echo ""

# Node 버전 확인
NODE_VER=$(node --version 2>/dev/null || echo "없음")
info "Node 버전: $NODE_VER"
if ! echo "$NODE_VER" | grep -q "v20\."; then
    warn "Node 20 권장. nvm use 20 후 새 세션에서 재시도"
fi

[ -d "$IDE_SHELL" ] || error "ide-shell 미발견: $IDE_SHELL\n  bootstrap.sh 를 먼저 실행하세요."

pushd "$IDE_SHELL" > /dev/null

# 1. React UI 빌드
info "[1/3] React UI 빌드 (npm run buildreact)..."
LOG_REACT="$LOGS_DIR/first-build-react.log"
if npm run buildreact 2>&1 | tee "$LOG_REACT"; then
    success "React UI 빌드 완료"
else
    error "buildreact 실패. 로그: $LOG_REACT"
fi

# 2. TypeScript 컴파일
info "[2/3] TypeScript 컴파일 (npm run compile)..."
LOG_COMPILE="$LOGS_DIR/first-build-compile.log"
if npm run compile 2>&1 | tee "$LOG_COMPILE"; then
    success "컴파일 완료"
else
    warn "compile 일부 실패 — 로그 확인: $LOG_COMPILE"
    warn "  (TypeScript 타입 오류인 경우 실행 가능할 수 있음)"
fi

popd > /dev/null

# 3. 실행 안내
echo ""
info "[3/3] 실행 방법 안내"
echo -e "  watch 모드:    ${BLUE}cd ide-shell && npm run watch${NC}  (별도 터미널)"
echo -e "  앱 실행:       ${BLUE}bash scripts/hangul.sh${NC}"
echo -e "  단위 테스트:    ${BLUE}cd ide-shell && npm run test-node${NC}"
echo ""
echo "==== 빌드 작업 종료 ===="
