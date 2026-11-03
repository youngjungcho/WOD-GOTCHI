class_name Pal
extends RefCounted
## GBC 느낌 팔레트와 도트 드로잉 헬퍼. 모든 그래픽은 코드로 그린다.

const LIGHT := Color("f8f0d8")
const MID := Color("e0c890")
const DARK := Color("a07048")
const INK := Color("282020")
const WHITE := Color("fcfcf4")
const RED := Color("d84838")
const GREEN := Color("58b048")
const BLUE := Color("4878c8")
const YELLOW := Color("f0c030")
const PANTS := Color("383848")

const SKINS := [Color("f8d0a8"), Color("d8a070"), Color("a06838")]
const HAIR_COLORS := [Color("383028"), Color("885028"), Color("e0b040"), Color("d05050")]
const OUTFITS := [Color("3870c8"), Color("c83838"), Color("38a058"), Color("8048b0")]
const SKIN_NAMES := ["밝은 톤", "중간 톤", "어두운 톤"]
const HAIR_NAMES := ["짧은 머리", "포니테일", "번 헤어", "스포츠"]
const HAIR_COLOR_NAMES := ["검정", "갈색", "금발", "빨강"]
const OUTFIT_NAMES := ["파랑", "빨강", "초록", "보라"]

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


## 포켓몬 시절 RPG 같은 이중 테두리 창.
static func window(ci: CanvasItem, r: Rect2, fill: Color = WHITE) -> void:
	ci.draw_rect(r, INK)
	ci.draw_rect(r.grow(-1), fill)
	frame(ci, r.grow(-2), DARK)
	# 모서리를 깎아 둥근 느낌을 낸다
	for c in [r.position, r.position + Vector2(r.size.x - 1, 0), r.position + Vector2(0, r.size.y - 1), r.end - Vector2.ONE]:
		ci.draw_rect(Rect2(c, Vector2.ONE), LIGHT)


static func bar(ci: CanvasItem, r: Rect2, ratio: float, col: Color) -> void:
	ci.draw_rect(r, INK)
	ci.draw_rect(r.grow(-1), LIGHT)
	var w := floorf((r.size.x - 2) * clampf(ratio, 0.0, 1.0))
	if w > 0:
		ci.draw_rect(Rect2(r.position + Vector2.ONE, Vector2(w, r.size.y - 2)), col)


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

## 크로스핏 박스 실내 배경.
static func box_scene(ci: CanvasItem, r: Rect2, t: float) -> void:
	var floor_y := r.position.y + r.size.y * 0.68
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, floor_y - r.position.y)), LIGHT)
	# 벽 벽돌 줄
	var y := r.position.y + 6
	var row := 0
	while y < floor_y - 4:
		ci.draw_rect(Rect2(r.position.x, y, r.size.x, 1), MID)
		var x := r.position.x + (0.0 if row % 2 == 0 else 10.0)
		while x < r.end.x:
			ci.draw_rect(Rect2(x, y - 6, 1, 6), MID)
			x += 20
		y += 7
		row += 1
	# 바닥 (고무 매트)
	ci.draw_rect(Rect2(r.position.x, floor_y, r.size.x, r.end.y - floor_y), DARK)
	ci.draw_rect(Rect2(r.position.x, floor_y, r.size.x, 2), INK)
	var mx := r.position.x
	while mx < r.end.x:
		ci.draw_rect(Rect2(mx, floor_y + 2, 1, r.end.y - floor_y - 2), Color(INK, 0.35))
		mx += 30
	# 화이트보드
	var wb := Rect2(r.position.x + 8, r.position.y + 10, 46, 30)
	ci.draw_rect(wb, INK)
	ci.draw_rect(wb.grow(-1), WHITE)
	for i in 4:
		ci.draw_rect(Rect2(wb.position.x + 4, wb.position.y + 5 + i * 6, 18 + (i * 7) % 16, 1), [BLUE, RED, INK, BLUE][i])
	ci.draw_rect(Rect2(wb.position.x + 2, wb.end.y, wb.size.x - 4, 2), DARK)
	# 풀업 리그
	var rx := r.end.x - 44
	ci.draw_rect(Rect2(rx, r.position.y + 8, 3, floor_y - r.position.y - 8), INK)
	ci.draw_rect(Rect2(rx + 34, r.position.y + 8, 3, floor_y - r.position.y - 8), INK)
	ci.draw_rect(Rect2(rx, r.position.y + 14, 37, 2), INK)
	# 원판 거치대
	for i in 3:
		ci.draw_rect(Rect2(r.position.x + 62 + i * 4, floor_y - 18 + i * 2, 3, 18 - i * 2), [RED, BLUE, YELLOW][i])
		frame(ci, Rect2(r.position.x + 62 + i * 4, floor_y - 18 + i * 2, 3, 18 - i * 2), INK)
	# 케틀벨
	var kb := Vector2(r.end.x - 26, floor_y - 9)
	ci.draw_rect(Rect2(kb + Vector2(1, 3), Vector2(8, 7)), INK)
	ci.draw_rect(Rect2(kb + Vector2(2, 4), Vector2(6, 5)), PANTS)
	ci.draw_rect(Rect2(kb + Vector2(2, 0), Vector2(6, 1)), INK)
	ci.draw_rect(Rect2(kb + Vector2(2, 0), Vector2(1, 4)), INK)
	ci.draw_rect(Rect2(kb + Vector2(7, 0), Vector2(1, 4)), INK)


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

static func _px(ci: CanvasItem, o: Vector2, s: int, x: float, y: float, w: float, h: float, col: Color) -> void:
	ci.draw_rect(Rect2(o + Vector2(x, y) * s, Vector2(w, h) * s), col)


## 1px 외곽선이 있는 박스 (단위 좌표).
static func _ob(ci: CanvasItem, o: Vector2, s: int, x: float, y: float, w: float, h: float, col: Color) -> void:
	var r := Rect2(o + Vector2(x, y) * s, Vector2(w, h) * s)
	ci.draw_rect(r, INK)
	ci.draw_rect(r.grow(-1), col)


## 16x24 단위 캐릭터. o는 좌상단(px), s는 배율.
## pose: idle, happy, tired, refuse, sleep, lift(p=0~1 바 높이), hang(p=0~1 당긴 정도), support
static func athlete(ci: CanvasItem, o: Vector2, look: Dictionary, pose: String = "idle", s: int = 2, t: float = 0.0, p: float = 0.0, muscle: bool = false) -> void:
	var skin: Color = SKINS[int(look.get("skin", 0))]
	var hair: Color = HAIR_COLORS[int(look.get("hair_color", 0))]
	var fit: Color = OUTFITS[int(look.get("outfit", 0))]
	var style := int(look.get("hair", 0))
	o = o.round()

	if pose == "sleep":
		_athlete_sleep(ci, o, s, skin, hair, fit)
		return

	var c := 0  # 웅크림 정도
	var bob := 0
	var arms := "down"
	var eyes := "open"
	var mouth := ""
	var lift := 0
	match pose:
		"idle":
			bob = int(t * 2.0) % 2
		"happy":
			arms = "v"
			eyes = "happy"
			mouth = "open"
			bob = -(int(t * 6.0) % 2)
		"tired":
			eyes = "half"
			c = 1
		"refuse":
			arms = "cross"
			eyes = "half"
		"lift":
			c = int(round(lerpf(5.0, 0.0, p)))
			arms = "bar"
			eyes = "strain" if p < 0.95 else "happy"
		"hang":
			lift = int(round(p * 10.0))
			arms = "up"
			eyes = "strain" if p > 0.3 else "open"
		"support":
			lift = 15
			arms = "down"
			eyes = "happy"
	var hw := 5 if muscle else 4
	var ho := Vector2(0, -lift * s)  # 당길 때 몸 전체가 올라간다
	var bo := o + ho
	var hy := bob + c

	# 몸 뒤쪽 요소
	if style == 1:
		_ob(ci, bo, s, 11, 1 + hy, 3, 5, hair)
	elif style == 2:
		_ob(ci, bo, s, 6, -2 + hy, 4, 3, hair)
	if arms == "up":
		_ob(ci, bo, s, 2, -6 + lift + hy, 3, 15 - lift, skin)
		_ob(ci, bo, s, 11, -6 + lift + hy, 3, 15 - lift, skin)
	elif arms == "v":
		_ob(ci, bo, s, 0, -3 + hy, 3, 10, skin)
		_ob(ci, bo, s, 13, -3 + hy, 3, 10, skin)

	# 다리
	var leg_top := 15 + c
	var leg_h := 23 - leg_top
	var spread := 1 if c > 1 else 0
	_ob(ci, bo, s, 4 - spread, leg_top, 4, leg_h, PANTS)
	_ob(ci, bo, s, 8 + spread, leg_top, 4, leg_h, PANTS)
	_ob(ci, bo, s, 3 - spread, 22, 5, 2, WHITE)
	_ob(ci, bo, s, 8 + spread, 22, 5, 2, WHITE)

	# 팔 (몸통 옆)
	if arms == "down" or arms == "cross":
		_ob(ci, bo, s, 8 - hw - 2, 8 + hy, 3, 7, skin)
		_ob(ci, bo, s, 8 + hw - 1, 8 + hy, 3, 7, skin)
		_px(ci, bo, s, 8 - hw - 2, 8 + hy, 3, 2, fit)
		_px(ci, bo, s, 8 + hw - 1, 8 + hy, 3, 2, fit)

	# 몸통
	_ob(ci, bo, s, 8 - hw, 8 + hy, hw * 2, 8, fit)
	_px(ci, bo, s, 7, 9 + hy, 2, 1, Color(WHITE, 0.6))

	if arms == "bar":
		var hand_y := lerpf(20.0, 15.0, p)
		_ob(ci, bo, s, 4, 9 + hy, 2, hand_y - 9 - hy + 1, skin)
		_ob(ci, bo, s, 10, 9 + hy, 2, hand_y - 9 - hy + 1, skin)
	elif arms == "cross":
		_ob(ci, bo, s, 3, 11 + hy, 10, 3, skin)

	# 머리
	_ob(ci, bo, s, 4, 0 + hy, 8, 8, skin)
	_ob(ci, bo, s, 4, 0 + hy, 8, 3, hair)
	match style:
		0:
			_px(ci, bo, s, 4, 3 + hy, 1, 2, hair)
			_px(ci, bo, s, 11, 3 + hy, 1, 2, hair)
		3:
			_px(ci, bo, s, 5, -1 + hy, 1, 1, hair)
			_px(ci, bo, s, 7, -1 + hy, 1, 1, hair)
			_px(ci, bo, s, 9, -1 + hy, 1, 1, hair)
	# 눈
	match eyes:
		"open":
			var blink := fmod(t, 3.0) < 0.12
			if blink:
				_px(ci, bo, s, 6, 5 + hy, 1, 0.5, INK)
				_px(ci, bo, s, 9, 5 + hy, 1, 0.5, INK)
			else:
				_px(ci, bo, s, 6, 4 + hy, 1, 2, INK)
				_px(ci, bo, s, 9, 4 + hy, 1, 2, INK)
		"happy":
			_px(ci, bo, s, 5.5, 4.5 + hy, 2, 0.5, INK)
			_px(ci, bo, s, 8.5, 4.5 + hy, 2, 0.5, INK)
			_px(ci, bo, s, 5, 6 + hy, 1, 0.5, Color("f08888"))
			_px(ci, bo, s, 10, 6 + hy, 1, 0.5, Color("f08888"))
		"half":
			_px(ci, bo, s, 6, 5 + hy, 1, 1, INK)
			_px(ci, bo, s, 9, 5 + hy, 1, 1, INK)
		"strain":
			_px(ci, bo, s, 5.5, 4 + hy, 2, 0.5, INK)
			_px(ci, bo, s, 8.5, 4 + hy, 2, 0.5, INK)
			_px(ci, bo, s, 6, 5 + hy, 1, 0.5, INK)
			_px(ci, bo, s, 9, 5 + hy, 1, 0.5, INK)
	if mouth == "open":
		_px(ci, bo, s, 7, 6.5 + hy, 2, 0.5, INK)
	elif eyes == "strain":
		_px(ci, bo, s, 6.5, 6.5 + hy, 3, 0.5, INK)


static func _athlete_sleep(ci: CanvasItem, o: Vector2, s: int, skin: Color, hair: Color, fit: Color) -> void:
	# 요가 매트 위에 누운 모습
	_ob(ci, o, s, -4, 21, 26, 3, Color("70a8d0"))
	_ob(ci, o, s, 7, 15, 9, 6, fit)
	_ob(ci, o, s, 15, 16, 8, 5, PANTS)
	_ob(ci, o, s, -1, 13, 8, 8, skin)
	_ob(ci, o, s, -1, 13, 3, 8, hair)
	_px(ci, o, s, 3, 17, 1.5, 0.5, INK)
	_px(ci, o, s, 3, 15, 1.5, 0.5, INK)
