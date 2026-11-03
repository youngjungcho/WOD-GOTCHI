class_name LiftGame
extends Screen
## 1RM 챌린지. A/B를 연타해서 바를 끝까지 끌어올린다.
## 무게/역량 비율이 클수록 바가 무겁게 내려가고, 스티킹 포인트에서 저항이 커진다.

const TIME_LIMIT := 7.0
const TAP_POWER := 0.065
const BASE_GRAVITY := 0.24
const STICK_FROM := 0.35
const STICK_TO := 0.6
const STICK_MULT := 1.7

var weight: float
var capacity: float
var _ratio: float
var _pos := 0.0
var _state := "ready"  # ready, lift, done
var _clock := 0.0
var _taps := 0
var _success := false
var _shake := 0.0


func _init(p_weight: float) -> void:
	super()
	weight = p_weight
	capacity = GameState.lift_capacity("deadlift")
	_ratio = weight / capacity


func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	_shake = max(0.0, _shake - delta * 8.0)
	match _state:
		"ready":
			if _clock >= 2.4:
				_state = "lift"
				_clock = 0.0
				Sfx.play("select")
		"lift":
			var g := BASE_GRAVITY * pow(_ratio, 3.0)
			if _pos > STICK_FROM and _pos < STICK_TO:
				g *= STICK_MULT
			if _pos > 0.0:
				_pos = max(0.0, _pos - g * delta)
			if _pos >= 1.0:
				_finish(true)
			elif _clock >= TIME_LIMIT:
				_finish(false)


func _finish(ok: bool) -> void:
	_state = "done"
	_success = ok
	_pos = 1.0 if ok else _pos
	GameState.use_attempt()
	var msgs: Array = []
	var xp := {"str": 6.0, "tec": 2.0}
	if ok:
		Sfx.play("success")
		var old := float(GameState.data.pr.get("deadlift", 0))
		if weight > old:
			GameState.data.pr.deadlift = weight
			msgs.append("NEW PR! 데드리프트 %skg!" % Pal.num(weight))
			xp = {"str": 20.0 * _ratio, "tec": 6.0}
		else:
			msgs.append("성공! %skg 들었어요." % Pal.num(weight))
			xp = {"str": 10.0, "tec": 3.0}
	else:
		Sfx.play("fail")
		msgs.append("실패... %skg은 아직 무거웠어요." % Pal.num(weight))
	msgs.append_array(GameState.apply_workout(xp, 12.0, 6.0))
	main.say("\n".join(msgs), func(): main.pop())


func _tap() -> void:
	if _state != "lift":
		return
	_taps += 1
	var tec_bonus := 1.0 + 0.01 * GameState.level("tec")
	var fatigue := 1.0 - _clock / (TIME_LIMIT + 2.0)
	_pos = min(1.0, _pos + TAP_POWER * fatigue * tec_bonus)
	_shake = 1.0
	Sfx.play("tap")


func on_button(btn: String, down: bool) -> void:
	if not down:
		return
	if btn == "a" or btn == "b":
		_tap()


func on_tap(_p: Vector2) -> void:
	_tap()


func _draw() -> void:
	var scene := Rect2(0, 0, size.x, 170)
	Pal.box_scene(self, scene, t)
	var floor_y := scene.size.y * 0.68
	var cx := 76.0
	var o := Vector2(cx - 16, floor_y - 44)
	if _shake > 0.0:
		o.x += (1 if int(t * 40) % 2 == 0 else -1)
	Pal.athlete(self, o, GameState.data.look, "lift", 2, t, _pos, GameState.is_muscular())
	var hand_y := o.y + lerpf(20.0, 15.0, _pos) * 2 + 1
	var plates := clampi(int(weight / 30.0), 1, 5)
	Pal.barbell(self, Vector2(cx, hand_y), 34, plates)

	# 오른쪽 게이지: 바 높이와 스티킹 포인트
	var g := Rect2(150, 16, 14, 96)
	draw_rect(g, Pal.INK)
	draw_rect(g.grow(-1), Pal.WHITE)
	var stick := Rect2(g.position.x + 1, g.end.y - 1 - (g.size.y - 2) * STICK_TO, g.size.x - 2, (g.size.y - 2) * (STICK_TO - STICK_FROM))
	draw_rect(stick, Color(Pal.RED, 0.3))
	var fill := (g.size.y - 2) * _pos
	draw_rect(Rect2(g.position.x + 1, g.end.y - 1 - fill, g.size.x - 2, fill), Pal.GREEN)
	Pal.text(self, Vector2(g.position.x - 2, g.position.y - 13), "TOP", Pal.INK)

	# 정보창
	var r := Rect2(2, 172, size.x - 4, size.y - 174)
	Pal.window(self, r)
	Pal.text(self, r.position + Vector2(8, 5), "데드리프트 %skg" % Pal.num(weight), Pal.INK)
	match _state:
		"ready":
			var n := 3 - int(_clock / 0.8)
			Pal.text(self, r.position + Vector2(8, 20), "그립 잡고... %d" % max(n, 1), Pal.RED)
			Pal.text(self, r.position + Vector2(8, 34), "A·B 버튼(화면)을 연타!", Pal.DARK)
		"lift":
			Pal.text(self, r.position + Vector2(8, 20), "연타!! 연타!!" if int(t * 6) % 2 == 0 else "", Pal.RED)
			Pal.bar(self, Rect2(r.position.x + 8, r.position.y + 36, r.size.x - 16, 8), 1.0 - _clock / TIME_LIMIT, Pal.BLUE)
			Pal.text(self, r.position + Vector2(8, 46), "%d회 연타" % _taps, Pal.DARK)
		"done":
			Pal.text(self, r.position + Vector2(8, 20), "GOOD LIFT!" if _success else "NO LIFT", Pal.GREEN if _success else Pal.RED)
