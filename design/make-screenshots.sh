#!/bin/zsh
# README 스크린샷 생성: ./design/make-screenshots.sh → docs/screenshots/*.png
# 앱의 후보 창 코드와 사전 데이터를 그대로 써서 그린다 (실행 중 잠깐 후보 창이 화면에 떴다 사라진다).
set -e
cd "$(dirname "$0")/.."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# 앱 번들 밖에서 쓸 수 있게: 창 접근 허용, 사전 파일 경로를 저장소 기준으로
sed 's/    private let panel: NSPanel/    let panel: NSPanel/' Sources/MHanja/CandidatePanel.swift > "$TMP/CandidatePanel.swift"
sed "s|Bundle.main.url(forResource: \"hanja\", withExtension: \"tsv\")|Optional(URL(fileURLWithPath: \"$PWD/Resources/hanja.tsv\"))|" \
    Sources/MHanja/HanjaDictionary.swift > "$TMP/HanjaDictionary.swift"
cp Sources/MHanja/SymbolTable.swift "$TMP/"
cp design/Screenshots.swift "$TMP/main.swift"

swiftc -O "$TMP"/*.swift -o "$TMP/screenshots"
mkdir -p docs/screenshots
"$TMP/screenshots" docs/screenshots
