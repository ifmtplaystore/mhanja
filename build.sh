#!/bin/zsh
# MHanja.app·DMG 빌드: CPU별로 따로 만든다.
#   ./build.sh          →  Apple Silicon과 Intel 둘 다
#   ./build.sh arm64    →  Apple Silicon만 (build/arm64/MHanja.app, build/MHanja.dmg)
#   ./build.sh x86_64   →  Intel만 (build/x86_64/MHanja.app, build/MHanja-Intel.dmg)
# Apple Silicon DMG 이름을 MHanja.dmg로 두는 것은 1.4 이하의 업데이트 알림이 첫 .dmg를 받기 때문이다.
set -e
cd "$(dirname "$0")"

ARCHS=("$@")
(( $# )) || ARCHS=(arm64 x86_64)
# 서명: SIGN_IDENTITY > 키체인의 "MHanja Local Signing"(자체 서명) > ad-hoc.
# 고정 인증서로 서명해야 다시 빌드해도 손쉬운 사용 권한이 유지된다 (ad-hoc은 빌드마다 바뀜).
LOCAL_IDENTITY="MHanja Local Signing"
if [[ -z "$SIGN_IDENTITY" ]] && security find-identity -p codesigning | grep -q "\"$LOCAL_IDENTITY\""; then
    SIGN_IDENTITY="$LOCAL_IDENTITY"
fi

for ARCH in $ARCHS; do
case $ARCH in
    arm64)  DMG=build/MHanja.dmg ;;
    x86_64) DMG=build/MHanja-Intel.dmg ;;
    *) echo "알 수 없는 아키텍처: $ARCH (arm64 또는 x86_64)"; exit 1 ;;
esac

swift build -c release --arch $ARCH
APP=build/$ARCH/MHanja.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --arch $ARCH --show-bin-path)/MHanja" "$APP/Contents/MacOS/MHanja"
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
    <key>CFBundleShortVersionString</key><string>1.5</string>
    <key>CFBundleVersion</key><string>6</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>© 2026 IFMT</string>
</dict>
</plist>
EOF

codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
echo "서명: ${SIGN_IDENTITY:-ad-hoc}"
echo "완료: $APP"

# 배포용 DMG: 앱 + /Applications 바로가기.
# dmgbuild가 있으면 배경 그림·큰 아이콘 창으로 꾸민다 (design/dmg-settings.py).
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
done
