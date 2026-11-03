class_name RhythmGame
extends Screen
## 체조 동작 리듬게임. 동작마다 리듬 패턴(Moves.LIST[id].rhythm)이 다르다.
## 노트가 오른쪽에서 왼쪽 판정선으로 흘러온다. A/B 탭, 노란 띠는 길게 누르기.
## WOD 구간으로 쓸 때는 on_done(reps)을 넘겨준다.

const LEAD_BEATS := 4
const LANE_Y := 150.0
const HIT_X := 24.0
const SPEED := 70.0  # px/초
const MAX_COMBO_MISS := 3

var move_id: String
var target_reps: int
var on_done: Callable

var _bpm: float
var _each: bool
var _notes: Array = []  # {t, btn, end(-1이면 단타), rep(이 노트가 1회를 완성하는지), state: 0대기 1성공 2실패, holding}
var _start_us := 0
var _perfect_win: float
var _good_win: float
var _reps := 0
var _perfects := 0
var _miss_streak := 0
var _judge := ""
var _judge_t := -10.0
var _lift_anim := 0.0  # 0~1, 몸이 올라간 정도
var _finished := false
var _fell := false
var _next_tick := 0


func _init(p_move: String, reps: int = 0, p_on_done: Callable = Callable()) -> void:
	super()
	move_id = p_move
	on_done = p_on_done
	var gym := GameState.level("gym")
	target_reps = reps if reps > 0 else Moves.default_reps(move_id)
	var rh: Dictionary = Moves.LIST[move_id].rhythm
	_bpm = float(rh.bpm)
	_each = rh.get("each", false)
	_perfect_win = 0.06 + gym * 0.003
	_good_win = 0.13 + gym * 0.005
	_build_chart(String(rh.pat))


func _beat() -> float:
	return 60.0 / _bpm


func _build_chart(pat: String) -> void:
	var b := _beat()
	var beat := float(LEAD_BEATS)
	var reps_left := target_reps
	var last_note := -1
	for i in pat.length():
		if pat[i] != ".":
			last_note = i
	while reps_left > 0:
		for i in pat.length():
			var c := pat[i]
			if c != ".":
				var hold := c == c.to_upper()
				var rep := _each or i == last_note
				_notes.append({
					"t": beat * b,
					"btn": c.to_lower(),
					"end": (beat + 1.0) * b if hold else -1.0,
					"rep": rep,
					"state": 0,
					"holding": false,
				})
				if rep:
					reps_left -= 1
					if reps_left <= 0:
						break
			beat += 2.0 if c == c.to_upper() and c != "." else 1.0
		beat += 0.5  # 패턴 사이 숨 고르기


func _ready() -> void:
	_start_us = Time.get_ticks_usec()


func _now() -> float:
	return (Time.get_ticks_usec() - _start_us) / 1000000.0


func _process(delta: float) -> void:
	super(delta)
	if _finished:
		return
	var now := _now()
	# 메트로놈
	var beat_i := int(floor(now / _beat()))
	if beat_i >= _next_tick:
		_next_tick = beat_i + 1
		if beat_i < LEAD_BEATS:
			Sfx.play("tick")
	# 놓친 노트 / 홀드 완료 처리
	for n in _notes:
		if n.state == 0 and now > n.t + _good_win:
			_miss(n)
		elif n.state == 1 and n.holding and now >= n.end:
			n.holding = false
			_complete_rep(n, n.get("perfect", false))
	_lift_anim = move_toward(_lift_anim, 0.0, delta * 2.2)
	var last: Dictionary = _notes.back()
	var last_t: float = last.end if last.end > 0 else last.t
	if now > last_t + 0.8:
		_end()


func _judge_text(txt: String) -> void:
	_judge = txt
	_judge_t = t


func _miss(n: Dictionary) -> void:
	n.state = 2
	n.holding = false
	_miss_streak += 1
	_judge_text("MISS")
	Sfx.play("miss")
	if _miss_streak >= MAX_COMBO_MISS:
		_fell = true
		_end()


func _complete_rep(n: Dictionary, perfect: bool) -> void:
	if n.rep:
		_reps += 1
		_lift_anim = 1.0
	else:
		_lift_anim = max(_lift_anim, 0.35)  # 킵·스윙 동작
	if perfect:
		_perfects += 1


func _press(btn: String) -> void:
	var now := _now()
	var best: Dictionary = {}
	var best_d := 999.0
	for n in _notes:
		if n.state != 0 or n.btn != btn:
			continue
		var dt: float = abs(now - n.t)
		if dt < best_d:
			best_d = dt
			best = n
	if best.is_empty() or best_d > _good_win:
		return
	var perfect := best_d <= _perfect_win
	best.state = 1
	_miss_streak = 0
	_judge_text("PERFECT" if perfect else "GOOD")
	Sfx.play("perfect" if perfect else "good")
	if best.end > 0:
		best.holding = true
		best.perfect = perfect
	else:
		_complete_rep(best, perfect)


func _release(btn: String) -> void:
	var now := _now()
	for n in _notes:
		if n.holding and n.btn == btn:
			n.holding = false
			if now >= n.end - _good_win:
				_complete_rep(n, n.get("perfect", false))
			else:
				_miss(n)


func on_button(btn: String, down: bool) -> void:
	if _finished:
		return
	if btn == "menu":
		if down:
			_fell = true
			_end()
		return
	if down:
		_press(btn)
	else:
		_release(btn)


func _end() -> void:
	if _finished:
		return
	_finished = true
	if on_done.is_valid():
		var cb := on_done
		main.pop()
		cb.call(_reps)
		return
	var best: Dictionary = GameState.data.rhythm_best
	var msgs: Array = []
	msgs.append("%s %d%s! (퍼펙트 %d)" % [Moves.name_of(move_id), _reps, Moves.unit_of(move_id), _perfects])
	if _fell:
		msgs.append("손이 미끄러져 바에서 떨어졌어요.")
	if _reps > int(best.get(move_id, 0)):
		best[move_id] = _reps
		msgs.append("개인 최고 기록!")
	msgs.append_array(GameState.train([{"id": move_id, "reps": _reps}], {"tec": _perfects * 0.3}))
	Sfx.play("success" if not _fell else "fail")
	main.say("\n".join(msgs), func(): main.pop())


func _draw() -> void:
	var scene := Rect2(0, 0, size.x, 170)
	Pal.box_scene(self, scene, t)
	var floor_y := scene.size.y * 0.68
	var look: Dictionary = GameState.data.look
	var info: Dictionary = Moves.LIST[move_id]
	var muscular: Dictionary = GameState.style()
	if info.get("anim", "bar") == "bar":
		# 큰 풀업 바
		var bar_y := 30.0
		draw_rect(Rect2(20, bar_y, 140, 3), Pal.INK)
		draw_rect(Rect2(20, bar_y, 3, floor_y - bar_y), Pal.INK)
		draw_rect(Rect2(157, bar_y, 3, floor_y - bar_y), Pal.INK)
		var o := Vector2(74, bar_y + 13)
		if _fell:
			Pal.athlete(self, Vector2(74, floor_y - 44), look, "tired", 2, t)
		elif info.get("mu", false) and _lift_anim > 0.7:
			Pal.athlete(self, o, look, "support", 2, t, 0.0, muscular)
		else:
			Pal.athlete(self, o, look, "hang", 2, t, _lift_anim, muscular)
		draw_rect(Rect2(20, bar_y, 140, 3), Pal.INK)
	else:
		# 바닥 동작: 올라갈 때 살짝 뛰는 모습
		var pose := "tired" if _fell else ("happy" if _lift_anim > 0.6 else "idle")
		Pal.athlete(self, Vector2(74, floor_y - 44 - _lift_anim * 8.0), look, pose, 2, t, 0.0, muscular)

	# 노트 레인
	var lane := Rect2(0, LANE_Y - 12, size.x, 24)
	draw_rect(lane, Color(Pal.INK, 0.75))
	draw_circle(Vector2(HIT_X, LANE_Y), 10, Pal.WHITE)
	draw_circle(Vector2(HIT_X, LANE_Y), 8, Color(Pal.INK, 0.9))
	var now := _now() if not _finished else 0.0
	for n in _notes:
		if n.state == 2 or (n.state == 1 and not n.holding):
			continue
		var x: float = HIT_X + (n.t - now) * SPEED
		var col := Pal.RED if n.btn == "a" else Pal.BLUE
		if n.end > 0:
			var x2: float = HIT_X + (n.end - now) * SPEED
			var xs: float = max(x, HIT_X) if n.holding else x
			if x2 > 0 and xs < size.x:
				draw_rect(Rect2(xs, LANE_Y - 4, x2 - xs, 8), Pal.YELLOW)
		if x < -10 or x > size.x + 10:
			continue
		if not n.holding:
			draw_circle(Vector2(x, LANE_Y), 7, Pal.WHITE)
			draw_circle(Vector2(x, LANE_Y), 6, col)
			Pal.text_center(self, Rect2(x - 6, LANE_Y - 6, 12, 12), "A" if n.btn == "a" else "B", Pal.WHITE)
	if t - _judge_t < 0.5:
		var jc := Pal.YELLOW if _judge == "PERFECT" else (Pal.GREEN if _judge == "GOOD" else Pal.RED)
		Pal.text(self, Vector2(HIT_X - 12, LANE_Y - 26), _judge, jc)

	# 정보창
	var r := Rect2(2, 172, size.x - 4, size.y - 174)
	Pal.window(self, r)
	Pal.text(self, r.position + Vector2(8, 5), Moves.name_of(move_id), Pal.INK)
	Pal.text(self, r.position + Vector2(8, 19), "%d / %d %s" % [_reps, target_reps, Moves.unit_of(move_id)], Pal.BLUE)
	Pal.text(self, r.position + Vector2(8, 33), "박자에 맞춰 탭, 노란 띠는 꾹!", Pal.DARK)
	Pal.text(self, r.position + Vector2(8, 47), "메뉴: 그만하기", Pal.DARK)
