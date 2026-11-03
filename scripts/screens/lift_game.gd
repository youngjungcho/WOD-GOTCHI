class_name LiftGame
extends Screen
## 1RM 챌린지. 종목마다 단계(phase)가 다르다.
##   mash    : A/B 연타로 바를 끌어올린다. 스티킹 포인트에서 저항이 커진다.
##   descend : (스쿼트) 내려가다가 깊이 존에서 A. 너무 빠르면 No Rep, 정확하면 반동 보너스.
##   catch   : (클린·스내치) 움직이는 커서를 존에 맞춰 A로 받는다. 무거울수록 존이 좁고 커서가 빠르다.
##   balance : (스내치) A·B를 번갈아 눌러 중심을 잡으며 일어선다. 같은 버튼을 두 번 누르면 흔들린다.

const TAP_POWER := 0.065
const BASE_GRAVITY := 0.24
const STICK_MULT := 1.7

const LIFTS := {
	"deadlift": {
		"phases": [{"type": "mash", "time": 7.0, "stick": [0.35, 0.6], "grav": 1.0, "label": "당기기!"}],
		"xp": {"str": 20.0, "tec": 4.0},
	},
	"squat": {
		"phases": [{"type": "descend"}, {"type": "mash", "time": 6.0, "stick": [0.2, 0.45], "grav": 1.0, "label": "일어서기!"}],
		"xp": {"str": 18.0, "tec": 3.0, "eng": 2.0},
	},
	"clean": {
		"phases": [
			{"type": "mash", "time": 4.0, "stick": [0.5, 0.7], "grav": 0.8, "label": "당기기!"},
			{"type": "catch", "width": 0.24},
			{"type": "mash", "time": 5.0, "stick": [0.25, 0.5], "grav": 0.85, "label": "일어서기!"},
		],
		"xp": {"str": 14.0, "tec": 12.0},
	},
	"snatch": {
		"phases": [
			{"type": "mash", "time": 3.5, "stick": [0.5, 0.7], "grav": 0.75, "label": "당기기!"},
			{"type": "catch", "width": 0.16},
			{"type": "balance", "taps": 8, "time": 4.0},
		],
		"xp": {"str": 10.0, "tec": 16.0, "gym": 2.0},
	},
}

var lift: String
var weight: float
var capacity: float
var _ratio: float
var _phases: Array
var _pi := -1  # 현재 단계 번호
var _state := "ready"  # ready, play, done
var _clock := 0.0
var _taps := 0
var _shake := 0.0
var _success := false
var _fail_msg := ""
var _note := ""  # 단계 결과 한 줄 (예: PERFECT 캐치!)
var _note_t := -10.0

# 단계별 상태
var _pos := 0.0  # mash 진행도
var _bonus := 0.0  # 다음 mash 시작 보너스
var _depth := 0.0  # descend 깊이
var _cur := 0.0  # catch 커서
var _zone := 0.65  # catch 존 중심
var _width := 0.2
var _bal_done := 0
var _bal_next := "a"
var _wobble := 0.0


func _init(p_lift: String, p_weight: float) -> void:
	super()
	lift = p_lift
	weight = p_weight
	capacity = GameState.lift_capacity(lift)
	_ratio = weight / capacity
	_phases = LIFTS[lift].phases


func _phase() -> Dictionary:
	return _phases[_pi] if _pi >= 0 and _pi < _phases.size() else {}


func _start_phase(i: int) -> void:
	_pi = i
	_clock = 0.0
	var ph := _phase()
	match ph.type:
		"mash":
			_pos = _bonus
			_bonus = 0.0
		"descend":
			_depth = 0.0
		"catch":
			_cur = 0.0
			_zone = randf_range(0.55, 0.8)
			var tec_bonus := 1.0 + 0.06 * (GameState.level("tec") - 1)
			_width = clampf(float(ph.width) * tec_bonus / pow(_ratio, 2.0), 0.05, 0.45)
		"balance":
			_bal_done = 0
			_bal_next = "a"
			_wobble = 0.0
	Sfx.play("select")


func _next_phase() -> void:
	if _pi + 1 >= _phases.size():
		_finish(true)
	else:
		_start_phase(_pi + 1)


func _note_text(s: String) -> void:
	_note = s
	_note_t = t


func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	_shake = max(0.0, _shake - delta * 8.0)
	if _state == "ready":
		if _clock >= 2.4:
			_state = "play"
			_start_phase(0)
		return
	if _state != "play":
		return
	var ph := _phase()
	match ph.type:
		"mash":
			var g := BASE_GRAVITY * pow(_ratio, 3.0) * float(ph.grav)
			if _pos > ph.stick[0] and _pos < ph.stick[1]:
				g *= STICK_MULT
			if _pos > 0.0:
				_pos = max(0.0, _pos - g * delta)
			if _clock >= float(ph.time):
				_finish(false, "힘이 다 빠졌어요...")
		"descend":
			_depth += delta / 1.6
			if _depth >= 1.25:
				# 바닥에서 너무 오래 머물렀다: 보너스 없이 일어서기
				_note_text("너무 깊이 주저앉았어요!")
				_next_phase()
		"catch":
			_cur += delta * (0.55 + 0.35 * _ratio)
			if _cur >= 1.05:
				_finish(false, "받을 타이밍을 놓쳤어요!")
		"balance":
			_wobble = max(0.0, _wobble - delta * 0.35)
			if _clock >= float(ph.time):
				_finish(false, "버티지 못하고 바를 떨어뜨렸어요!")


func _finish(ok: bool, why: String = "") -> void:
	if _state == "done":
		return
	_state = "done"
	_success = ok
	_fail_msg = why
	GameState.use_attempt(lift)
	var lift_name: String = GameState.LIFTS[lift]
	var msgs: Array = []
	var base: Dictionary = LIFTS[lift].xp
	var xp := {}
	if ok:
		Sfx.play("success")
		if weight > GameState.pr(lift):
			GameState.data.pr[lift] = weight
			msgs.append("NEW PR! %s %skg!" % [lift_name, Pal.num(weight)])
			for s in base:
				xp[s] = base[s] * _ratio
		else:
			msgs.append("성공! %s %skg." % [lift_name, Pal.num(weight)])
			for s in base:
				xp[s] = base[s] * 0.5
	else:
		Sfx.play("fail")
		msgs.append("실패... %s" % why)
		for s in base:
			xp[s] = base[s] * 0.25
	msgs.append_array(GameState.apply_workout(xp, 12.0, 6.0, false))
	var msg := "\n".join(msgs)
	# 결과 자세를 잠깐 보여준 뒤 메시지
	get_tree().create_timer(0.9).timeout.connect(func(): main.say(msg, func(): main.pop()))


func _press(btn: String) -> void:
	if _state != "play":
		return
	var ph := _phase()
	match ph.type:
		"mash":
			_taps += 1
			var tec_bonus := 1.0 + 0.01 * GameState.level("tec")
			var fatigue := 1.0 - _clock / (float(ph.time) + 2.0)
			_pos = min(1.0, _pos + TAP_POWER * fatigue * tec_bonus)
			_shake = 1.0
			Sfx.play("tap")
			# 꼭대기에 닿는 순간 성공 (중력 계산보다 먼저)
			if _pos >= 1.0:
				_next_phase()
		"descend":
			if btn != "a":
				return
			if _depth < 0.8:
				_finish(false, "깊이 부족! No Rep")
				return
			if _depth >= 0.92 and _depth <= 1.0:
				_bonus = 0.12
				_note_text("PERFECT 반동!")
				Sfx.play("perfect")
			else:
				_note_text("GOOD 깊이")
				Sfx.play("good")
			_next_phase()
		"catch":
			if btn != "a":
				return
			var d: float = abs(_cur - _zone)
			if d <= _width * 0.125:
				_bonus = 0.15
				_note_text("PERFECT 캐치!")
				Sfx.play("perfect")
			elif d <= _width * 0.5:
				_note_text("GOOD 캐치")
				Sfx.play("good")
			else:
				_finish(false, "바를 제대로 받지 못했어요!")
				return
			_next_phase()
		"balance":
			if btn == _bal_next:
				_bal_done += 1
				_bal_next = "b" if _bal_next == "a" else "a"
				Sfx.play("tap")
				if _bal_done >= int(ph.taps):
					_next_phase()
			else:
				_wobble += 0.4 * _ratio
				Sfx.play("miss")
				if _wobble >= 1.0:
					_finish(false, "중심을 잃었어요!")


func on_button(btn: String, down: bool) -> void:
	if down and (btn == "a" or btn == "b"):
		_press(btn)


func on_tap(_p: Vector2) -> void:
	_press("a")


# ---------- 그리기 ----------

## 지금 단계에 맞는 자세, 진행도, 바 위치(손/어깨/머리 위/바닥).
func _pose_info() -> Dictionary:
	var typ: String = _phase().get("type", "")
	if _state == "done":
		if not _success:
			return {"pose": "tired", "p": 0.0, "bar": "floor"}
		match lift:
			"deadlift":
				return {"pose": "lift", "p": 1.0, "bar": "hand"}
			"snatch":
				return {"pose": "ohs", "p": 1.0, "bar": "over"}
			_:
				return {"pose": "squat", "p": 1.0, "bar": "shoulder"}
	match lift:
		"deadlift":
			return {"pose": "lift", "p": _pos, "bar": "hand"}
		"squat":
			if typ == "descend" or _state == "ready":
				return {"pose": "squat", "p": 1.0 - clampf(_depth, 0.0, 1.0), "bar": "shoulder"}
			return {"pose": "squat", "p": _pos, "bar": "shoulder"}
		"clean":
			if _pi <= 0:
				return {"pose": "lift", "p": _pos, "bar": "hand"}
			if typ == "catch":
				return {"pose": "lift", "p": 1.0, "bar": "hand"}
			return {"pose": "squat", "p": _pos, "bar": "shoulder"}
		"snatch":
			if _pi <= 0:
				return {"pose": "lift", "p": _pos, "bar": "hand"}
			if typ == "catch":
				return {"pose": "lift", "p": 1.0, "bar": "hand"}
			return {"pose": "ohs", "p": float(_bal_done) / 8.0 * 0.6, "bar": "over"}
	return {"pose": "idle", "p": 0.0, "bar": "floor"}


func _draw() -> void:
	var scene := Rect2(0, 0, size.x, 170)
	Pal.box_scene(self, scene, t)
	var floor_y := scene.size.y * 0.68
	var cx := 76.0
	var o := Vector2(cx - 16, floor_y - 44)
	if _shake > 0.0:
		o.x += (1 if int(t * 40) % 2 == 0 else -1)
	if _phase().get("type", "") == "balance":
		o.x += round(sin(t * 18.0) * _wobble * 3.0)
	var info := _pose_info()
	Pal.athlete(self, o, GameState.data.look, info.pose, 2, t, info.p, GameState.style())
	var plates := clampi(int(weight / 30.0), 1, 5)
	var bar_y := floor_y - 6
	match info.bar:
		"hand":
			bar_y = o.y + lerpf(20.0, 15.0, info.p) * 2 + 1
		"shoulder":
			bar_y = o.y + (8 + Pal.squat_crouch(info.p)) * 2 - 1
		"over":
			bar_y = o.y + (-6 + Pal.squat_crouch(info.p)) * 2
	Pal.barbell(self, Vector2(cx, bar_y), 34, plates)
	_draw_meter()
	if t - _note_t < 0.8:
		Pal.text(self, Vector2(8, 8), _note, Pal.RED)

	# 정보창
	var r := Rect2(2, 172, size.x - 4, size.y - 174)
	Pal.window(self, r)
	Pal.text(self, r.position + Vector2(8, 5), "%s %skg" % [GameState.LIFTS[lift], Pal.num(weight)], Pal.INK)
	var step := "%d/%d" % [maxi(_pi + 1, 1), _phases.size()]
	Pal.text(self, Vector2(r.end.x - 8 - Pal.text_width(step), r.position.y + 5), step, Pal.DARK)
	match _state:
		"ready":
			var n := 3 - int(_clock / 0.8)
			var steps := []
			for ph in _phases:
				steps.append(_phase_name(ph))
			Pal.text(self, r.position + Vector2(8, 20), "준비... %d" % maxi(n, 1), Pal.RED)
			Pal.text(self, r.position + Vector2(8, 34), " → ".join(steps), Pal.DARK)
		"play":
			_draw_help(r)
		"done":
			Pal.text(self, r.position + Vector2(8, 20), "GOOD LIFT!" if _success else "NO LIFT", Pal.GREEN if _success else Pal.RED)
			if not _success:
				Pal.text(self, r.position + Vector2(8, 34), _fail_msg, Pal.DARK)


static func _phase_name(ph: Dictionary) -> String:
	match ph.type:
		"mash":
			return "연타"
		"descend":
			return "깊이"
		"catch":
			return "받기"
		"balance":
			return "균형"
	return ""


func _draw_help(r: Rect2) -> void:
	var ph := _phase()
	match ph.type:
		"mash":
			Pal.text(self, r.position + Vector2(8, 20), str(ph.label) + (" 연타!!" if int(t * 6) % 2 == 0 else ""), Pal.RED)
			Pal.bar(self, Rect2(r.position.x + 8, r.position.y + 36, r.size.x - 16, 8), 1.0 - _clock / float(ph.time), Pal.BLUE)
			Pal.text(self, r.position + Vector2(8, 46), "%d회 연타" % _taps, Pal.DARK)
		"descend":
			Pal.text(self, r.position + Vector2(8, 20), "내려가는 중...", Pal.INK)
			Pal.text(self, r.position + Vector2(8, 34), "초록 깊이에서 A!", Pal.RED)
		"catch":
			Pal.text(self, r.position + Vector2(8, 20), "바가 떠올랐다!", Pal.INK)
			Pal.text(self, r.position + Vector2(8, 34), "존에 맞춰 A로 받기!", Pal.RED)
		"balance":
			Pal.text(self, r.position + Vector2(8, 20), "중심 잡고 일어서기!", Pal.INK)
			Pal.text(self, r.position + Vector2(8, 34), "A·B 번갈아!  %d/%d" % [_bal_done, int(ph.taps)], Pal.RED)
			Pal.bar(self, Rect2(r.position.x + 8, r.position.y + 48, r.size.x - 16, 6), 1.0 - _clock / float(ph.time), Pal.BLUE)


## 단계별 게이지.
func _draw_meter() -> void:
	if _state == "done":
		return
	var g := Rect2(150, 16, 14, 96)
	var ph := _phase()
	var typ: String = ph.get("type", "mash" if _state == "ready" else "")
	match typ:
		"mash":
			draw_rect(g, Pal.INK)
			draw_rect(g.grow(-1), Pal.WHITE)
			var st: Array = ph.get("stick", [0.35, 0.6])
			var stick := Rect2(g.position.x + 1, g.end.y - 1 - (g.size.y - 2) * float(st[1]), g.size.x - 2, (g.size.y - 2) * (float(st[1]) - float(st[0])))
			draw_rect(stick, Color(Pal.RED, 0.3))
			var fill := (g.size.y - 2) * _pos
			draw_rect(Rect2(g.position.x + 1, g.end.y - 1 - fill, g.size.x - 2, fill), Pal.GREEN)
			Pal.text(self, Vector2(g.position.x - 2, g.position.y - 13), "TOP", Pal.INK)
		"descend":
			# 위에서 아래로 내려가는 깊이 게이지
			draw_rect(g, Pal.INK)
			draw_rect(g.grow(-1), Pal.WHITE)
			var h := g.size.y - 2
			draw_rect(Rect2(g.position.x + 1, g.position.y + 1 + h * 0.8 / 1.25, g.size.x - 2, h * 0.2 / 1.25), Color(Pal.GREEN, 0.5))
			draw_rect(Rect2(g.position.x + 1, g.position.y + 1 + h * 0.92 / 1.25, g.size.x - 2, h * 0.08 / 1.25), Pal.YELLOW)
			var y := g.position.y + 1 + h * clampf(_depth, 0.0, 1.25) / 1.25
			draw_rect(Rect2(g.position.x - 3, y - 1, g.size.x + 6, 3), Pal.INK)
			Pal.text(self, Vector2(g.position.x - 3, g.end.y + 2), "깊이", Pal.WHITE)
		"catch":
			# 가로 받기 게이지
			var cr := Rect2(10, 128, 160, 14)
			draw_rect(cr, Pal.INK)
			draw_rect(cr.grow(-1), Pal.WHITE)
			var w := cr.size.x - 2
			draw_rect(Rect2(cr.position.x + 1 + w * (_zone - _width * 0.5), cr.position.y + 1, w * _width, cr.size.y - 2), Color(Pal.GREEN, 0.6))
			draw_rect(Rect2(cr.position.x + 1 + w * (_zone - _width * 0.125), cr.position.y + 1, w * _width * 0.25, cr.size.y - 2), Pal.YELLOW)
			var x := cr.position.x + 1 + w * clampf(_cur, 0.0, 1.0)
			draw_rect(Rect2(x - 1, cr.position.y - 3, 3, cr.size.y + 6), Pal.RED)
		"balance":
			# 흔들림 게이지 + 다음에 누를 버튼
			draw_rect(g, Pal.INK)
			draw_rect(g.grow(-1), Pal.WHITE)
			var fill := (g.size.y - 2) * clampf(_wobble, 0.0, 1.0)
			draw_rect(Rect2(g.position.x + 1, g.end.y - 1 - fill, g.size.x - 2, fill), Pal.RED)
			Pal.text(self, Vector2(g.position.x - 10, g.end.y + 2), "흔들림", Pal.WHITE)
			var bc := Vector2(126, 40)
			draw_circle(bc, 11, Pal.INK)
			draw_circle(bc, 10, Pal.RED if _bal_next == "a" else Pal.BLUE)
			Pal.text_center(self, Rect2(bc.x - 10, bc.y - 7, 20, 14), _bal_next.to_upper(), Pal.WHITE)
