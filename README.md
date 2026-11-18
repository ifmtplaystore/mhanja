# MHanja

macOS 메뉴바 앱. 윈도우 한글 입력기처럼 **자음 + 트리거 키**로 특수문자를, **한글 + 트리거 키**로 한자를 입력합니다.

## 사용법

macOS 기본 입력기(두벌식)를 그대로 쓰면서, 글자를 입력한 직후 트리거 키(기본: 오른쪽 Option)를 눌렀다 뗍니다.

| 입력 | 결과 |
|---|---|
| 자음 + 트리거 키 (예: `ㅁ`) | 특수문자 목록 (`※ ☆ ★ → …`), 윈도우 KS X 1001 배열과 같음 |
| 한글 음절 + 트리거 키 (예: `한`) | 한자 목록과 훈 (`韓 나라 이름`, `漢 한수` …) |

목록에서:

- `↑` `↓` 선택, `←` `→` 페이지, 숫자 `1`–`9` 바로 선택, `Enter` 입력, `Esc` 닫기
- `Tab` 전체 보기 — 모든 문자를 격자로 펼칩니다. 한자는 기본 목록에 KS X 1001 한자만 보이고, 전체 보기에서 나머지 한자까지 보입니다.

메뉴바 아이콘에서 사용 여부, 트리거 키(오른쪽 Option / Command / Control), 로그인 시 실행을 설정할 수 있습니다.

처음 실행하면 **시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용**에서 MHanja를 허용해야 합니다. 키 입력 감지와 커서 위치 확인에 필요합니다.

## 설치

[Releases](../../releases)에서 `MHanja.dmg`를 받아 열고, MHanja를 응용 프로그램 폴더로 끌어다 놓습니다.

Apple 공증을 받지 않은 앱이라 처음 실행하면 macOS가 막습니다. 다음 순서로 한 번만 허용하면 됩니다.

1. MHanja를 실행합니다 → "열 수 없음" 경고가 뜨면 **완료**(또는 취소)를 누릅니다.
2. **시스템 설정 > 개인정보 보호 및 보안**을 열고, 아래쪽의 "MHanja이(가) 차단되었습니다" 옆 **그래도 열기**를 누릅니다.
3. 다시 확인 창에서 **열기**를 누릅니다. (macOS 14 이하는 앱을 우클릭 > **열기**로도 됩니다.)

요구 사항: macOS 13 이상

## 빌드

```sh
./build.sh          # → build/MHanja.app, build/MHanja.dmg
```

- Swift 5.9 이상 (Xcode 또는 Command Line Tools)
- **DMG 꾸미기 (선택):** 배경 그림과 큰 아이콘 창은 [dmgbuild](https://github.com/dmgbuild/dmgbuild)로 만듭니다. 없으면 꾸미지 않은 DMG를 만듭니다.
  ```sh
  python3 -m venv .build/dmgbuild-venv && .build/dmgbuild-venv/bin/pip install dmgbuild
  ```
- **서명:** `SIGN_IDENTITY` 환경 변수 → 키체인의 `MHanja Local Signing` 인증서 → ad-hoc 순으로 고릅니다.
  ad-hoc 서명은 빌드할 때마다 바뀌어 손쉬운 사용 권한을 다시 허용해야 하므로, 개발할 때는 코드 서명용 자체 서명 인증서(`MHanja Local Signing`)를 키체인에 만들어 두면 편합니다.

## 프로젝트 구성

```text
Sources/MHanja/      앱 소스
  KeyMonitor.swift       전역 키 감시, 트리거 키 감지
  HangulTracker.swift    입력 중인 자음/음절 추적
  CandidatePanel.swift   후보 목록 창 (목록·격자)
  HanjaDictionary.swift  한자 사전 (기본/전체 목록, 훈 추출)
  SymbolTable.swift      자음별 특수문자 표
  TextInserter.swift     글자 바꿔 넣기, 커서 위치 찾기
Resources/           한자 사전 데이터, 앱 아이콘
design/              아이콘·DMG 배경 원본과 생성 코드
build.sh             앱 번들·DMG 빌드
```

## 라이선스

MIT License — [LICENSE](LICENSE)

한자 사전 데이터(`Resources/hanja.tsv`)는 [libhangul](https://github.com/libhangul/libhangul)의 `data/hanja/hanja.txt`를 가공한 것으로, BSD 3-Clause 라이선스를 따릅니다 — [Resources/hanja-LICENSE.txt](Resources/hanja-LICENSE.txt)

문의/건의: ifmtplaystore@gmail.com
