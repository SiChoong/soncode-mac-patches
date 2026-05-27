# SonCode Mac 패치

Void Editor 기반의 SonCode macOS 앱을 한국어화 + AI 기능 패치하는 스크립트 모음입니다.  
Windows용 `.ps1` 스크립트를 Mac용 `bash`/`python3`으로 포팅한 버전입니다.

---

## ⚡ 빠른 설치 (원라이너)

터미널에서 한 줄로 설치:

```bash
curl -fsSL https://raw.githubusercontent.com/SiChoong/soncode-mac-patches/main/install.sh | bash
```

> SonCode.app이 없으면 Void를 자동으로 다운로드한 뒤 패치를 적용합니다.

---

## 전제 조건

- macOS 12 이상
- Python 3 (macOS 기본 내장)
- SonCode.app 또는 Void.app이 `/Applications`에 설치되어 있거나, 자동 설치 허용

---

## 설치 방법

### 방법 1 — curl 원라이너 (권장)

```bash
curl -fsSL https://raw.githubusercontent.com/SiChoong/soncode-mac-patches/main/install.sh | bash
```

### 방법 2 — git clone 후 실행

```bash
git clone https://github.com/SiChoong/soncode-mac-patches.git
cd soncode-mac-patches
sudo bash install.sh
```

### 방법 3 — SonCode.app이 이미 있는 경우 (sudo 불필요)

```bash
bash apply-all.sh
```

---

## 패치 목록

| # | 파일 | 기능 |
|---|------|------|
| 1 | `patch-toggle3.sh` | UI 언어 토글 명령 추가 (`korean-ag.toggleUiLocale`) |
| 2 | `patch-plus-button.sh` | 채팅 + 버튼 (파일/폴더/이미지/슬래시/커넥트/플러그인) |
| 3 | `fix-children.sh` | + 버튼 패치 후 인코딩 깨짐 복구 |

---

## 보조 스크립트 (`scripts/`)

| 파일 | 기능 |
|------|------|
| `bundle-cli.sh` | Claude / Codex / Gemini CLI 일괄 설치 + PATH 등록 |
| `launch-soncode.sh` | `.env.local` 로드 후 SonCode 실행 |
| `setup-anthropic-quick.sh` | Anthropic API Key 설정 + 앱 재시작 |
| `make-dmg.sh` | 패치 완료된 앱으로 DMG 또는 ZIP 패키지 생성 |
| `create-alias.sh` | 바탕화면 별칭 + Dock 등록 |
| `portable-launcher.sh` | USB 포터블 실행 |
| `bootstrap.sh` | 소스 빌드용 개발 환경 셋업 (Xcode CLT + Node 20) |
| `setup-env.sh` | native 모듈 재컴파일 (소스 빌드용) |
| `first-build.sh` | 소스 첫 빌드 (buildreact → compile) |
| `hangul.sh` | 소스 빌드 앱 안전 런처 (cwd=ide-shell 보정) |

---

## 결과 확인

```bash
cat /tmp/patch-result.txt
cat /tmp/patch-plus-result.txt
cat /tmp/fix-children-result.txt
```

## 검증 마커

패치가 정상 적용되면 `workbench.desktop.main.js` 내에 다음이 존재합니다:

- `korean-ag.toggleUiLocale`
- `korean-ag.plusButton`
- `function PlusButtonW19`

---

## Windows와의 차이점

| 항목 | Windows (.ps1) | Mac (.sh / .py) |
|------|---------------|-----------------|
| 설치 경로 | `C:\Program Files\SonCode\` | `/Applications/SonCode.app/` |
| 패키징 | InnoSetup `.exe` | `hdiutil` DMG |
| 바로가기 | `.lnk` (WScript) | Finder 별칭 + Dock |
| CLI 경로 | `%LOCALAPPDATA%\SonCode\cli\` | `~/Library/Application Support/SonCode/cli/` |
| PATH 등록 | 레지스트리 | `~/.zshrc` / `~/.bash_profile` |
| SHA-256 | .NET `SHA256` | Python3 `hashlib` |
