#!/bin/zsh
# MHanja.app 빌드: ./build.sh  →  build/MHanja.app
set -e
cd "$(dirname "$0")"

swift build -c release
APP=build/MHanja.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MHanja "$APP/Contents/MacOS/MHanja"
cp Resources/* "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.ifmt.mhanja</string>
    <key>CFBundleName</key><string>MHanja</string>
    <key>CFBundleDisplayName</key><string>MHanja</string>
    <key>CFBundleExecutable</key><string>MHanja</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>© 2026 IFMT</string>
</dict>
</plist>
EOF

# 서명: SIGN_IDENTITY > 키체인의 "MHanja Local Signing"(자체 서명) > ad-hoc.
# 고정 인증서로 서명해야 다시 빌드해도 손쉬운 사용 권한이 유지된다 (ad-hoc은 빌드마다 바뀜).
LOCAL_IDENTITY="MHanja Local Signing"
if [[ -z "$SIGN_IDENTITY" ]] && security find-identity -p codesigning | grep -q "\"$LOCAL_IDENTITY\""; then
    SIGN_IDENTITY="$LOCAL_IDENTITY"
fi
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
echo "서명: ${SIGN_IDENTITY:-ad-hoc}"
echo "완료: $APP"

# 배포용 DMG: 앱 + /Applications 바로가기.
# dmgbuild가 있으면 배경 그림·큰 아이콘 창으로 꾸민다 (design/dmg-settings.py).
DMG=build/MHanja.dmg
rm -f "$DMG"
DMGBUILD=.build/dmgbuild-venv/bin/dmgbuild
if [[ -x "$DMGBUILD" ]]; then
    BG=build/dmg-background.tiff
    tiffutil -cathidpicheck design/dmg-background.png design/dmg-background@2x.png -out "$BG" 2>/dev/null
    "$DMGBUILD" -s design/dmg-settings.py \
        -D app="$APP" -D background="$BG" -D icon=Resources/AppIcon.icns MHanja "$DMG" >/dev/null
    rm -f "$BG"
else
    echo "dmgbuild 없음 — 꾸미지 않은 DMG를 만듭니다."
    echo "  설치: python3 -m venv .build/dmgbuild-venv && .build/dmgbuild-venv/bin/pip install dmgbuild"
    STAGE=build/dmg
    rm -rf "$STAGE"
    mkdir -p "$STAGE"
    cp -R "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname MHanja -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
    rm -rf "$STAGE"
fi
echo "완료: $DMG"
