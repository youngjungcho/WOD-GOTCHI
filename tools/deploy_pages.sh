#!/bin/bash
# 릴리스 웹 빌드를 만들어 GitHub Pages(gh-pages 브랜치)에 올린다.
# 주소: https://<계정>.github.io/<저장소>/
# gh-pages 브랜치는 빌드 결과만 담는 배포용이라 매번 새로 만들어 덮어쓴다.
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
REMOTE="$(git remote get-url origin)"
OUT="build/pages"

rm -rf "$OUT" && mkdir -p "$OUT"
"$GODOT" --headless --path . --export-release "Web" "$OUT/index.html"
touch "$OUT/.nojekyll"  # Jekyll 처리 없이 파일을 그대로 서빙

TMP="$(mktemp -d)"
cp -R "$OUT/." "$TMP/"
cd "$TMP"
git init -q -b gh-pages
git add -A
git commit -q -m "웹 빌드 배포 ($(date '+%Y-%m-%d %H:%M'))

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push -f -q "$REMOTE" gh-pages
cd - > /dev/null
rm -rf "$TMP"
echo "배포 완료: gh-pages 브랜치"
