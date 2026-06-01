#!/bin/bash
# Build de Release do iMackPeek e cópia para dist/iMackPeek.app.
# Uso: scripts/build_release.sh
# (regenera o projeto com xcodegen se necessário, depois compila Release.)

set -euo pipefail

APP_NAME="iMackPeek"
PROJECT="${APP_NAME}.xcodeproj"

if [[ ! -d "$PROJECT" ]]; then
    echo "→ gerando projeto com xcodegen"
    xcodegen generate
fi

echo "→ compilando Release UNIVERSAL (arm64 + x86_64)"
DERIVED="$(mktemp -d)"
xcodebuild -project "$PROJECT" -scheme "$APP_NAME" -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED" \
    ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
    build >/dev/null

BUILT_APP="$DERIVED/Build/Products/Release/${APP_NAME}.app"
if [[ ! -d "$BUILT_APP" ]]; then
    echo "erro: build não produziu $BUILT_APP" >&2
    exit 1
fi

echo "→ copiando para dist/"
mkdir -p dist
rm -rf "dist/${APP_NAME}.app"
cp -R "$BUILT_APP" "dist/${APP_NAME}.app"
rm -rf "$DERIVED"

echo "→ verificando arquiteturas"
lipo -archs "dist/${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

echo "✓ dist/${APP_NAME}.app"
