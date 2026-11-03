# WOD-GOTCHI

크로스핏 다마고치. 내가 만든 캐릭터를 매일 돌보고 운동시켜 게임즈 선수로 키우는 게임 (Godot 4).

설계 문서: [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md)

## 실행

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

에디터로 열기: `/Applications/Godot.app/Contents/MacOS/Godot -e --path .`

## 조작
| 버튼 | 키보드 | 홈 | 메뉴 | 미니게임 |
|---|---|---|---|---|
| A | Z / Space | 칭찬 | 다음 항목 | 탭 |
| B | X | 상태(화이트보드) | 결정 | 탭 (버터플라이 교대) |
| 메뉴 | Enter / Esc | 행동 메뉴 | 뒤로 | 그만하기 |

방향키로도 메뉴를 움직일 수 있고, 화면을 직접 터치해도 된다.

## 자동 테스트 (스크린샷)

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . res://tests/SmokeTest.tscn
```
기존 저장 데이터는 백업했다가 끝나면 되돌린다. 스크린샷은 `~/Library/Application Support/Godot/app_userdata/WOD-GOTCHI/shots/`에 저장된다.

## 구조
- `scripts/game_state.gd` 저장, 실시간 경과, 방치 페널티, 성장/진화
- `scripts/pal.gd` 팔레트와 도트 드로잉 (캐릭터·배경 모두 코드로 그림)
- `scripts/sfx.gd` 사각파 효과음 생성
- `scripts/main.gd` 화면 스택, 하단 버튼, 입력
- `scripts/screens/` 각 화면 (생성, 홈, 1RM, 리듬, WOD 실행/편집, 실제 PR)
- 폰트: Galmuri (SIL OFL, `assets/fonts/OFL-Galmuri.md`)
