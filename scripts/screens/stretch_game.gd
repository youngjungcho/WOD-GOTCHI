class_name StretchGame
extends Screen
## 스트레칭 균형 미니게임. 몸이 좌우로 흔들리는 걸 B(왼쪽 버튼)·A(오른쪽 버튼)를 눌러 버티며
## 가운데 초록 구간에 오래 머물수록 컨디션이 많이 회복된다. 에너지는 쓰지 않는다.

const DURATION := 12.0
const GOAL := 7.0  # 초록 구간에 이만큼 있으면 만점
const ZONE := 0.35

var _m := 0.0  # 균형 위치 -1(왼쪽) ~ 1(오른쪽)
var _v := 0.0
var _hold_a := false
var _hold_b := false
var _in_zone := 0.0
var _clock := 0.0
var _started := false
var _ended := false
var _drift := 0.0


func _process(delta: float) -> void:
	super(delta)
	if _ended:
		return
	if not _started:
		if t > 1.6:
			_started = true
		return
	_clock += delta
	# 흔들림: 천천히 방향이 바뀌는 바람 + 누르는 힘
	_drift = lerpf(_drift, sin(_clock * 1.3) * 0.9 + sin(_clock * 3.1) * 0.5, delta * 2.0)
	var push := (-1.6 if _hold_b else 0.0) + (1.6 if _hold_a else 0.0)
	_v += (_drift + push) * delta * 1.4
	_v *= 0.96
	_m = clampf(_m + _v * delta, -1.0, 1.0)
	if absf(_m) <= ZONE:
		_in_zone += delta
	if _clock >= DURATION:
		_ended = true
		var score := clampf(_in_zone / GOAL, 0.0, 1.0)
		Sfx.play("success" if score >= 0.7 else "good")
		var msg := GameState.stretch_result(score)
		main.say(msg, func(): main.pop())


func button_labels() -> Dictionary:
	return {"a": "오른쪽▶", "b": "◀왼쪽", "menu": "그만"}


func on_button(btn: String, down: bool) -> void:
	match btn:
		"a":
			_hold_a = down
		"b":
			_hold_b = down
		"menu":
			if down and not _ended:
				Sfx.play("back")
				main.pop()


func on_tap(pos: Vector2) -> void:
	# 화면 왼쪽/오른쪽 터치로도 잠깐 밀기
	if pos.x < size.x * 0.5:
		_v -= 0.4
	else:
		_v += 0.4


func _draw() -> void:
	var scene := Rect2(0, 0, size.x, 170)
	Pal.box_scene(self, scene, t, 0.8)
	var floor_y := scene.size.y * 0.8
	var lean := _m * 10.0
	Pal.athlete(self, Vector2(58 + lean * 1.6, floor_y - 92), GameState.data.look, "ohs" if absf(_m) <= ZONE else "tired", 2, t, 0.7, GameState.style())
	# 균형 게이지
	var r := Rect2(14, 150, size.x - 28, 14)
	Pal.round_rect(self, r, Pal.INK)
	draw_rect(r.grow(-1), Pal.WHITE)
	var iw := r.size.x - 2
	var zx := r.position.x + 1 + iw * (0.5 - ZONE * 0.5)
	draw_rect(Rect2(zx, r.position.y + 1, iw * ZONE, r.size.y - 2), Color(Pal.GREEN, 0.55))
	var mx := r.position.x + 1 + iw * (_m + 1.0) * 0.5
	draw_rect(Rect2(mx - 1, r.position.y - 3, 3, r.size.y + 6), Pal.RED)
	var info := Rect2(2, 172, size.x - 4, size.y - 174)
	Pal.window(self, info)
	Pal.text(self, info.position + Vector2(8, 5), "스트레칭 균형 잡기", Pal.INK)
	if not _started:
		Pal.text(self, info.position + Vector2(8, 19), "준비...", Pal.RED)
	else:
		Pal.bar(self, Rect2(info.position.x + 8, info.position.y + 21, info.size.x - 16, 7), _in_zone / GOAL, Pal.MINT.darkened(0.2))
		Pal.bar(self, Rect2(info.position.x + 8, info.position.y + 31, info.size.x - 16, 4), 1.0 - _clock / DURATION, Pal.BLUE)
	Pal.text(self, info.position + Vector2(8, 40), "B 왼쪽  A 오른쪽 (꾹 누르기)", Pal.DARK)
