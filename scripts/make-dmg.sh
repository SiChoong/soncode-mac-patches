#!/usr/bin/env bash
# ============================================================
# make-dmg.sh — SonCode macOS DMG 패키지 생성
# (Windows make-portable-zip.ps1 Mac 대응판)
# ------------------------------------------------------------
# 입력:
#   - /Applications/SonCode.app  (패치 완료 상태)
#   - 또는 ide-shell/.build/electron/SonCode.app  (개발 빌드)
#
# 출력:
#   - artifacts/SonCode-{ver}-{date}.dmg
#
# 사용:
#   bash scripts/make-dmg.sh
#   bash scripts/make-dmg.sh --source /path/to/SonCode.app
#   bash scripts/make-dmg.sh --zip   # DMG 대신 ZIP 생성
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[dmg]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SONCODE_APP="/Applications/SonCode.app"
VOID_APP="/Applications/Void.app"
OUT_DIR="$ROOT/artifacts"
SOURCE=""
ZIP_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source|-s) SOURCE="$2"; shift 2 ;;
        --outdir|-o) OUT_DIR="$2"; shift 2 ;;
        --zip|-z)    ZIP_MODE=true; shift ;;
        *) shift ;;
    esac
done

# 소스 .app 자동 탐색: 개발 빌드 → SonCode.app → Void.app
if [ -z "$SOURCE" ]; then
    for candidate in \
        "$ROOT/ide-shell/.build/electron/SonCode.app" \
        "$SONCODE_APP" \
        "$VOID_APP"; do
        if [ -d "$candidate" ]; then
            SOURCE="$candidate"
            break
        fi
    done
fi

[ -d "$SOURCE" ] || error "소스 .app을 찾을 수 없습니다. --source 옵션으로 경로를 지정하세요."
info "소스: $SOURCE"

# product.json에서 버전 추출
PRODUCT_JSON=""
for p in "$SOURCE/Contents/Resources/app/product.json" \
          "$ROOT/ide-shell/product.json"; do
    [ -f "$p" ] && PRODUCT_JSON="$p" && break
done

VER="0.1.0"
if [ -n "$PRODUCT_JSON" ]; then
    VER=$(python3 -c "import json,sys; d=json.load(open('$PRODUCT_JSON')); \
        print(d.get('hangulVersion', d.get('voidVersion', d.get('version', '0.1.0'))))" 2>/dev/null || echo "0.1.0")
fi

DATE_STAMP=$(date +%Y%m%d-%H%M)
mkdir -p "$OUT_DIR"

APP_NAME=$(basename "$SOURCE" .app)

if $ZIP_MODE; then
    # ---- ZIP 포터블 패키지 ----
    ZIP_NAME="${APP_NAME}-portable-${VER}-${DATE_STAMP}.zip"
    ZIP_PATH="$OUT_DIR/$ZIP_NAME"
    STAGING=$(mktemp -d /tmp/soncode-stage-XXXXXX)
    trap 'rm -rf "$STAGING"' EXIT

    APP_STAGE="$STAGING/${APP_NAME}.app"
    info "스테이징 복사..."
    cp -R "$SOURCE" "$APP_STAGE"

    # 포터블 런처 동봉
    LAUNCHER="$REPO_ROOT/scripts/portable-launcher.sh"
    [ -f "$LAUNCHER" ] && cp "$LAUNCHER" "$STAGING/SonCode-Portable.sh" && chmod +x "$STAGING/SonCode-Portable.sh"

    cat > "$STAGING/README-portable.txt" << EOF
SonCode (손코드) — macOS 포터블 패키지
========================================
버전: $VER
생성일: $(date '+%Y-%m-%d %H:%M')

[실행]
  SonCode-Portable.sh 를 터미널에서 실행하면
  같은 폴더의 soncode-portable/ 에 모든 설정/확장이 저장됩니다.

[직접 실행]
  open -a ${APP_NAME}.app --args --user-data-dir=./soncode-portable

[제거]
  폴더 삭제만 하면 완전 제거됩니다.
EOF

    info "ZIP 압축 중..."
    (cd "$STAGING" && zip -qr "$ZIP_PATH" .)
    SIZE_MB=$(du -m "$ZIP_PATH" | cut -f1)
    success "완료: $ZIP_NAME  (${SIZE_MB} MB)"
    echo "$ZIP_PATH"

else
    # ---- DMG 패키지 ----
    DMG_NAME="${APP_NAME}-${VER}-${DATE_STAMP}.dmg"
    DMG_PATH="$OUT_DIR/$DMG_NAME"
    STAGING=$(mktemp -d /tmp/soncode-dmg-XXXXXX)
    trap 'rm -rf "$STAGING"' EXIT

    info "스테이징 복사..."
    cp -R "$SOURCE" "$STAGING/"
    # /Applications 심볼릭 링크 (드래그 설치용)
    ln -s /Applications "$STAGING/Applications"

    # 배경 이미지가 있으면 추가
    BG_IMG="$ROOT/branding/png/soncode-256.png"
    if [ -f "$BG_IMG" ]; then
        mkdir -p "$STAGING/.background"
        cp "$BG_IMG" "$STAGING/.background/background.png"
    fi

    info "DMG 생성 중 → $DMG_NAME"
    hdiutil create \
        -volname "SonCode $VER" \
        -srcfolder "$STAGING" \
        -ov \
        -format UDZO \
        -imagekey zlib-level=9 \
        "$DMG_PATH"

    # 쿼런틴 제거 (배포 전 서명 없을 때)
    xattr -dr com.apple.quarantine "$DMG_PATH" 2>/dev/null || true

    SIZE_MB=$(du -m "$DMG_PATH" | cut -f1)
    success "완료: $DMG_NAME  (${SIZE_MB} MB)"
    echo "$DMG_PATH"

    # SHA256 체크섬
    SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
    echo "$SHA256  $DMG_NAME" > "${DMG_PATH}.sha256"
    info "SHA256: $SHA256"

    # JSON 매니페스트
    MANIFEST="$ROOT/artifacts/dmg-manifest.json"
    python3 - << PYEOF
import json
manifest = {
    "dmgPath": "$DMG_PATH",
    "dmgName": "$DMG_NAME",
    "sizeMB": $SIZE_MB,
    "source": "$SOURCE",
    "version": "$VER",
    "sha256": "$SHA256",
    "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
with open("$MANIFEST", "w") as f:
    json.dump(manifest, f, indent=2, ensure_ascii=False)
print(f"[dmg] 매니페스트: $MANIFEST")
PYEOF
fi
