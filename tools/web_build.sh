#!/bin/bash
# 웹 빌드를 만들고 같은 와이파이의 휴대폰에서 접속할 수 있게 띄운다.
# 사용법: tools/web_build.sh          (빌드 + 서버)
#        tools/web_build.sh --build  (빌드만, 서버가 이미 떠 있을 때)
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PORT="${PORT:-8080}"

mkdir -p build/web
"$GODOT" --headless --path . --export-debug "Web" build/web/index.html
echo "빌드 완료: build/web/"

if [ "$1" != "--build" ]; then
	IP=$(ipconfig getifaddr en0 || ipconfig getifaddr en1 || echo "localhost")
	echo "휴대폰 Safari에서 열기: http://$IP:$PORT"
	cd build/web && exec python3 -m http.server "$PORT" --bind 0.0.0.0
fi
