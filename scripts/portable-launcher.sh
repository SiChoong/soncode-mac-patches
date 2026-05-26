#!/usr/bin/env bash
# ============================================================
# SonCode — macOS 포터블 런처
# (Windows portable-launcher.bat Mac 대응판)
# ------------------------------------------------------------
# 이 스크립트와 같은 폴더의 SonCode.app에서 실행하며,
# ./soncode-portable/ 에 모든 user data를 저장합니다.
# USB/외장 드라이브에서 그대로 실행 가능합니다.
#
# 사용법:
#   1. SonCode.app 과 함께 이 파일을 USB에 복사
#   2. terminal: bash SonCode-Portable.sh
#   3. 또는: chmod +x SonCode-Portable.sh && ./SonCode-Portable.sh
# ============================================================

# 이 스크립트가 있는 디렉토리
BASE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

PORTABLE_DATA="$BASE/soncode-portable"
PORTABLE_EXT="$BASE/soncode-portable/extensions"

mkdir -p "$PORTABLE_DATA" "$PORTABLE_EXT"

echo "[portable] user-data: $PORTABLE_DATA"

# .app 번들 탐색
APP_BUNDLE=""
for candidate in \
    "$BASE/SonCode.app" \
    "$BASE/Void.app" \
    "$BASE/SonCode-x64/SonCode.app" \
    "$BASE/SonCode.app/Contents/MacOS/Electron"; do
    if [ -d "$candidate" ] || [ -f "$candidate" ]; then
        APP_BUNDLE="$candidate"
        break
    fi
done

if [ -z "$APP_BUNDLE" ]; then
    echo "[portable] ERROR: SonCode.app을 찾을 수 없습니다."
    echo "           이 스크립트를 SonCode.app과 같은 폴더에 두세요."
    exit 1
fi

echo "[portable] 실행: $APP_BUNDLE"

if [[ "$APP_BUNDLE" == *.app ]]; then
    open -a "$APP_BUNDLE" --args \
        --user-data-dir="$PORTABLE_DATA" \
        --extensions-dir="$PORTABLE_EXT" \
        "$@"
else
    "$APP_BUNDLE" \
        --user-data-dir="$PORTABLE_DATA" \
        --extensions-dir="$PORTABLE_EXT" \
        "$@" &
fi
