class_name WodPlay
extends Screen
## WOD 실행 화면. 라운드×동작을 한 화면에서 이어서 진행한다.
## - 동작마다 조작이 다르다 (Moves.input_of): power / rope / cadence / combo / beat
## - 심박: 동작할수록 오르고, 손을 떼면 내려간다. 85 이상이면 판정이 빡빡해지고 100이면 강제 휴식.
## - 라이벌 친구(토리)와 내 지난 기록(고스트)이 위쪽 막대로 같이 달린다.
## - 메뉴 버튼: 그만하기

const RIVAL_NAME := "토리"
const HR_RED := 85.0
const HR_RECOVER := 55.0
const TRANS_TIME := 1.0

var wod: Dictionary
var _queue: Array = []  # [{id, reps, round}]
var _scaled: Array = []
var _done: Array = []  # 실제로 한 횟수 [{id, reps}]
var _total_reps := 0
var _rival_time := 60.0
var _best := 0.0

var _state := "intro"  # intro, play, trans, done
var _clock := 0.0  # GO 이후 경과 시간
var _phase_t := 0.0
var _seg := 0
var _reps := 0.0  # 지금 동작에서 한 횟수 (케이던스는 0.5 단위)
var _inp: Dictionary = {}

var _hr := 20.0
var _locked := false
var _last_input := -10.0
var _anim := 0.0  # 1회 성공 연출 (0~1)
var _pop := ""  # 화면에 튀어나오는 글자
var _pop_t := -10.0
var _coach := ""
var _coach_t := -10.0
var _said := {}
var _rival_ahead := false

# 동작별 상태
var _cursor := 0.0  # power 게이지 (0~1 왕복)
var _cdir := 1.0
var _combo := 0
var _cool := 0.0  # 입력 잠깐 막기 (No Rep 등)
var _rope := 0.0  # 줄 회전 (1.0 = 한 바퀴)
var _rope_hit := false  # 이번 바퀴에 이미 넘었는지
var _last_stroke := -10.0
var _next_btn := "a"
var _cad_mark := 0.0  # 마지막 스트로크 간격 / 목표 간격
var _step := 0  # combo 진행
var _beat_t0 := 0.0
var _beat_n := 0  # 다음에 판정할 노트 번호
var _pat: Array = []  # beat 패턴 (쉬는 박은 "")
var _pat_ok := false  # 이번 패턴을 놓친 노트 없이 치고 있는지
var _first_idx := 0
var _last_idx := 0
var _miss_run := 0
var _rest_msg := ""


func _init(p_wod: Dictionary) -> void:
	super()
	wod = p_wod
	_best = float(wod.get("best", 0.0))
	for r in int(wod.rounds):
		for m in wod.moves:
			var id := Moves.scaled(m.id)
			if id != m.id and not _scaled.has(m.id):
				_scaled.append(m.id)
			_queue.append({"id": id, "reps": int(m.reps), "round": r + 1})
			_total_reps += int(m.reps)
	# 라이벌 목표 시간: 동작별 기준 시간 × 내 실력에 따른 배율
	var sec := 0.0
	for q in _queue:
		sec += Moves.rival_sec_per_rep(q.id) * int(q.reps) + TRANS_TIME
	var avg_lv := GameState.level_sum() / 4.0
	_rival_time = sec * clampf(1.25 - 0.03 * avg_lv, 0.8, 1.25)


func _ready() -> void:
	if _scaled.size() > 0:
		var lines := []
		for s in _scaled:
			lines.append("%s → %s" % [Moves.name_of(s), Moves.name_of(Moves.scaled(s))])
		_say("스케일! " + ", ".join(lines), 3.0)
	else:
		_say("준비~", 2.0)


func _q() -> Dictionary:
	return _queue[_seg]


# ---------- 진행 ----------

func _start_seg() -> void:
	_reps = 0.0
	_inp = Moves.input_of(_q().id)
	_combo = 0
	_step = 0
	_cursor = 0.0
	_cdir = 1.0
	_rope = 0.0
	_rope_hit = false
	_next_btn = "a"
	_last_stroke = _clock
	_cad_mark = 1.0
	_miss_run = 0
	if _inp.type == "beat":
		var rh: Dictionary = Moves.LIST[_q().id].rhythm
		_pat = []
		for ch in String(rh.pat):
			_pat.append("" if ch == "." else ch.to_lower())
		_first_idx = 0
		while _pat[_first_idx] == "":
			_first_idx += 1
		_last_idx = _pat.size() - 1
		while _pat[_last_idx] == "":
			_last_idx -= 1
		_pat_ok = false
		_beat_t0 = _clock + _beat_len()
		_beat_n = 0
	var q := _q()
	if q.round == int(wod.rounds) and _seg > 0 and _queue[_seg - 1].round != q.round:
		_say("마지막 라운드! 힘내!", 1.6)
	else:
		_say("%s %d%s!" % [Moves.name_of(q.id), q.reps, Moves.unit_of(q.id)], 1.4)


func _rep_done(amount: float = 1.0) -> void:
	_reps += amount
	_anim = 1.0
	if absf(_reps - round(_reps)) < 0.01:
		_pop = str(int(round(_reps)))
		_pop_t = t
		Sfx.play("good")
	var left := int(_q().reps) - int(_reps)
	if left == 3 and not _said.has("3left%d" % _seg):
		_said["3left%d" % _seg] = true
		_say("3개 남았어!", 1.0)
	if _reps >= int(_q().reps) - 0.001:
		_done.append({"id": _q().id, "reps": int(_q().reps)})
		_seg += 1
		if _seg >= _queue.size():
			_finish(false)
		else:
			_state = "trans"
			_phase_t = 0.0
			Sfx.play("select")


func _finish(quit: bool) -> void:
	if _state == "done":
		return
	if quit and _seg < _queue.size() and int(_reps) > 0:
		_done.append({"id": _q().id, "reps": int(_reps)})
	_state = "done"
	_phase_t = 0.0
	var total := 0
	for d in _done:
		total += int(d.reps)
	var msgs: Array = []
	msgs.append("%s %s!  %s" % [wod.name, "포기" if quit else "완료", _fmt(_clock)])
	var extra := {"eng": _clock / 40.0}
	if not quit:
		extra.eng += 3.0
		if _clock < _rival_time:
			msgs.append("%s를 이겼어요! (%s)" % [RIVAL_NAME, _fmt(_rival_time)])
			extra["tec"] = 2.0
			extra.eng += 2.0
			GameState.add_gauge("mood", 5)
		else:
			msgs.append("%s가 먼저 끝냈어요... (%s)" % [RIVAL_NAME, _fmt(_rival_time)])
		if _best <= 0.0 or _clock < _best:
			if _best > 0.0:
				msgs.append("NEW PR! %s → %s" % [_fmt(_best), _fmt(_clock)])
				for s in GameState.STATS:
					extra[s] = float(extra.get(s, 0.0)) + 2.0
			wod.best = _clock
		# 체조 단일 기록
		if _queue.size() == 1 and _inp.get("type", "") == "beat":
			var rb: Dictionary = GameState.data.rhythm_best
			if total > int(rb.get(_done[0].id, 0)):
				rb[_done[0].id] = total
	msgs.append_array(GameState.train(_done, extra))
	Sfx.play("fail" if quit else "success")
	_say("헥헥... 끝!" if not quit else "오늘은 여기까지...", 3.0)
	var msg := "\n".join(msgs)
	get_tree().create_timer(1.6).timeout.connect(func(): main.say(msg, func(): main.pop()))


static func _fmt(sec: float) -> String:
	return "%d:%02d" % [int(sec) / 60, int(sec) % 60]


func _say(s: String, dur: float = 1.2) -> void:
	_coach = s
	_coach_t = t + dur


func _process(delta: float) -> void:
	super(delta)
	_phase_t += delta
	_anim = max(0.0, _anim - delta * 4.0)
	_cool = max(0.0, _cool - delta)
	match _state:
		"intro":
			if _phase_t >= 2.4:
				_state = "play"
				_phase_t = 0.0
				Sfx.play("select")
				_start_seg()
			return
		"done":
			return
	_clock += delta
	# 심박: 손을 떼고 있으면 빨리 내려간다
	var idle := _clock - _last_input > 0.6
	var decay := 14.0 if _locked else (8.0 if idle else 2.5)
	_hr = max(15.0, _hr - decay * delta)
	if _locked and _hr <= HR_RECOVER:
		_locked = false
		_say("다시 가자!", 0.8)
	if _hr >= HR_RED and not _locked and not _said.has("red%d" % _seg):
		_said["red%d" % _seg] = true
		_say("숨 쉬어! 페이스 조절!", 1.2)
	# 라이벌 역전 알림
	var mine := _progress()
	var rival := clampf(_clock / _rival_time, 0.0, 1.0)
	if rival > mine + 0.02 and not _rival_ahead:
		_rival_ahead = true
		_say("%s가 앞서가요!" % RIVAL_NAME, 1.0)
	elif mine > rival + 0.02 and _rival_ahead:
		_rival_ahead = false
		_say("역전! 좋아!", 1.0)
	if _state == "trans":
		if _phase_t >= TRANS_TIME:
			_state = "play"
			_phase_t = 0.0
			_start_seg()
		return
	_tick_input(delta)


func _tick_input(delta: float) -> void:
	var tight := 0.6 if _hr >= HR_RED else 1.0
	match _inp.type:
		"power":
			_cursor += _cdir * float(_inp.speed) * delta
			if _cursor > 1.0:
				_cursor = 1.0
				_cdir = -1.0
			elif _cursor < 0.0:
				_cursor = 0.0
				_cdir = 1.0
		"rope":
			if _locked or _cool > 0.0:
				return
			var before := fmod(_rope, 1.0)
			_rope += float(_inp.speed) * delta
			if fmod(_rope, 1.0) < before:
				_rope_hit = false  # 새 바퀴
		"beat":
			var bl := _beat_len()
			var win := 0.16 * tight + 0.004 * GameState.level("gym")
			# 판정 시간이 지난 노트는 놓친 것
			while _clock > _beat_t0 + _beat_n * bl + win:
				var btn: String = _pat[_beat_n % _pat.size()]
				if btn != "" and not _locked:
					_beat_miss()
				_beat_n += 1


func _beat_len() -> float:
	return 60.0 / float(Moves.LIST[_q().id].rhythm.bpm)


func _beat_miss() -> void:
	_pat_ok = false
	_miss_run += 1
	_combo = 0
	_add_hr(1.0)
	if _miss_run >= 3:
		_miss_run = 0
		_cool = 1.2
		_say("앗, 바에서 미끄러졌어!", 1.0)
		Sfx.play("miss")


func _progress() -> float:
	var done := 0.0
	for i in mini(_seg, _queue.size()):
		done += int(_queue[i].reps)
	if _seg < _queue.size() and _state != "done":
		done += _reps
	return clampf(done / max(1.0, float(_total_reps)), 0.0, 1.0)


func _add_hr(v: float) -> void:
	var eng := float(GameState.level("eng") - 1)
	_hr += v * clampf(1.0 - 0.06 * eng, 0.5, 1.0)
	if _hr >= 100.0:
		_hr = 100.0
		_locked = true
		_combo = 0
		_say("헥헥... 숨 고르는 중", 1.5)
		Sfx.play("miss")


# ---------- 입력 ----------

func on_button(btn: String, down: bool) -> void:
	if not down:
		return
	if btn == "menu":
		if _state == "play" or _state == "trans":
			_finish(true)
		return
	if _state != "play" or _locked or _cool > 0.0:
		return
	_last_input = _clock
	var tight := 0.6 if _hr >= HR_RED else 1.0
	match _inp.type:
		"power":
			if btn != "a":
				return
			var w := 0.3 * (1.0 + 0.03 * GameState.level("tec")) * tight
			var d := absf(_cursor - 0.5)
			if d <= w * 0.2:
				_combo += 1
				_pop_word("PERFECT" if _combo < 3 else "콤보 %d!" % _combo)
				_add_hr(4.0 * (1.0 - mini(_combo, 5) * 0.1))
				Sfx.play("perfect")
				_rep_done()
			elif d <= w * 0.5:
				_combo = 0
				_add_hr(4.0)
				_rep_done()
			else:
				_combo = 0
				_pop_word("No Rep!")
				_add_hr(2.0)
				_cool = 0.35
				Sfx.play("miss")
		"rope":
			if btn != "a":
				return
			var ph := fmod(_rope, 1.0)
			var win := (0.12 if _q().id == "su" else 0.09) * tight
			if absf(ph - 0.5) <= win and not _rope_hit:
				_rope_hit = true
				_add_hr(1.2)
				Sfx.play("tap")
				_rep_done()
			else:
				_pop_word("줄 걸림!")
				_add_hr(1.5)
				_cool = 0.8
				_rope = 0.0
				Sfx.play("miss")
		"cadence":
			if btn != _next_btn:
				_pop_word("박자!")
				_add_hr(1.0)
				return
			var target := float(_inp.interval)
			var dt := _clock - _last_stroke
			_last_stroke = _clock
			_next_btn = "b" if _next_btn == "a" else "a"
			_cad_mark = dt / target
			if dt < target * 0.65:
				_pop_word("너무 빨라!")
				_add_hr(3.0)
				return
			_add_hr(1.4 if dt < target * 1.4 else 0.6)
			Sfx.play("tap")
			_rep_done(0.5 if dt < target * 1.4 else 0.25)
		"combo":
			var seq: Array = _inp.seq
			if btn == seq[_step]:
				_step += 1
				_add_hr(1.6)
				_anim = 0.6
				Sfx.play("tap")
				if _step >= seq.size():
					_step = 0
					_rep_done()
			else:
				_step = 0
				_pop_word("삐끗!")
				_add_hr(1.0)
				_cool = 0.25
				Sfx.play("miss")
		"beat":
			var bl := _beat_len()
			var win := 0.16 * tight + 0.004 * GameState.level("gym")
			var nt := _beat_t0 + _beat_n * bl
			var want: String = _pat[_beat_n % _pat.size()]
			if want == "" or absf(_clock - nt) > win or btn != want:
				_pop_word("MISS")
				_beat_miss()
				Sfx.play("miss")
				return
			var perfect := absf(_clock - nt) <= win * 0.4
			_pop_word("PERFECT" if perfect else "GOOD")
			Sfx.play("perfect" if perfect else "good")
			_add_hr(2.0)
			_miss_run = 0
			var idx := _beat_n % _pat.size()
			_beat_n += 1
			if idx == _first_idx:
				_pat_ok = true
			var each: bool = Moves.LIST[_q().id].rhythm.get("each", false)
			# each면 노트마다 1회, 아니면 패턴을 빠짐없이 끝까지 쳐야 1회
			if each or (idx == _last_idx and _pat_ok):
				_rep_done()


func on_tap(_pos: Vector2) -> void:
	on_button("a", true)


func _pop_word(s: String) -> void:
	_pop = s
	_pop_t = t


# ---------- 그리기 ----------

func _draw() -> void:
	var scene := Rect2(0, 44, size.x, 128)
	Pal.box_scene(self, scene, t)
	_draw_top()
	var floor_y := scene.position.y + scene.size.y * 0.68
	_draw_character(floor_y)
	if _state == "play":
		_draw_input(floor_y)
	if t - _pop_t < 0.6 and _pop != "":
		var y := floor_y - 70 - (t - _pop_t) * 20.0
		var col := Pal.RED if _pop in ["No Rep!", "MISS", "줄 걸림!", "삐끗!", "너무 빨라!", "박자!"] else Pal.BLUE
		Pal.text_center(self, Rect2(0, y, size.x, 12), _pop, col)
	_draw_info()


func _draw_top() -> void:
	draw_rect(Rect2(0, 0, size.x, 44), Pal.WHITE)
	draw_rect(Rect2(0, 43, size.x, 1), Pal.INK)
	Pal.text(self, Vector2(4, 2), _fmt(_clock), Pal.INK)
	var rnd := "R%d/%d" % [int(_q().round) if _seg < _queue.size() else int(wod.rounds), int(wod.rounds)]
	Pal.text(self, Vector2(40, 2), rnd, Pal.DARK)
	# 심박
	Pal.icon(self, Vector2(84, 4), "heart")
	var hcol := Pal.RED if _hr >= HR_RED else (Pal.YELLOW if _hr >= 60.0 else Pal.GREEN)
	if _locked and int(t * 6) % 2 == 0:
		hcol = Pal.INK
	Pal.bar(self, Rect2(93, 4, 60, 7), _hr / 100.0, hcol)
	draw_rect(Rect2(93 + 60 * HR_RED / 100.0, 3, 1, 9), Pal.INK)
	Pal.text(self, Vector2(156, 2), "%d" % int(_hr), hcol if not _locked else Pal.RED)
	# 레이스 막대: 나 / 토리 (+ 내 기록 고스트)
	var lane := Rect2(32, 16, 140, 6)
	Pal.text(self, Vector2(4, 13), "나", Pal.BLUE)
	Pal.bar(self, lane, _progress(), Pal.BLUE)
	Pal.text(self, Vector2(4, 27), RIVAL_NAME, Pal.RED)
	Pal.bar(self, Rect2(32, 30, 140, 6), clampf(_clock / _rival_time, 0.0, 1.0), Pal.PINK)
	if _best > 0.0:
		var gx := lane.position.x + lane.size.x * clampf(_clock / _best, 0.0, 1.0)
		draw_rect(Rect2(gx - 1, lane.position.y - 2, 2, lane.size.y + 4), Pal.YELLOW.darkened(0.2))


func _draw_character(floor_y: float) -> void:
	var look: Dictionary = GameState.data.look
	var st := GameState.style()
	var o := Vector2(74, floor_y - 44)
	if _state == "done":
		Pal.athlete(self, Vector2(74, floor_y - 44), look, "sleep", 1, t, 0.0, st)
		return
	if _locked:
		Pal.athlete(self, o, look, "tired", 1, t, 0.0, st)
		Pal.bubble(self, o + Vector2(28, -10), "sweat")
		return
	if _state != "play":
		Pal.athlete(self, o, look, "idle", 1, t, 0.0, st)
		return
	var id: String = _q().id
	var cat: String = Moves.LIST[id].cat
	match _inp.type:
		"power":
			var p := 1.0 - _anim if _anim > 0.0 else 0.15
			if cat == "barbell" and id in ["backsquat", "frontsquat", "thruster", "lunge"]:
				Pal.athlete(self, o, look, "squat", 1, t, p, st)
				Pal.barbell(self, Vector2(90, o.y + Chibi.shoulder_y(p)), 28, 2)
			elif id in ["ohs", "squatsnatch", "powersnatch", "press", "pushpress", "pushjerk", "splitjerk", "cleanjerk"] and _anim > 0.0:
				Pal.athlete(self, o, look, "ohs", 1, t, 1.0, st)
				Pal.barbell(self, Vector2(90, o.y + Chibi.overhead_y(1.0)), 28, 2)
			else:
				Pal.athlete(self, o, look, "lift", 1, t, p, st)
				var hand := Vector2(90, o.y + Chibi.lift_hand_y(p))
				if cat == "barbell":
					Pal.barbell(self, hand, 28, 2)
				else:
					draw_rect(Rect2(hand - Vector2(5, 0), Vector2(10, 9)), Pal.INK)
					draw_rect(Rect2(hand - Vector2(4, -1), Vector2(8, 7)), Pal.PINK)
		"rope":
			var ph := fmod(_rope, 1.0)
			var jump := 6.0 if absf(ph - 0.5) < 0.18 and _rope_hit else 0.0
			# 줄: 몸 뒤(위쪽 반)와 앞(아래쪽 반)
			var c := Vector2(90, o.y + 26)
			var ang := ph * TAU
			_draw_rope(c, ang, ph > 0.25 and ph < 0.75)
			Pal.athlete(self, o - Vector2(0, jump), look, "idle" if jump == 0.0 else "happy", 1, t, 0.0, st)
			_draw_rope(c, ang, not (ph > 0.25 and ph < 0.75))
		"cadence":
			var bob := 3.0 * sin(_clock * PI / float(_inp.interval))
			Pal.athlete(self, o + Vector2(0, bob if _clock - _last_input < 0.6 else 0.0), look, "lift" if id in ["row", "ski", "sled", "farmer"] else "idle", 1, t, 0.6 + bob * 0.1, st)
		"combo":
			var seq_len: int = _inp.seq.size()
			var pose := "idle"
			var dy := 0.0
			if _step > 0:
				pose = "squat" if _step % 2 == 1 else "happy"
				dy = -6.0 if pose == "happy" else 0.0
			if _anim > 0.6 and _step == 0 and seq_len > 0:
				pose = "happy"
				dy = -8.0 * _anim
			Pal.athlete(self, o + Vector2(0, dy), look, pose, 1, t, 0.0, st)
		"beat":
			if Moves.LIST[id].get("anim", "bar") == "bar":
				var bar_y := floor_y - 72
				draw_rect(Rect2(40, bar_y, 100, 2), Pal.INK)
				Pal.athlete(self, Vector2(74, bar_y - Chibi.HANG_HAND_Y + 1), look, "hang", 1, t, _anim, st)
				draw_rect(Rect2(40, bar_y, 100, 2), Pal.INK)
			else:
				Pal.athlete(self, o - Vector2(0, _anim * 6.0), look, "happy" if _anim > 0.5 else "idle", 1, t, 0.0, st)


func _draw_rope(c: Vector2, ang: float, front: bool) -> void:
	# 줄을 몸 둘레의 타원으로 그리고, 앞쪽 절반/뒤쪽 절반을 나눠 그린다
	var col := Pal.RED if front else Color(Pal.RED, 0.45)
	var y := c.y - cos(ang) * 30.0
	draw_rect(Rect2(c.x - 22, y, 44, 2), col)
	draw_rect(Rect2(c.x - 24, min(y, c.y), 2, absf(y - c.y)), col)
	draw_rect(Rect2(c.x + 22, min(y, c.y), 2, absf(y - c.y)), col)


func _draw_input(floor_y: float) -> void:
	var r := Rect2(8, floor_y + 12, size.x - 16, 16)
	var tight := 0.6 if _hr >= HR_RED else 1.0
	match _inp.type:
		"power":
			var w := 0.3 * (1.0 + 0.03 * GameState.level("tec")) * tight
			Pal.round_rect(self, r, Pal.INK)
			draw_rect(r.grow(-1), Pal.WHITE)
			var iw := r.size.x - 2
			draw_rect(Rect2(r.position.x + 1 + iw * (0.5 - w * 0.5), r.position.y + 1, iw * w, r.size.y - 2), Color(Pal.GREEN, 0.55))
			draw_rect(Rect2(r.position.x + 1 + iw * (0.5 - w * 0.1), r.position.y + 1, iw * w * 0.2, r.size.y - 2), Pal.YELLOW)
			draw_rect(Rect2(r.position.x + iw * _cursor, r.position.y - 3, 3, r.size.y + 6), Pal.RED)
		"rope":
			var ph := fmod(_rope, 1.0)
			Pal.round_rect(self, r, Pal.INK)
			draw_rect(r.grow(-1), Pal.WHITE)
			var iw := r.size.x - 2
			var win := (0.12 if _q().id == "su" else 0.09) * tight
			draw_rect(Rect2(r.position.x + 1 + iw * (0.5 - win), r.position.y + 1, iw * win * 2.0, r.size.y - 2), Color(Pal.GREEN, 0.55))
			draw_rect(Rect2(r.position.x + iw * ph, r.position.y - 3, 3, r.size.y + 6), Pal.RED)
		"cadence":
			Pal.round_rect(self, r, Pal.INK)
			draw_rect(r.grow(-1), Pal.WHITE)
			var iw := r.size.x - 2
			# 목표 간격(1.0)을 가운데에 두고, 0.65~1.4가 좋은 구간
			var zx := func(v: float) -> float: return r.position.x + 1 + iw * clampf(v / 2.0, 0.0, 1.0)
			draw_rect(Rect2(zx.call(0.65), r.position.y + 1, zx.call(1.4) - zx.call(0.65), r.size.y - 2), Color(Pal.GREEN, 0.55))
			draw_rect(Rect2(zx.call(1.0) - 1, r.position.y + 1, 2, r.size.y - 2), Pal.YELLOW)
			draw_rect(Rect2(zx.call(_cad_mark) - 1, r.position.y - 3, 3, r.size.y + 6), Pal.RED)
			_btn_icon(Vector2(r.end.x - 14, r.position.y - 20), _next_btn, true)
		"combo":
			var seq: Array = _inp.seq
			var x0 := size.x * 0.5 - seq.size() * 9.0
			for i in seq.size():
				_btn_icon(Vector2(x0 + i * 18, r.position.y), seq[i], i == _step)
				if i < _step:
					Pal.icon(self, Vector2(x0 + i * 18 + 3, r.position.y - 9), "cond")
		"beat":
			# 작은 리듬 레인: 노트가 오른쪽에서 판정선으로
			Pal.round_rect(self, r, Pal.INK)
			draw_rect(r.grow(-1), Color(Pal.INK, 0.85))
			var hx := r.position.x + 14
			draw_circle(Vector2(hx, r.get_center().y), 6, Pal.WHITE)
			draw_circle(Vector2(hx, r.get_center().y), 5, Pal.INK)
			var bl := _beat_len()
			for k in 6:
				var n := _beat_n + k
				var btn: String = _pat[n % _pat.size()]
				if btn == "":
					continue
				var x := hx + (_beat_t0 + n * bl - _clock) * 60.0
				if x > r.end.x - 4:
					break
				draw_circle(Vector2(x, r.get_center().y), 5, Pal.RED if btn == "a" else Pal.BLUE)


func _btn_icon(p: Vector2, btn: String, active: bool) -> void:
	var c := p + Vector2(7, 7)
	draw_circle(c, 8, Pal.INK)
	draw_circle(c, 7, (Pal.RED if btn == "a" else Pal.BLUE) if active else Pal.MID)
	Pal.text_center(self, Rect2(c.x - 7, c.y - 6, 14, 12), btn.to_upper(), Pal.WHITE)


func _draw_info() -> void:
	var r := Rect2(2, 174, size.x - 4, size.y - 176)
	Pal.window(self, r)
	match _state:
		"intro":
			var n := 3 - int(_phase_t / 0.8)
			Pal.text(self, r.position + Vector2(8, 5), wod.name, Pal.INK)
			Pal.text(self, r.position + Vector2(8, 19), "%d..." % maxi(n, 1) if n > 0 else "GO!", Pal.RED)
		"done":
			Pal.text(self, r.position + Vector2(8, 5), "기록 %s" % _fmt(_clock), Pal.INK)
		_:
			if _seg < _queue.size():
				var q := _q()
				var label := "%s  %d/%d" % [Moves.name_of(q.id), int(_reps), int(q.reps)]
				if _state == "trans":
					label = "다음: %s %d%s" % [Moves.name_of(q.id), q.reps, Moves.unit_of(q.id)]
				Pal.text(self, r.position + Vector2(8, 5), label, Pal.INK)
			Pal.text(self, r.position + Vector2(8, 34), _hint(), Pal.DARK)
	if t < _coach_t:
		Pal.text(self, r.position + Vector2(8, 19), "코치: " + _coach, Pal.BLUE)


func _hint() -> String:
	if _locked:
		return "손 떼고 숨 고르기..."
	match _inp.get("type", ""):
		"power":
			return "초록에서 A! 손 떼면 심박↓"
		"rope":
			return "줄이 발밑에 올 때 A!"
		"cadence":
			return "A·B 일정한 박자로!"
		"combo":
			return "버튼 순서대로!"
		"beat":
			return "박자에 맞춰 A·B!"
	return ""
