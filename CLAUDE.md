# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

SonCode Mac 패치 모음 — Void 에디터 기반의 SonCode macOS 앱(`/Applications/SonCode.app`)의 번들된 JS 파일을 직접 텍스트 치환 방식으로 패치합니다. Windows용 `.ps1` 스크립트를 Mac용으로 포팅한 버전입니다.

## 패치 적용 명령

```bash
# 전체 패치 일괄 적용 (권장)
sudo bash install.sh

# 개별 패치 적용 (SonCode.app이 이미 설치된 경우)
bash apply-all.sh

# 각 패치 단독 실행
python3 patch-toggle3.sh       # UI 언어 토글
python3 patch-plus-button.sh   # 채팅 + 버튼
python3 fix-children.sh        # 인코딩 깨짐 복구
```

## 패치 결과 확인

```bash
cat /tmp/patch-result.txt
cat /tmp/patch-plus-result.txt
cat /tmp/fix-children-result.txt
```

## 검증 마커 (패치 성공 기준)

`/Applications/SonCode.app/Contents/Resources/app/out/vs/workbench/workbench.desktop.main.js` 내에 다음 세 문자열이 존재해야 합니다:
- `korean-ag.toggleUiLocale`
- `korean-ag.plusButton`
- `function PlusButtonW19`

## 아키텍처

### 패치 대상 파일

모든 스크립트는 동일한 두 파일을 수정합니다:
- **`workbench.desktop.main.js`** — Void/SonCode의 번들된 UI 코드 (수 MB 단위의 minified JS). 텍스트 치환으로 직접 수정.
- **`product.json`** — 앱의 무결성 체크섬(`checksums` 필드)을 보관. 패치 후 SHA-256을 재계산하여 갱신하지 않으면 앱이 시작되지 않음.

### 체크섬 갱신 메커니즘

모든 스크립트는 `update_checksum()` 함수를 공통으로 포함합니다:
1. 수정된 `workbench.desktop.main.js`를 UTF-8로 인코딩
2. SHA-256 해시를 계산 → URL-safe Base64(패딩 제거)로 변환
3. `product.json`의 기존 체크섬 값을 새 값으로 교체

### 패치 방식

- 모든 패치는 **정확한 문자열 앵커**를 찾아 `str.replace(..., 1)`로 1회 치환
- 앵커를 찾지 못하면 에러를 출력하고 `sys.exit(1)` (버전 불일치 신호)
- 이미 패치된 경우 마커 문자열(`korean-ag.toggleUiLocale` 등)로 감지하여 스킵
- CRLF → LF 정규화를 먼저 수행 (`content.replace("\r\n", "\n")`)

### install.sh vs apply-all.sh

| | `install.sh` | `apply-all.sh` |
|---|---|---|
| 권한 | `sudo` 필요 (자동 재실행) | 불필요 |
| Void 자동 설치 | GitHub Releases API로 최신 DMG 다운로드 | 없음 |
| 패치 방식 | Python heredoc으로 3개 패치 인라인 처리 | 각 `.sh` 파일을 `python3`로 순차 호출 |
| 대상 앱 | SonCode.app → Void.app 순서로 폴백 | SonCode.app 고정 |

### 스크립트 파일 명명 규칙

`.sh` 확장자이지만 `patch-toggle3.sh`, `patch-plus-button.sh`, `fix-children.sh`는 실제로 Python 3 스크립트입니다 (`#!/usr/bin/env python3`). `apply-all.sh`가 `python3`로 직접 호출합니다.

## 버전 호환성 주의사항

패치 앵커 문자열은 Void W19(특정 빌드 버전) 기준입니다. SonCode/Void가 업데이트되면 다음 모듈 참조 이름이 바뀔 수 있습니다:
- `import_react83`, `import_react163`
- `import_jsx_runtime123`
- `VoidChatArea2`, `VoidInputBox23` (함수명 `X23`)

이 이름들이 변경되면 `patch-plus-button.sh`의 모든 앵커를 새 버전에 맞게 업데이트해야 합니다.
