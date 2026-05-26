#!/usr/bin/env bash
# =============================================================================
# Korean AntiGravity (Hangul AI IDE) — Mac 부트스트랩 스크립트
# =============================================================================
# 목적: ide-shell (Void fork) 빌드 환경을 초기 셋업한다.
# 사용법: bash scripts/bootstrap.sh
# 전제: macOS 12+, Xcode Command Line Tools, Homebrew 권장
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "=== Hangul AI IDE 부트스트랩 시작 (macOS) ==="
echo ""

# ---- 1. Xcode Command Line Tools 확인 ----
info "[1/4] Xcode CLT 확인..."
if ! xcode-select -p &>/dev/null; then
    warn "Xcode Command Line Tools 미설치. 설치를 시작합니다..."
    xcode-select --install
    echo "  설치 완료 후 이 스크립트를 다시 실행하세요."
    exit 0
fi
success "Xcode CLT: $(xcode-select -p)"

# ---- 2. Node.js 버전 확인 ----
info "[2/4] Node.js 버전 확인..."
if ! command -v node &>/dev/null; then
    warn "Node.js 미설치."
    if command -v brew &>/dev/null; then
        info "  Homebrew로 nvm 설치를 권장합니다:"
        echo "  brew install nvm"
        echo "  nvm install 20"
        echo "  nvm use 20"
    else
        echo "  https://nodejs.org 에서 LTS(20.x) 설치 후 재실행하세요."
    fi
    exit 1
fi

NODE_VERSION=$(node --version)
NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/v\([0-9]*\).*/\1/')
success "Node.js: $NODE_VERSION"
if [ "$NODE_MAJOR" -lt 20 ]; then
    warn "Node.js >= 20 권장. 현재: $NODE_VERSION"
    warn "  nvm install 20 && nvm use 20"
fi

# ---- 3. ide-shell 디렉토리 확인 ----
IDE_SHELL="$ROOT/ide-shell"

info "[3/4] ide-shell 디렉토리 확인..."
if [ ! -f "$IDE_SHELL/package.json" ]; then
    error "ide-shell/package.json 이 없습니다. Void fork가 복사되지 않았습니다.
  수동 복구: git clone https://github.com/voideditor/void.git ide-shell"
fi
success "ide-shell 위치: $IDE_SHELL"

# ---- 4. npm install ----
info "[4/4] npm install 실행 (수 분 소요)..."
pushd "$IDE_SHELL" > /dev/null
npm install
popd > /dev/null
success "npm install 완료"

echo ""
echo -e "${GREEN}다음 명령으로 개발 빌드를 실행하세요:${NC}"
echo ""
echo "    cd ide-shell"
echo "    npm run buildreact      # React UI 번들 1회 빌드"
echo "    npm run watch           # TypeScript watch 모드 시작"
echo ""
echo "별도 터미널에서:"
echo "    bash scripts/hangul.sh  # Hangul AI IDE 실행 (macOS)"
echo ""
echo "=== 부트스트랩 완료 ==="
