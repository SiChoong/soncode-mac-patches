#!/usr/bin/env bash
# ============================================================
# Hangul AI IDE — Mac 환경 셋업 스크립트
# (Windows setup-env-admin.ps1 Mac 대응판)
# ------------------------------------------------------------
# 사용법: bash scripts/setup-env.sh
#
# 수행 작업:
#   1. Xcode Command Line Tools 확인
#   2. nvm + Node 20 설치/활성화
#   3. npm config 설정 (node-gyp용)
#   4. ide-shell native 모듈 재컴파일
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

echo ""
echo "==== Hangul AI IDE 환경 셋업 (macOS) ===="
echo ""

# 1. Xcode CLT 확인
info "1. Xcode Command Line Tools 확인..."
if ! xcode-select -p &>/dev/null; then
    warn "Xcode CLT 미설치. 설치를 시작합니다..."
    xcode-select --install
    error "설치 완료 후 이 스크립트를 다시 실행하세요."
fi
success "Xcode CLT: $(xcode-select -p)"

# Clang 버전 확인
CLANG_VER=$(clang --version 2>/dev/null | head -1 || echo "미확인")
info "   Clang: $CLANG_VER"

# 2. nvm + Node 20 확인/설치
info "2. Node.js 20 확인..."
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck source=/dev/null
    source "$NVM_DIR/nvm.sh"
    info "   nvm 발견: $(nvm --version)"

    CURRENT_NODE=$(node --version 2>/dev/null || echo "없음")
    info "   현재 Node: $CURRENT_NODE"

    if ! node --version 2>/dev/null | grep -q "v20\."; then
        info "   Node 20 설치/활성화 중..."
        nvm install 20
        nvm use 20
        nvm alias default 20
    fi
    success "Node $(node --version) 활성화됨"
elif command -v node &>/dev/null; then
    NODE_VER=$(node --version)
    success "Node: $NODE_VER (시스템 설치)"
    if ! echo "$NODE_VER" | grep -q "v20\."; then
        warn "Node 20 권장. 현재: $NODE_VER"
        warn "  Homebrew: brew install nvm && nvm install 20"
    fi
else
    warn "Node.js 미설치"
    if command -v brew &>/dev/null; then
        info "   Homebrew로 nvm 설치 중..."
        brew install nvm
        mkdir -p "$NVM_DIR"
        # shellcheck source=/dev/null
        source "$(brew --prefix nvm)/nvm.sh"
        nvm install 20
        nvm use 20
        # .zshrc에 nvm 설정 추가
        if ! grep -q "NVM_DIR" "$HOME/.zshrc" 2>/dev/null; then
            {
                echo ""
                echo '# nvm'
                echo "export NVM_DIR=\"\$HOME/.nvm\""
                echo "[ -s \"\$(brew --prefix nvm)/nvm.sh\" ] && source \"\$(brew --prefix nvm)/nvm.sh\""
            } >> "$HOME/.zshrc"
        fi
        success "Node $(node --version) 설치 완료"
    else
        warn "Homebrew 미설치. https://brew.sh 에서 설치 후 재시도하세요."
        error "Node.js 설치 불가"
    fi
fi

# 3. npm config 설정
info "3. npm config 설정..."
npm config set python "$(command -v python3)"
# macOS는 MSVS 불필요 — Xcode CLT 사용
success "npm config 완료 (python=$(command -v python3))"

# 4. ide-shell native 모듈 재컴파일
if [ -d "$IDE_SHELL" ]; then
    info "4. native 모듈 재컴파일 (5-15분 소요)..."
    pushd "$IDE_SHELL" > /dev/null
    if npm rebuild --loglevel=warn; then
        success "npm rebuild 완료"
    else
        warn "일부 모듈 빌드 실패 — node-pty 관련 이슈일 수 있음."
    fi
    popd > /dev/null
else
    warn "4. ide-shell 미발견: $IDE_SHELL"
    warn "   scripts/bootstrap.sh 를 먼저 실행하세요."
fi

echo ""
echo "==== 셋업 완료 ===="
echo -e "다음: ${BLUE}bash scripts/first-build.sh${NC} 로 첫 빌드 시도"
