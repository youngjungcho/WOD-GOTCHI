class_name Pal
extends RefCounted
## 파스텔 팔레트와 도트 드로잉 헬퍼. 모든 그래픽은 코드로 그린다.
## 캐릭터는 Chibi(2등신 치비)가 그린다.

const LIGHT := Color("fff6e8")  # 크림 배경
const MID := Color("f2d9b8")  # 연한 선
const DARK := Color("9c7458")  # 보조 글씨·나무
const INK := Color("4a3b4a")  # 글씨·외곽선
const WHITE := Color("fffdf8")
const RED := Color("ff6f7f")
const GREEN := Color("62c48a")
const BLUE := Color("6aa8f0")
const YELLOW := Color("ffc94d")
const PINK := Color("ffb3c7")
const MINT := Color("9fe3d0")
const PANTS := Color("5a6480")

const SKIN_NAMES := ["밝은 톤", "중간 톤", "어두운 톤"]
const HAIR_NAMES := ["짧은 머리", "포니테일", "번 헤어", "스포츠"]
const HAIR_COLOR_NAMES := ["검정", "갈색", "금발", "빨강"]
const OUTFIT_NAMES := ["하늘", "딸기", "민트", "라벤더"]

static var _font: FontFile


static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/Galmuri9.ttf")
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _font


# ---------- 텍스트 / 창 ----------

## 무게 표기: 정수면 정수로, 아니면 소수 한 자리.
static func num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, round(v)) else "%.1f" % v


static func text(ci: CanvasItem, pos: Vector2, s: String, col: Color = INK, size: int = 10) -> void:
	var f := font()
	ci.draw_string(f, pos.round() + Vector2(0, f.get_ascent(size)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func text_center(ci: CanvasItem, rect: Rect2, s: String, col: Color = INK, size: int = 10) -> void:
	var f := font()
	var y := rect.position.y + (rect.size.y - f.get_height(size)) * 0.5 + f.get_ascent(size)
	ci.draw_string(f, Vector2(rect.position.x, round(y)), s, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, col)


static func text_wrap(ci: CanvasItem, pos: Vector2, s: String, width: float, col: Color = INK, size: int = 10, max_lines: int = -1) -> void:
	var f := font()
	ci.draw_multiline_string(f, pos + Vector2(0, f.get_ascent(size)), s, HORIZONTAL_ALIGNMENT_LEFT, width, size, max_lines, col)


static func text_width(s: String, size: int = 10) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func frame(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), col)
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), col)
	ci.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), col)
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), col)


## 둥근 모서리 창 (말풍선 느낌).
static func window(ci: CanvasItem, r: Rect2, fill: Color = WHITE) -> void:
	round_rect(ci, r, INK)
	round_rect(ci, r.grow(-1), fill)
	# 안쪽 연한 테두리
	ci.draw_rect(Rect2(r.position.x + 4, r.position.y + 2, r.size.x - 8, 1), MID)
	ci.draw_rect(Rect2(r.position.x + 4, r.end.y - 3, r.size.x - 8, 1), MID)


## 모서리를 2px 깎은 사각형.
static func round_rect(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_rect(Rect2(r.position.x + 2, r.position.y, r.size.x - 4, r.size.y), col)
	ci.draw_rect(Rect2(r.position.x, r.position.y + 2, r.size.x, r.size.y - 4), col)
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - 2), col)


static func bar(ci: CanvasItem, r: Rect2, ratio: float, col: Color) -> void:
	round_rect(ci, r, INK)
	ci.draw_rect(r.grow(-1), Color("f3e6d6"))
	var w := floorf((r.size.x - 2) * clampf(ratio, 0.0, 1.0))
	if w > 0:
		ci.draw_rect(Rect2(r.position + Vector2.ONE, Vector2(w, r.size.y - 2)), col)
		ci.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(w, 1)), col.lightened(0.35))


static func gauge_color(v: float) -> Color:
	if v < 25.0:
		return RED
	if v < 50.0:
		return YELLOW
	return GREEN


## 오른쪽을 가리키는 ▶ 커서.
static func cursor(ci: CanvasItem, pos: Vector2, col: Color = INK) -> void:
	for i in 4:
		ci.draw_rect(Rect2(pos + Vector2(i, i), Vector2(1, 7 - i * 2)), col)


# ---------- 배경 ----------

## 아늑한 크로스핏 박스 실내 배경.
## room_override: 상점 미리보기용 (null이면 지금 꾸민 대로)
static func box_scene(ci: CanvasItem, r: Rect2, t: float, floor_ratio: float = 0.68, room_override = null) -> void:
	var floor_y := r.position.y + r.size.y * floor_ratio
	var room: Dictionary = GameState.room() if room_override == null else room_override
	var wall := Rect2(r.position, Vector2(r.size.x, floor_y - r.position.y))
	var wall_col := Color(room.get("wall", "fff6e8"))
	ci.draw_rect(wall, wall_col)
	# 벽지 줄무늬
	var stripe := Color("fdeedd") if not room.has("wall") else wall_col.darkened(0.04)
	var x := r.position.x + 4
	var rainbow := [Color("ffd6dc"), Color("ffe6c7"), Color("fff5c2"), Color("d9f5e4"), Color("d6ecff"), Color("e8dcff")]
	var k := 0
	while x < r.end.x:
		var sc: Color = rainbow[k % rainbow.size()] if room.get("rainbow", false) else stripe
		ci.draw_rect(Rect2(x, wall.position.y, 6 if not room.get("rainbow", false) else 16, wall.size.y), sc)
		x += 16
		k += 1
	# 걸레받이
	ci.draw_rect(Rect2(r.position.x, floor_y - 5, r.size.x, 5), Color("f6d6c8"))
	ci.draw_rect(Rect2(r.position.x, floor_y - 5, r.size.x, 1), Color("eebfae"))
	# 창문 (하늘과 구름)
	var win := Rect2(r.position.x + 64, r.position.y + 8, 40, 28)
	round_rect(ci, win, INK)
	ci.draw_rect(win.grow(-2), Color("bfe7ff"))
	var cx := win.position.x + 4 + fmod(t * 2.0, 40.0)
	ci.draw_rect(Rect2(clampf(cx, win.position.x + 2, win.end.x - 12), win.position.y + 8, 10, 3), WHITE)
	ci.draw_rect(Rect2(clampf(cx + 2, win.position.x + 2, win.end.x - 8), win.position.y + 6, 6, 2), WHITE)
	ci.draw_rect(Rect2(win.position.x + 19, win.position.y + 2, 2, win.size.y - 4), Color("fff6e8"))
	ci.draw_rect(Rect2(win.position.x + 2, win.position.y + 13, win.size.x - 4, 2), Color("fff6e8"))
	# 화이트보드 (오늘의 WOD)
	var wb := Rect2(r.position.x + 8, r.position.y + 10, 46, 30)
	round_rect(ci, wb, INK)
	ci.draw_rect(wb.grow(-1), WHITE)
	for i in 4:
		ci.draw_rect(Rect2(wb.position.x + 5, wb.position.y + 6 + i * 6, 16 + (i * 7) % 16, 1), [BLUE, RED, INK, GREEN][i])
	icon(ci, Vector2(wb.end.x - 12, wb.position.y + 4), "heart")
	ci.draw_rect(Rect2(wb.position.x + 3, wb.end.y, wb.size.x - 6, 2), DARK)
	# 화분
	var pot := Vector2(r.position.x + 110, floor_y - 13)
	ci.draw_rect(Rect2(pot.x, pot.y + 6, 10, 8), INK)
	ci.draw_rect(Rect2(pot.x + 1, pot.y + 7, 8, 6), Color("ff9f80"))
	for lf in [Vector2(-3, 0), Vector2(3, -3), Vector2(8, 0), Vector2(2, 2)]:
		ci.draw_rect(Rect2(pot + lf, Vector2(5, 4)), Color("3f8f62"))
		ci.draw_rect(Rect2(pot + lf + Vector2(1, 1), Vector2(3, 2)), GREEN)
	# 풀업 리그
	var rx := r.end.x - 44
	ci.draw_rect(Rect2(rx, r.position.y + 8, 3, floor_y - r.position.y - 8), INK)
	ci.draw_rect(Rect2(rx + 34, r.position.y + 8, 3, floor_y - r.position.y - 8), INK)
	ci.draw_rect(Rect2(rx + 1, r.position.y + 8, 1, floor_y - r.position.y - 8), Color("8a7a96"))
	ci.draw_rect(Rect2(rx + 35, r.position.y + 8, 1, floor_y - r.position.y - 8), Color("8a7a96"))
	ci.draw_rect(Rect2(rx, r.position.y + 14, 37, 2), INK)
	# 바닥: 나무 + 민트 매트
	ci.draw_rect(Rect2(r.position.x, floor_y, r.size.x, r.end.y - floor_y), Color("e8c49e"))
	ci.draw_rect(Rect2(r.position.x, floor_y, r.size.x, 1), Color("c99a72"))
	var mx := r.position.x + 10
	while mx < r.end.x:
		ci.draw_rect(Rect2(mx, floor_y + 1, 1, r.end.y - floor_y - 1), Color("d9b088"))
		mx += 28
	var mat := Rect2(r.position.x + 30, floor_y + 6, r.size.x - 60, r.end.y - floor_y - 12)
	if mat.size.y > 4:
		var mat_col := Color(room.get("mat", "9fe3d0"))
		round_rect(ci, mat, mat_col.darkened(0.2))
		round_rect(ci, mat.grow(-1), mat_col)
	_room_extras(ci, r, floor_y, room)
	# 케틀벨
	var kb := Vector2(r.end.x - 24, floor_y - 9)
	ci.draw_rect(Rect2(kb + Vector2(1, 3), Vector2(9, 7)), INK)
	ci.draw_rect(Rect2(kb + Vector2(2, 4), Vector2(7, 5)), PINK)
	ci.draw_rect(Rect2(kb + Vector2(3, 5), Vector2(2, 1)), WHITE)
	ci.draw_rect(Rect2(kb + Vector2(2, 0), Vector2(7, 1)), INK)
	ci.draw_rect(Rect2(kb + Vector2(2, 0), Vector2(1, 4)), INK)
	ci.draw_rect(Rect2(kb + Vector2(8, 0), Vector2(1, 4)), INK)


## 상점에서 산 포스터·소품·가랜드·시계.
static func _room_extras(ci: CanvasItem, r: Rect2, floor_y: float, room: Dictionary) -> void:
	# 가랜드: 벽 위쪽을 가로지르는 삼각 깃발
	if room.has("garland"):
		var cols := [PINK, MINT, YELLOW, Color("cbb8f5")] if room.garland == "pastel" else [RED, Color("ff9f50"), YELLOW, GREEN, BLUE, Color("a07ce8")]
		ci.draw_rect(Rect2(r.position.x, r.position.y + 3, r.size.x, 1), DARK)
		var fx := r.position.x + 2
		var i := 0
		while fx < r.end.x - 4:
			var c: Color = cols[i % cols.size()]
			for j in 5:
				ci.draw_rect(Rect2(fx + j * 0.5, r.position.y + 4 + j, 7 - j, 1), c)
			fx += 11
			i += 1
	# 벽시계 (풀업 리그 안쪽 벽)
	if room.get("clock", false):
		var cc := Vector2(r.end.x - 26, r.position.y + 26)
		ci.draw_circle(cc, 7, INK)
		ci.draw_circle(cc, 6, WHITE)
		var hr := GameState.local_hour() % 12
		var a := hr / 12.0 * TAU - PI / 2
		ci.draw_line(cc, cc + Vector2(cos(a), sin(a)) * 3.5, INK, 1.0)
		ci.draw_line(cc, cc + Vector2(0, -5), RED, 1.0)
	match room.get("poster", ""):
		"heart":
			var p := Rect2(r.position.x + 110, r.position.y + 10, 20, 24)
			round_rect(ci, p, INK)
			ci.draw_rect(p.grow(-1), Color("ffe3ea"))
			icon(ci, p.position + Vector2(7, 8), "heart", 1)
			icon(ci, p.position + Vector2(3, 3), "heart", 1)
		"pr":
			var p := Rect2(r.position.x + 108, r.position.y + 10, 24, 22)
			round_rect(ci, p, INK)
			ci.draw_rect(p.grow(-1), YELLOW)
			text_center(ci, Rect2(p.position.x, p.position.y + 3, p.size.x, 12), "PR!", RED)
			ci.draw_rect(Rect2(p.position.x + 4, p.end.y - 5, p.size.x - 8, 1), RED)
		"cf":
			var p := Rect2(r.position.x + 110, r.position.y + 10, 20, 26)
			round_rect(ci, p, INK)
			ci.draw_rect(p.grow(-1), RED)
			ci.draw_rect(p.grow(-3), WHITE)
			icon(ci, p.position + Vector2(7, 5), "dumbbell")
			ci.draw_rect(Rect2(p.position.x + 5, p.position.y + 15, 10, 1), INK)
			ci.draw_rect(Rect2(p.position.x + 6, p.position.y + 18, 8, 1), INK)
		"cat":
			var p := Rect2(r.position.x + 110, r.position.y + 10, 20, 24)
			round_rect(ci, p, INK)
			ci.draw_rect(p.grow(-1), Color("fff1c9"))
			var c := p.position + Vector2(10, 14)
			ci.draw_rect(Rect2(c + Vector2(-6, -6), Vector2(3, 3)), Color("f2a65a"))
			ci.draw_rect(Rect2(c + Vector2(3, -6), Vector2(3, 3)), Color("f2a65a"))
			ci.draw_rect(Rect2(c + Vector2(-6, -4), Vector2(12, 9)), Color("f2a65a"))
			ci.draw_rect(Rect2(c + Vector2(-3, -1), Vector2(1, 2)), INK)
			ci.draw_rect(Rect2(c + Vector2(2, -1), Vector2(1, 2)), INK)
			ci.draw_rect(Rect2(c + Vector2(-1, 2), Vector2(2, 1)), PINK)
	var dx := r.end.x - 56  # 왼쪽은 은퇴한 코치 자리
	match room.get("deco", ""):
		"cat":
			var b := Vector2(dx + 7, floor_y - 8)
			ci.draw_rect(Rect2(b + Vector2(-7, -9), Vector2(4, 4)), INK)
			ci.draw_rect(Rect2(b + Vector2(3, -9), Vector2(4, 4)), INK)
			ci.draw_circle(b, 7, INK)
			ci.draw_circle(b, 6, Color("f2a65a"))
			ci.draw_rect(Rect2(b + Vector2(-6, -8), Vector2(2, 3)), Color("f2a65a"))
			ci.draw_rect(Rect2(b + Vector2(4, -8), Vector2(2, 3)), Color("f2a65a"))
			ci.draw_rect(Rect2(b + Vector2(-3, -2), Vector2(1, 2)), INK)
			ci.draw_rect(Rect2(b + Vector2(2, -2), Vector2(1, 2)), INK)
			ci.draw_rect(Rect2(b + Vector2(-1, 1), Vector2(2, 1)), PINK)
		"dumbbells":
			for i in 2:
				var b := Vector2(dx - 2, floor_y - 6 - i * 7)
				ci.draw_rect(Rect2(b, Vector2(18, 5)), INK)
				ci.draw_rect(Rect2(b + Vector2(1, 1), Vector2(4, 3)), [BLUE, RED][i])
				ci.draw_rect(Rect2(b + Vector2(13, 1), Vector2(4, 3)), [BLUE, RED][i])
				ci.draw_rect(Rect2(b + Vector2(5, 2), Vector2(8, 1)), Color("8a7a96"))
		"bottle":
			var b := Vector2(dx + 4, floor_y - 18)
			ci.draw_rect(Rect2(b + Vector2(2, 0), Vector2(4, 3)), INK)
			ci.draw_rect(Rect2(b + Vector2(0, 3), Vector2(8, 15)), INK)
			ci.draw_rect(Rect2(b + Vector2(1, 4), Vector2(6, 13)), Color("bfe7ff"))
			ci.draw_rect(Rect2(b + Vector2(1, 9), Vector2(6, 8)), Color("6aa8f0"))
			ci.draw_rect(Rect2(b + Vector2(2, 5), Vector2(1, 3)), WHITE)
		"trophy":
			var b := Vector2(dx, floor_y - 16)
			ci.draw_rect(Rect2(b + Vector2(1, 0), Vector2(12, 8)), INK)
			ci.draw_rect(Rect2(b + Vector2(2, 1), Vector2(10, 6)), YELLOW)
			ci.draw_rect(Rect2(b + Vector2(3, 2), Vector2(2, 3)), WHITE)
			ci.draw_rect(Rect2(b + Vector2(5, 8), Vector2(4, 4)), INK)
			ci.draw_rect(Rect2(b + Vector2(6, 8), Vector2(2, 4)), YELLOW)
			ci.draw_rect(Rect2(b + Vector2(2, 12), Vector2(10, 4)), INK)
			ci.draw_rect(Rect2(b + Vector2(3, 13), Vector2(8, 2)), Color("c8875a"))
		"bear":
			var b := Vector2(dx + 7, floor_y - 9)
			ci.draw_circle(b + Vector2(-5, -6), 3, INK)
			ci.draw_circle(b + Vector2(5, -6), 3, INK)
			ci.draw_circle(b, 8, INK)
			ci.draw_circle(b, 7, Color("c8875a"))
			ci.draw_circle(b + Vector2(-5, -6), 2, Color("c8875a"))
			ci.draw_circle(b + Vector2(5, -6), 2, Color("c8875a"))
			ci.draw_rect(Rect2(b + Vector2(-3, -2), Vector2(1, 2)), INK)
			ci.draw_rect(Rect2(b + Vector2(2, -2), Vector2(1, 2)), INK)
			ci.draw_rect(Rect2(b + Vector2(-2, 2), Vector2(4, 2)), Color("f0d0b0"))
			ci.draw_rect(Rect2(b + Vector2(-1, 2), Vector2(2, 1)), INK)
		"plant":
			var b := Vector2(dx, floor_y - 26)
			ci.draw_rect(Rect2(b + Vector2(2, 16), Vector2(12, 10)), INK)
			ci.draw_rect(Rect2(b + Vector2(3, 17), Vector2(10, 8)), Color("ffffff"))
			for lf in [Vector2(0, 6), Vector2(8, 4), Vector2(4, 0), Vector2(10, 10), Vector2(-2, 11)]:
				ci.draw_rect(Rect2(b + lf, Vector2(7, 6)), Color("3f8f62"))
				ci.draw_rect(Rect2(b + lf + Vector2(1, 1), Vector2(5, 4)), GREEN)


# ---------- 아이콘 ----------
# k 외곽선, r 빨강, y 노랑, b 갈색, w 흰색, g 초록, t 하늘, p 분홍

const ICONS := {
	"heart": [".kk.kk.", "krrkrrk", "krwrrrk", "krrrrrk", ".krrrk.", "..krk..", "...k..."],
	"food": ["..kkk..", ".kbbbk.", "kbbwbbk", "kbbbbbk", ".kbbbk.", "..kwk..", ".kwwk.."],
	"energy": ["...kkk.", "..kyyk.", ".kyyk..", "kyyyyk.", ".kkyyk.", "..kyk..", "..kk..."],
	"cond": ["..kkk..", "..kgk..", "kkkgkkk", "kgggggk", "kkkgkkk", "..kgk..", "..kkk.."],
	"mental": ["..kkk..", ".kpppk.", "kppwppk", "kpppppk", ".kpppk.", "..kpk..", "...k..."],
	"sweat": ["...t...", "..ttt..", ".ttwtt.", ".ttttt.", "..ttt.."],
	"anger": [".r.r.", "rr.rr", ".....", "rr.rr", ".r.r."],
	"note": ["..kkk", "..k.k", "..k.k", "kkk.k", "kkkkk", "kk..."],
	"dumbbell": ["r.....r", "rr...rr", "rrkkkrr", "rr...rr", "r.....r"],
	"moon": ["..yyy..", ".yy....", "yy.....", "yy.....", "yy.....", ".yy....", "..yyy.."],
	"sun": ["...y...", ".y.y.y.", "..yyy..", "yyyyyyy", "..yyy..", ".y.y.y.", "...y..."],
	"quiz": [".kkkk.", "k....k", "....k.", "...k..", "...k..", "......", "...k.."],
	"more": ["kk.kk.kk", "kk.kk.kk"],
	"coin": [".kkkk.", "kyyyyk", "kywyyk", "kyyyyk", "kyyyyk", ".kkkk."],
	"star": ["...k...", "..kyk..", "kkkyykk", "kyyyyyk", ".kyyyk.", ".kykyk.", "kk...kk"],
}
const ICON_COLORS := {"k": INK, "r": RED, "y": YELLOW, "b": Color("c8875a"), "w": WHITE, "g": GREEN, "t": Color("8fd3ff"), "p": PINK}


static func icon(ci: CanvasItem, pos: Vector2, name: String, s: int = 1) -> void:
	var rows: Array = ICONS[name]
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch != ".":
				ci.draw_rect(Rect2(pos + Vector2(x, y) * s, Vector2(s, s)), ICON_COLORS[ch])


## 머리 위 감정 말풍선. kind: heart, note, sweat, anger, alert
static func bubble(ci: CanvasItem, pos: Vector2, kind: String) -> void:
	var r := Rect2(pos, Vector2(13, 12))
	round_rect(ci, r, INK)
	round_rect(ci, r.grow(-1), WHITE)
	ci.draw_rect(Rect2(pos + Vector2(2, 12), Vector2(3, 1)), INK)
	ci.draw_rect(Rect2(pos + Vector2(2, 13), Vector2(1, 1)), INK)
	match kind:
		"alert":
			ci.draw_rect(Rect2(pos + Vector2(5, 2), Vector2(3, 5)), RED)
			ci.draw_rect(Rect2(pos + Vector2(5, 8), Vector2(3, 2)), RED)
		"heart":
			icon(ci, pos + Vector2(3, 3), "heart")
		"note":
			icon(ci, pos + Vector2(4, 3), "note")
		"sweat":
			icon(ci, pos + Vector2(3, 4), "sweat")
		"anger":
			icon(ci, pos + Vector2(4, 4), "anger")


## 바벨. center는 봉의 가운데, plates는 한쪽 원판 개수.
static func barbell(ci: CanvasItem, center: Vector2, half_len: float, plates: int) -> void:
	var c := center.round()
	ci.draw_rect(Rect2(c.x - half_len, c.y - 1, half_len * 2, 2), INK)
	var cols := [RED, BLUE, YELLOW, GREEN]
	for side in [-1, 1]:
		for i in plates:
			var h: int = 14 - mini(i, 3) * 2
			var x: float = c.x + side * (half_len - 6 - i * 4) - (3 if side < 0 else 0)
			var pr := Rect2(x, c.y - h / 2, 3, h)
			ci.draw_rect(pr, INK)
			ci.draw_rect(pr.grow(-1) if pr.size.x > 2 else pr, cols[i % 4])


# ---------- 캐릭터 ----------

## 캐릭터 그리기 (Chibi에 위임). o = 32x48 상자의 왼쪽 위, s = 칸 크기(px).
## pose: idle, happy, tired, refuse, sleep, lift(p=0~1 바 높이), hang(p=0~1 당긴 정도), support,
##       squat(p=0~1 일어선 정도, 바는 어깨), ohs(p=0~1, 바는 머리 위)
static func athlete(ci: CanvasItem, o: Vector2, look: Dictionary, pose: String = "idle", s: int = 1, t: float = 0.0, p: float = 0.0, style: Dictionary = {}, clip_rows: int = -1) -> void:
	Chibi.draw(ci, o, look, pose, s, t, p, style, clip_rows)


static func squat_crouch(p: float) -> int:
	return Chibi.squat_crouch(p)
