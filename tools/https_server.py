"""휴대폰 테스트용 HTTPS 정적 서버.

Godot 웹 빌드는 보안 연결(HTTPS)에서만 실행된다. localhost가 아닌 주소(같은 와이파이의 휴대폰)로
접속하려면 HTTPS가 필요해서, build/cert의 자체 서명 인증서로 build/web을 서빙한다.
사용법: python3 tools/https_server.py [포트]
"""
import http.server
import os
import socket
import ssl
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8443
CERT = os.path.join(ROOT, "build", "cert", "cert.pem")
KEY = os.path.join(ROOT, "build", "cert", "key.pem")


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=os.path.join(ROOT, "build", "web"), **kwargs)

    def end_headers(self):
        # 새로 빌드하면 휴대폰에서 새로고침만으로 반영되게 캐시를 끈다
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        return s.getsockname()[0]
    except OSError:
        return "localhost"
    finally:
        s.close()


ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(CERT, KEY)
httpd = http.server.ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
print(f"휴대폰 Safari에서 열기: https://{lan_ip()}:{PORT}", flush=True)
httpd.serve_forever()
