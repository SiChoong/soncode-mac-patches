#!/usr/bin/env bash
# ============================================================
# 손코드 (SonCode) 통합 AI CLI 번들 설치 / 업데이트 스크립트 — macOS
# ------------------------------------------------------------
# 설치/업데이트:  bash scripts/bundle-cli.sh
# 강제 재설치:    bash scripts/bundle-cli.sh --force
# 검증만:         bash scripts/bundle-cli.sh --check
#
# 설치 위치: ~/Library/Application Support/SonCode/cli/
#   - node_modules/@anthropic-ai/claude-code  → claude
#   - node_modules/@openai/codex              → codex
#   - node_modules/@google/gemini-cli         → gemini
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[손코드 CLI]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

FORCE=false
CHECK_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --force|-f) FORCE=true ;;
        --check|-c) CHECK_ONLY=true ;;
    esac
done

CLI_ROOT="$HOME/Library/Application Support/SonCode/cli"
CLI_BIN="$CLI_ROOT/node_modules/.bin"

check_binaries() {
    local all_ok=true
    for tool in claude codex gemini; do
        local bin="$CLI_BIN/$tool"
        if [ -x "$bin" ]; then
            local ver
            ver=$("$bin" --version 2>&1 | head -1) || ver="(버전 확인 실패)"
            echo -e "  ${GREEN}[OK]${NC}  $tool => $ver"
        else
            echo -e "  ${RED}[X]${NC}   $tool => 미설치"
            all_ok=false
        fi
    done
    $all_ok
}

if $CHECK_ONLY; then
    info "설치 상태 확인"
    check_binaries || true
    exit 0
fi

# Node.js 확인
if ! command -v node &>/dev/null; then
    error "Node.js가 설치되어 있지 않습니다. https://nodejs.org/ 에서 LTS 설치 필요."
fi
info "Node $(node --version)  npm $(npm --version)"

# 디렉토리 준비
mkdir -p "$CLI_ROOT"
info "설치 경로: $CLI_ROOT"

# package.json 작성
cat > "$CLI_ROOT/package.json" << 'EOF'
{
  "name": "soncode-cli-bundle",
  "version": "0.1.0",
  "private": true,
  "description": "손코드 통합 AI CLI 번들 (Claude / Codex / Gemini)",
  "dependencies": {
    "@anthropic-ai/claude-code": "latest",
    "@openai/codex": "latest",
    "@google/gemini-cli": "latest"
  }
}
EOF

# 강제 재설치 시 node_modules 제거
if $FORCE && [ -d "$CLI_ROOT/node_modules" ]; then
    info "기존 node_modules 제거 (--force)"
    rm -rf "$CLI_ROOT/node_modules" "$CLI_ROOT/package-lock.json"
fi

# npm install
info "npm install 실행..."
pushd "$CLI_ROOT" > /dev/null
npm install --no-audit --no-fund --loglevel=warn
popd > /dev/null

# PATH 등록 (~/.zshrc 및 ~/.bash_profile)
EXPORT_LINE="export PATH=\"\$PATH:$CLI_BIN\""
for RC in "$HOME/.zshrc" "$HOME/.bash_profile"; do
    if [ -f "$RC" ] || [ "$RC" = "$HOME/.zshrc" ]; then
        if ! grep -qF "$CLI_BIN" "$RC" 2>/dev/null; then
            echo "" >> "$RC"
            echo "# 손코드 AI CLI" >> "$RC"
            echo "$EXPORT_LINE" >> "$RC"
            success "PATH 등록: $RC"
        else
            warn "PATH 이미 등록됨: $RC"
        fi
    fi
done

# 현재 세션 PATH에도 추가
export PATH="$PATH:$CLI_BIN"

# 검증
echo ""
info "설치 검증"
if check_binaries; then
    echo ""
    success "새 터미널/SonCode 재시작 후 즉시 사용 가능합니다."
else
    warn "일부 CLI 검증 실패 — 위 메시지 확인 후 --force 로 재시도하세요."
    exit 1
fi
