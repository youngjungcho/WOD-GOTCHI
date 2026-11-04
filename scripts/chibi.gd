class_name Chibi
extends RefCounted
## 2등신 치비 캐릭터 렌더러.
## 캐릭터는 32x48칸 기준(발끝이 47행)으로 그리고, 칸 하나 = s 픽셀로 화면에 찍는다.
## 둥근 도형(타원)을 칸에 채운 뒤 바깥에만 외곽선을 두르고, 그 위에 얼굴을 그린다.
## 같은 모습은 텍스처로 캐시해서 재사용한다.

const GW := 48  # 그리드 너비 (팔 벌림·망토·누운 자세 여유 포함)
const GH := 96  # 그리드 높이 (매달리기·머슬업 여유 포함)
const GX := 8  # 캐릭터 x=0이 그리드의 몇 번째 칸인지
const GY := 44  # 캐릭터 y=0이 그리드의 몇 번째 칸인지

# 칸 색 코드
enum { NONE, K, SK, SKS, HR, HRH, OF, OFS, PT, SH, EY, WH, BL, BAND, BELT, GOLD, CAPE, SWEAT, MAT, JEWEL, SIL }

const HANG_HAND_Y := -4  # 매달리기 자세에서 손(봉) 높이

const SKINS := [["ffe0c8", "f4bfa0"], ["f0c09a", "d89e78"], ["b07850", "8e5c3c"]]
const HAIRS := [["4a3530", "6e5048"], ["9a5e3a", "c07e52"], ["f2c75c", "ffe08a"], ["e86a6a", "ff9a9a"]]
const OUTFITS := [["7ec4f8", "5aa3dc"], ["ff8a8a", "e06868"], ["8edb9a", "62b874"], ["b79cf0", "9478d4"]]

static var _cache := {}


## 칸 그리드. 좌표는 캐릭터 기준(0,0 = 32x48 상자의 왼쪽 위).
class Grid:
	var px := PackedByteArray()

	func _init() -> void:
		px.resize(GW * GH)

	func at(x: int, y: int) -> int:
		var gx := x + GX
		var gy := y + GY
		if gx < 0 or gy < 0 or gx >= GW or gy >= GH:
			return NONE
		return px[gy * GW + gx]

	func put(x: int, y: int, c: int) -> void:
		var gx := x + GX
		var gy := y + GY
		if gx < 0 or gy < 0 or gx >= GW or gy >= GH:
			return
		px[gy * GW + gx] = c

	func rect(x: int, y: int, w: int, h: int, c: int) -> void:
		for j in range(y, y + h):
			for i in range(x, x + w):
				put(i, j, c)

	func ell(cx: float, cy: float, rx: float, ry: float, c: int) -> void:
		for y in range(int(floor(cy - ry)) - 1, int(ceil(cy + ry)) + 1):
			for x in range(int(floor(cx - rx)) - 1, int(ceil(cx + rx)) + 1):
				var a := (x + 0.5 - cx) / rx
				var b := (y + 0.5 - cy) / ry
				if a * a + b * b <= 1.0:
					put(x, y, c)

	## 지금 칠해진 칸 중 from 색만 to로 바꾼다 (영역 제한).
	func swap_in(x0: int, y0: int, x1: int, y1: int, from: Array, to: int) -> void:
		for y in range(y0, y1):
			for x in range(x0, x1):
				if from.has(at(x, y)):
					put(x, y, to)

	## 바깥 외곽선: 비어 있고 상하좌우에 칠해진 칸이 있으면 외곽선.
	func outline() -> void:
		var src := px.duplicate()
		for gy in GH:
			for gx in GW:
				if src[gy * GW + gx] != NONE:
					continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = gx + d.x
					var ny: int = gy + d.y
					if nx < 0 or ny < 0 or nx >= GW or ny >= GH:
						continue
					var v := src[ny * GW + nx]
					if v != NONE and v != K:
						px[gy * GW + gx] = K
						break


static func squat_crouch(p: float) -> int:
	return int(round(lerpf(8.0, 0.0, clampf(p, 0.0, 1.0))))


static func lift_hand_y(p: float) -> float:
	return lerpf(42.0, 34.0, clampf(p, 0.0, 1.0))


static func shoulder_y(p: float) -> float:
	return 28.0 + squat_crouch(p)


static func overhead_y(p: float) -> float:
	return -4.0 + squat_crouch(p)


## 화면에 그린다. o = 32x48 상자의 왼쪽 위(px), s = 칸 크기(px).
## clip_rows > 0이면 위에서부터 그 행까지만 그린다(도감 얼굴 초상화).
static func draw(ci: CanvasItem, o: Vector2, look: Dictionary, pose: String, s: int, t: float, p: float, style: Dictionary, clip_rows: int = -1) -> void:
	var bob := 0
	var blink := false
	match pose:
		"idle":
			bob = int(t * 2.0) % 2
			blink = fmod(t, 3.0) < 0.12
		"happy":
			bob = -(int(t * 6.0) % 2)
		"refuse", "tired":
			blink = fmod(t, 4.0) < 0.12
	var sweat_on: bool = style.get("sweat", false) and int(t * 3.0) % 2 == 0
	var pq := int(round(p * 24.0))
	var key := "%s|%s|%d|%d|%s|%s|%s" % [look.hash(), pose, pq, bob, blink, sweat_on, style.hash()]
	var tex: Texture2D = _cache.get(key)
	if tex == null:
		if _cache.size() > 400:
			_cache.clear()
		var g := build(look, pose, pq / 24.0, style, bob, blink, sweat_on)
		tex = _texture(g, look, style)
		_cache[key] = tex
	o = o.round()
	if clip_rows > 0:
		var src := Rect2(GX, GY, 32, clip_rows)
		ci.draw_texture_rect_region(tex, Rect2(o, src.size * s), src)
	else:
		ci.draw_texture_rect(tex, Rect2(o - Vector2(GX, GY) * s, Vector2(GW, GH) * s), false)


static func _texture(g: Grid, look: Dictionary, style: Dictionary) -> Texture2D:
	var skin: Array = SKINS[int(look.get("skin", 0)) % SKINS.size()]
	var hair: Array = HAIRS[int(look.get("hair_color", 0)) % HAIRS.size()]
	var fit: Array = OUTFITS[int(look.get("outfit", 0)) % OUTFITS.size()]
	var cols := {
		K: Color("4a3b4a"), SK: Color(skin[0]), SKS: Color(skin[1]), HR: Color(hair[0]), HRH: Color(hair[1]),
		OF: Color(fit[0]), OFS: Color(fit[1]), PT: Color("5a6480"), SH: Color("fffdf8"), EY: Color("2b2233"),
		WH: Color("ffffff"), BL: Color("ff9db0"), BAND: Color(style.get("headband", "ff7b8a")), BELT: Color("8a5a3a"),
		GOLD: Color("ffcf4a"), CAPE: Color(style.get("cape", "ff7b8a")), SWEAT: Color("8fd3ff"), MAT: Color("9fe3d0"),
		JEWEL: Color("ff5a6e"), SIL: style.get("sil", Color.BLACK),
	}
	var img := Image.create(GW, GH, false, Image.FORMAT_RGBA8)
	for i in g.px.size():
		var c: int = g.px[i]
		if c != NONE:
			img.set_pixel(i % GW, i / GW, cols[c])
	return ImageTexture.create_from_image(img)


## 자세별로 칸을 채운다.
static func build(look: Dictionary, pose: String, p: float, style: Dictionary, bob: int, blink: bool, sweat_on: bool) -> Grid:
	var g := Grid.new()
	var hair_style := int(look.get("hair", 0))
	if pose == "sleep":
		_sleep(g, hair_style)
		return g

	var c := 0  # 웅크림(칸)
	var oy := 0  # 몸 전체 위아래 이동 (매달리기)
	var arms := "down"
	var eyes := "open"
	var mouth := "w"
	var hand_y := 0.0
	var hand_top := 0
	match pose:
		"happy":
			arms = "v"
			eyes = "happy"
			mouth = "open"
		"tired":
			eyes = "line"
			mouth = "small"
			c = 1
		"refuse":
			arms = "cross"
			eyes = "half"
			mouth = "pout"
		"lift":
			c = squat_crouch(p)
			arms = "bar"
			hand_y = lift_hand_y(p)
			eyes = "strain" if p < 0.95 else "happy"
			mouth = "strain" if p < 0.95 else "open"
		"squat":
			c = squat_crouch(p)
			arms = "rack"
			eyes = "strain" if p < 0.95 else "happy"
			mouth = "strain" if p < 0.95 else "open"
		"ohs":
			c = squat_crouch(p)
			arms = "up"
			hand_top = int(overhead_y(p))
			eyes = "strain" if p < 0.95 else "happy"
			mouth = "strain" if p < 0.95 else "open"
		"hang":
			oy = -int(round(p * 12.0))
			arms = "up"
			hand_top = HANG_HAND_Y
			eyes = "strain" if p > 0.3 else "open"
			mouth = "strain" if p > 0.3 else "w"
		"support":
			oy = -34
			arms = "down"
			eyes = "happy"
			mouth = "open"
	if blink and eyes == "open":
		eyes = "blink"
	var body: String = style.get("body", "normal")
	var tw: float = {"slim": 6.0, "normal": 7.0, "wide": 8.5, "huge": 10.0, "chubby": 9.0}.get(body, 7.0)
	var y0 := oy + c + bob  # 머리·몸통 기준 이동
	var sil: bool = style.has("sil")

	# ---- 몸 뒤쪽: 망토, 묶은 머리, 올린 팔 ----
	if style.has("cape") and arms != "up":
		g.ell(16, 34 + y0, tw + 3.0, 10.0 - c * 0.5, CAPE)
		g.rect(int(16 - tw - 2), 28 + y0, int(tw * 2 + 4), 6, CAPE)
	if hair_style == 1:
		g.ell(29.5, 11 + y0, 3.5, 6.5, HR)
		g.ell(29.5, 17 + y0, 2.5, 3.5, HR)
	elif hair_style == 2:
		g.ell(16, 1 + y0, 5.5, 4.5, HR)
	if arms == "up":
		var sh := 30 + y0
		g.rect(4, hand_top, 4, sh - hand_top, SK)
		g.rect(24, hand_top, 4, sh - hand_top, SK)
		g.ell(6, hand_top, 2.5, 2.2, SK)
		g.ell(26, hand_top, 2.5, 2.2, SK)
	elif arms == "v":
		g.ell(4.5, 22 + y0, 2.6, 5.5, SK)
		g.ell(27.5, 22 + y0, 2.6, 5.5, SK)
	elif arms == "down":
		g.ell(16 - tw - 1.0, 33 + y0, 2.6, 4.6, SK)
		g.ell(16 + tw + 1.0, 33 + y0, 2.6, 4.6, SK)

	# ---- 다리 ----
	var leg_top := 37 + c
	if c > 3:
		# 깊게 앉으면 허벅지가 옆으로
		g.ell(10, 42, 4.5, 2.6, PT)
		g.ell(22, 42, 4.5, 2.6, PT)
		g.rect(8, 42, 4, 3, PT)
		g.rect(20, 42, 4, 3, PT)
		g.ell(9.5, 45.6, 3.4, 1.8, SH)
		g.ell(22.5, 45.6, 3.4, 1.8, SH)
	else:
		var lw := 5 if body == "huge" or body == "chubby" else 4
		g.rect(15 - lw, leg_top, lw, 44 - leg_top, PT)
		g.rect(17, leg_top, lw, 44 - leg_top, PT)
		g.ell(12.5, 45.6, 3.4, 1.8, SH)
		g.ell(19.5, 45.6, 3.4, 1.8, SH)
		if style.get("sleeves", false):
			g.rect(15 - lw, 41, lw, 2, EY)
			g.rect(17, 41, lw, 2, EY)

	# ---- 몸통 ----
	var ty := 33.5 + y0
	if body == "chubby":
		g.ell(16, ty + 1.0, tw, 7.0, OF)
	else:
		g.ell(16, ty, tw, 6.2, OF)
	g.swap_in(0, int(ty) + 3, 32, int(ty) + 9, [OF], OFS)
	if not sil:
		# 가슴의 하트 로고
		var hy := int(ty) - 3
		for q in [Vector2i(14, 0), Vector2i(15, 0), Vector2i(17, 0), Vector2i(18, 0), Vector2i(14, 1), Vector2i(15, 1), Vector2i(16, 1), Vector2i(17, 1), Vector2i(18, 1), Vector2i(15, 2), Vector2i(16, 2), Vector2i(17, 2), Vector2i(16, 3)]:
			g.put(q.x, hy + q.y, WH)
	if style.get("belt", false):
		g.swap_in(0, int(ty) + 3, 32, int(ty) + 5, [OF, OFS, WH], BELT)
		g.rect(15, int(ty) + 3, 2, 2, GOLD)
	if style.get("wrist", false) and arms == "down":
		g.rect(int(16 - tw - 3), 36 + y0, 4, 1, WH)
		g.rect(int(16 + tw - 1), 36 + y0, 4, 1, WH)

	# ---- 몸통 앞 팔 ----
	match arms:
		"bar":
			g.rect(8, 30 + y0, 3, int(hand_y) - 30 - y0, SK)
			g.rect(21, 30 + y0, 3, int(hand_y) - 30 - y0, SK)
			g.ell(9.5, hand_y, 2.2, 2.0, SK)
			g.ell(22.5, hand_y, 2.2, 2.0, SK)
		"cross":
			g.ell(16, 34 + y0, tw + 1.5, 2.6, SK)
		"rack":
			g.ell(9, 29 + y0, 2.6, 2.8, SK)
			g.ell(23, 29 + y0, 2.6, 2.8, SK)

	# ---- 머리 ----
	var hcy := 14.0 + y0
	g.ell(16, hcy, 13.0, 12.0, SK)
	_hair(g, hair_style, y0)
	if style.has("headband"):
		g.swap_in(0, 8 + y0, 32, 10 + y0, [HR, HRH, SK, SKS], BAND)
		g.rect(28, 7 + y0, 3, 2, BAND)
		g.put(30, 9 + y0, BAND)
	if style.get("crown", false):
		g.rect(10, -1 + y0, 12, 3, GOLD)
		for x in [10, 13, 18, 21]:
			g.put(x, -2 + y0, GOLD)
		g.put(15, -3 + y0, GOLD)
		g.put(16, -3 + y0, GOLD)
		g.put(15, -2 + y0, GOLD)
		g.put(16, -2 + y0, GOLD)

	g.outline()
	if sil:
		for i in g.px.size():
			if g.px[i] != NONE:
				g.px[i] = SIL
		return g

	# ---- 얼굴 (외곽선 다음) ----
	if style.get("crown", false):
		g.put(15, 0 + y0, JEWEL)
		g.put(16, 0 + y0, JEWEL)
	_face(g, eyes, mouth, 15 + y0, body == "chubby")
	if style.get("glasses", false):
		for ex in [8, 19]:
			for i in 5:
				g.put(ex + i, 14 + y0, EY)
				g.put(ex + i, 19 + y0, EY)
			for j in 6:
				g.put(ex, 14 + y0 + j, EY)
				g.put(ex + 4, 14 + y0 + j, EY)
		g.rect(13, 16 + y0, 6, 1, EY)
	if style.get("bandage", false):
		g.rect(21, 5 + y0, 4, 2, WH)
		g.rect(22, 4 + y0, 2, 4, WH)
	if sweat_on:
		g.put(28, 12 + y0, SWEAT)
		g.rect(27, 13 + y0, 3, 2, SWEAT)
	return g


static func _hair(g: Grid, style: int, y0: int) -> void:
	var cut := 7 if style == 3 else 10
	for y in range(1 + y0, cut + y0):
		for x in range(2, 30):
			var a := (x + 0.5 - 16.0) / 13.6
			var b := (y + 0.5 - 13.6 - y0) / 12.6
			if a * a + b * b <= 1.0:
				g.put(x, y, HR)
	if style == 3:
		# 짧고 삐죽한 스포츠 머리
		for x in [9, 13, 17, 21]:
			g.put(x, 0 + y0, HR)
			g.put(x + 1, 0 + y0, HR)
			g.put(x, -1 + y0, HR)
	else:
		# 옆머리와 앞머리
		g.rect(3, 10 + y0, 2, 8, HR)
		g.rect(27, 10 + y0, 2, 8, HR)
		g.rect(5, 10 + y0, 4, 2, HR)
		g.rect(23, 10 + y0, 4, 2, HR)
		g.rect(13, 10 + y0, 3, 2, HR)
		g.put(14, 12 + y0, HR)
		g.rect(18, 10 + y0, 2, 1, HR)
	# 하이라이트, 머리카락 아래 그늘
	g.rect(9, 4 + y0, 4, 1, HRH)
	g.rect(8, 5 + y0, 2, 1, HRH)
	for x in range(3, 30):
		for y in range(5 + y0, 15 + y0):
			if g.at(x, y) == SK and g.at(x, y - 1) == HR:
				g.put(x, y, SKS)


static func _face(g: Grid, eyes: String, mouth: String, y: int, chubby: bool) -> void:
	for ex in [9, 20]:
		match eyes:
			"open":
				g.rect(ex, y, 3, 4, EY)
				g.put(ex, y, WH)
				g.put(ex + 2, y + 2, WH)
			"blink", "line":
				g.rect(ex, y + 2, 3, 1, EY)
			"happy":
				g.put(ex, y + 2, EY)
				g.put(ex + 1, y + 1, EY)
				g.put(ex + 2, y + 2, EY)
			"half":
				g.rect(ex, y + 2, 3, 2, EY)
				g.put(ex, y + 2, WH)
			"strain":
				var dir := 1 if ex < 16 else -1
				var sx: int = ex if dir > 0 else ex + 2
				g.put(sx, y, EY)
				g.put(sx + dir, y + 1, EY)
				g.put(sx + dir * 2, y + 2, EY)
				g.put(sx + dir, y + 3, EY)
				g.put(sx, y + 4, EY)
	# 볼터치
	var bw := 4 if chubby else 3
	g.rect(8 - bw + 1, y + 5, bw, 1, BL)
	g.rect(23, y + 5, bw, 1, BL)
	match mouth:
		"w":
			for q in [Vector2i(14, 6), Vector2i(15, 7), Vector2i(16, 6), Vector2i(17, 7), Vector2i(18, 6)]:
				g.put(q.x, y + q.y, EY)
		"open":
			g.rect(15, y + 6, 3, 2, EY)
			g.put(16, y + 7, BL)
		"small":
			g.rect(15, y + 7, 2, 1, EY)
		"pout":
			g.put(15, y + 7, EY)
			g.put(16, y + 6, EY)
			g.put(17, y + 7, EY)
		"strain":
			g.rect(14, y + 7, 5, 1, EY)


## 매트 위에 누워 자는 모습.
static func _sleep(g: Grid, hair_style: int) -> void:
	g.rect(-6, 44, 44, 3, MAT)
	g.ell(27, 40, 8.5, 4.6, OF)
	g.rect(33, 38, 5, 5, PT)
	g.ell(9, 36, 10.5, 9.5, SK)
	for y in range(26, 47):
		for x in range(-2, 5):
			if g.at(x, y) == SK:
				g.put(x, y, HR)
	if hair_style == 1:
		g.ell(-2, 40, 3, 4, HR)
	g.outline()
	g.rect(-6, 44, 44, 3, MAT)
	g.rect(6, 35, 3, 1, EY)
	g.rect(12, 35, 3, 1, EY)
	g.rect(4, 38, 3, 1, BL)
	g.rect(14, 38, 3, 1, BL)
	g.rect(9, 40, 2, 1, EY)
