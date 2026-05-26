#!/usr/bin/env bash
# apply-all.sh — SonCode Mac 패치 일괄 적용
# SonCode.app 또는 Void.app이 /Applications에 설치된 경우 실행
# Usage: bash apply-all.sh

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# 대상 앱 탐색
if [ -d "/Applications/SonCode.app" ]; then
    TARGET="/Applications/SonCode.app"
    info "SonCode.app 발견"
elif [ -d "/Applications/Void.app" ]; then
    TARGET="/Applications/Void.app"
    warn "SonCode.app 없음 — Void.app에 패치 적용"
else
    error "SonCode.app / Void.app을 찾을 수 없습니다. /Applications에 먼저 설치해주세요."
fi

echo ""
echo "  ╔══════════════════════════════════╗"
echo "  ║    SonCode 패치 일괄 적용        ║"
echo "  ╚══════════════════════════════════╝"
echo ""

info "[1/3] UI 언어 토글 패치..."
python3 "$DIR/patch-toggle3.sh"
echo ""

info "[2/3] 채팅 + 버튼 패치..."
python3 "$DIR/patch-plus-button.sh"
echo ""

info "[3/3] 인코딩 복구 (필요시)..."
python3 "$DIR/fix-children.sh"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
success "패치 완료! $TARGET"
echo ""
echo "  앱을 완전히 종료한 후 다시 실행하세요."
echo ""
echo "  결과 로그:"
echo "    cat /tmp/patch-result.txt"
echo "    cat /tmp/patch-plus-result.txt"
echo "    cat /tmp/fix-children-result.txt"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
