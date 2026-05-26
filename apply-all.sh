#!/usr/bin/env bash
# apply-all.sh — SonCode Mac 패치 일괄 적용
# Usage: bash apply-all.sh

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"

SONCODE="/Applications/SonCode.app"

if [ ! -d "$SONCODE" ]; then
    echo "ERROR: SonCode.app not found at $SONCODE"
    echo "SonCode를 먼저 /Applications 에 설치해주세요."
    exit 1
fi

echo "=== [1/3] UI Language Toggle (W19) ==="
python3 "$DIR/patch-toggle3.sh"
echo ""

echo "=== [2/3] Plus Button (W19+) ==="
python3 "$DIR/patch-plus-button.sh"
echo ""

echo "=== [3/3] Fix encoding ==="
python3 "$DIR/fix-children.sh"
echo ""

echo "=== 완료 ==="
echo "SonCode를 완전히 종료한 후 다시 실행하세요."
echo "결과 로그:"
echo "  /tmp/patch-result.txt"
echo "  /tmp/patch-plus-result.txt"
echo "  /tmp/fix-children-result.txt"
