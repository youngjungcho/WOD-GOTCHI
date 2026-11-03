extends Node
## 캐릭터 데이터, 실시간 경과, 방치 페널티, 성장 단계를 관리하는 autoload.

signal changed
signal toast(message: String)

const SAVE_PATH := "user://save.json"

const STAGE_NAMES := ["등록생", "스케일드", "RX", "컴피티터", "게임즈 선수"]
# 단계별: 게이지 감소 배율, 오프라인 바닥값, 하루당 디트레이닝 비율
const STAGE_DECAY := [0.5, 0.7, 1.0, 1.2, 1.4]
const STAGE_FLOOR := [35.0, 25.0, 10.0, 0.0, 0.0]
const STAGE_DETRAIN := [0.0, 0.0, 0.0, 0.03, 0.05]
# 다음 단계로 가기 위한 조건: [능력치 레벨 합계, 실제로 운동한 날 수]
const STAGE_REQ := [[12, 2], [20, 5], [32, 12], [48, 25]]

# 시간당 기본 변화량
const DECAY_PER_HOUR := {"food": 6.0, "energy": 4.0, "mood": 3.0, "cond": 2.0}

const STATS := ["str", "gym", "eng", "tec"]
const STAT_NAMES := {"str": "근력", "gym": "체조", "eng": "엔진", "tec": "기술"}
const GAUGE_NAMES := {"food": "영양", "energy": "에너지", "mood": "의욕", "cond": "컨디션"}

const LIFTS := {"deadlift": "데드리프트", "squat": "백스쿼트", "clean": "클린", "snatch": "스내치"}
const LIFT_REQ := {"deadlift": {}, "squat": {}, "clean": {"tec": 2}, "snatch": {"tec": 3}}
const ATTEMPTS_PER_DAY := 3

var data: Dictionary = {}
var _accum := 0.0
var _autosave := 0.0


func _ready() -> void:
	load_game()


func _process(delta: float) -> void:
	if not is_created():
		return
	_accum += delta
	if _accum >= 1.0:
		_advance(_accum / 3600.0, false)
		data.last_tick = now()
		_accum = 0.0
		_check_calls()
		changed.emit()
	# 웹/모바일은 탭을 닫거나 앱이 종료될 때 저장 기회가 없을 수 있어 주기적으로 저장한다
	_autosave += delta
	if _autosave >= 20.0:
		_autosave = 0.0
		save_game()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		save_game()
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		catch_up()


static func now() -> float:
	return Time.get_unix_time_from_system()


static func today() -> String:
	return Time.get_date_string_from_system()


# ---------- 생성 / 저장 ----------

func new_character(name: String, look: Dictionary) -> void:
	var t := now()
	data = {
		"version": 1,
		"name": name,
		"look": look,
		"born": t,
		"last_tick": t,
		"gauges": {"food": 80.0, "energy": 90.0, "mood": 80.0, "cond": 90.0},
		"xp": {"str": 0.0, "gym": 0.0, "eng": 0.0, "tec": 0.0},
		"stage": 0,
		"sleeping": false,
		"mess": 0,
		"injured_until": 0.0,
		"praise_at": 0.0,
		"pr": {"deadlift": 0.0, "squat": 0.0, "clean": 0.0, "snatch": 0.0},
		"rhythm_best": {},
		"move_log": {},
		"form": "rookie",
		"mental": 30.0,
		"hist": _empty_hist(),
		"call": {},
		"next_fake_call": t + randf_range(20.0, 40.0) * 60.0,
		"skip_until": 0.0,
		"pending_evo": {},
		"attempt_day": "",
		"attempts_used": {},
		"real": {"checkin_day": "", "prs": {"deadlift": 0, "squat": 0, "clean": 0, "snatch": 0, "pullup": 0}},
		"wods": [
			{"name": "첫 WOD", "rounds": 3, "moves": [{"id": "pullup", "reps": 5}, {"id": "deadlift", "reps": 5}, {"id": "burpee", "reps": 5}]},
		],
	}
	Forms.register("rookie", name)
	save_game()
	changed.emit()


static func _empty_hist() -> Dictionary:
	return {"cheat": 0, "healthy": 0, "injuries": 0, "ignored": 0, "answered": 0, "scold_ok": 0, "scold_bad": 0, "giveins": 0}


func is_created() -> bool:
	return data.has("name")


func save_game() -> void:
	if not is_created():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		data = parsed
		_migrate()
		catch_up()


func reset_game() -> void:
	data = {}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	changed.emit()


## 앱이 꺼져 있던 동안의 시간을 한 번에 반영한다.
func catch_up() -> void:
	if not is_created():
		return
	var hours: float = max(0.0, (now() - float(data.last_tick)) / 3600.0)
	if hours > 0.01:
		_advance(hours, true)
		if hours >= 1.0:
			toast.emit("%s 동안 자리를 비웠어요." % _fmt_hours(hours))
	data.last_tick = now()
	_check_calls()
	save_game()
	changed.emit()


func _advance(hours: float, offline: bool) -> void:
	var st: int = data.stage
	var mult: float = STAGE_DECAY[st]
	var g: Dictionary = data.gauges
	var before := g.duplicate()
	if data.sleeping:
		g.food -= DECAY_PER_HOUR.food * 0.5 * mult * hours
		g.energy += 14.0 * hours
		g.cond += 6.0 * hours
		g.mood -= DECAY_PER_HOUR.mood * 0.3 * mult * hours
	else:
		g.food -= DECAY_PER_HOUR.food * mult * hours
		g.energy -= DECAY_PER_HOUR.energy * mult * hours
		g.mood -= DECAY_PER_HOUR.mood * mult * hours
		var cond_mult := 2.0 if int(data.mess) >= 2 else 1.0
		g.cond -= DECAY_PER_HOUR.cond * mult * cond_mult * hours
	# 배고프면 의욕도 빨리 떨어진다
	if g.food < 20.0:
		g.mood -= 3.0 * hours
	for k in g.keys():
		var v: float = g[k]
		if offline and v < before[k]:
			# 초반에는 하루 정도 비워도 바닥값 아래로 떨어지지 않는다
			v = max(v, min(before[k], STAGE_FLOOR[st]))
		g[k] = clampf(v, 0.0, 100.0)
	if offline and hours > 24.0 and STAGE_DETRAIN[st] > 0.0:
		var days := (hours - 24.0) / 24.0
		var loss: float = min(0.25, STAGE_DETRAIN[st] * days)
		for s in STATS:
			data.xp[s] = float(data.xp[s]) * (1.0 - loss)
		toast.emit("오래 쉬어서 실력이 %d%% 줄었어요..." % int(loss * 100))


static func _fmt_hours(h: float) -> String:
	if h >= 24.0:
		return "%d일 %d시간" % [int(h / 24.0), int(h) % 24]
	if h >= 1.0:
		return "%d시간" % int(h)
	return "%d분" % int(h * 60.0)


# ---------- 조회 ----------

func gauge(k: String) -> float:
	return float(data.gauges[k])


func add_gauge(k: String, v: float) -> void:
	data.gauges[k] = clampf(float(data.gauges[k]) + v, 0.0, 100.0)


# 레벨 곡선: Lv까지 필요한 누적 XP = A*(Lv-1)^2 + B*(Lv-1)
# 초반(Lv2=25)은 무겁게, 후반(Lv12=1265)은 완만하게.
const CURVE_A := 9.0
const CURVE_B := 16.0


static func level_for_xp(xp: float) -> int:
	var n := (-CURVE_B + sqrt(CURVE_B * CURVE_B + 4.0 * CURVE_A * max(xp, 0.0))) / (2.0 * CURVE_A)
	return int(floor(n + 0.000001)) + 1


static func xp_for_level(lv: int) -> float:
	var n := float(lv - 1)
	return CURVE_A * n * n + CURVE_B * n


func level(stat: String) -> int:
	return level_for_xp(float(data.xp[stat]))


func level_sum() -> int:
	var s := 0
	for k in STATS:
		s += level(k)
	return s


func days_alive() -> int:
	return int((now() - float(data.born)) / 86400.0)


## 운동한 날 수 (같은 날 여러 번 해도 하루).
func workout_days() -> int:
	return (data.get("workout_days", {}) as Dictionary).size()


func stage() -> int:
	return int(data.stage)


func title() -> String:
	var form: String = data.get("form", "rookie")
	if stage() < 2:
		return Forms.name_of(form)
	return "%s %s" % [Forms.STAGE_PREFIX[stage()], Forms.name_of(form)]


func style() -> Dictionary:
	return Forms.style_of(data.get("form", "rookie"))


func mental() -> float:
	return float(data.get("mental", 30.0))


func add_mental(v: float) -> void:
	data.mental = clampf(mental() + v, 0.0, 100.0)


func is_injured() -> bool:
	return now() < float(data.injured_until)


func injury_left_text() -> String:
	return _fmt_hours((float(data.injured_until) - now()) / 3600.0)


## 운동 전 체크. 운동할 수 없으면 사유 문자열을 돌려준다.
func workout_block_reason() -> String:
	if data.sleeping:
		return "자는 중이에요. 먼저 깨워주세요."
	if is_injured():
		return "부상 회복 중... (%s 남음)" % injury_left_text()
	if now() < float(data.get("skip_until", 0.0)):
		return "오늘은 쉬기로 했잖아요~ (땡땡이 중)"
	if gauge("energy") < 15.0:
		return "너무 피곤해서 못하겠어요..."
	if gauge("mood") < 15.0:
		return "오늘은 운동하기 싫대요. 칭찬해 주세요."
	return ""


## 1RM 역량(kg). 근력·기술 레벨과 당일 컨디션으로 정해진다.
## 1RM 역량(kg). 근력·기술 레벨과 당일 컨디션으로 정해진다.
## 클린·스내치는 기술 비중이 크고 기본 무게가 낮다.
func lift_capacity(lift: String = "deadlift") -> float:
	var st := float(level("str") - 1)
	var tc := float(level("tec") - 1)
	var base := 40.0 + st * 8.0 + tc * 2.0
	match lift:
		"squat":
			base *= 0.85
		"clean":
			base = (40.0 + st * 6.0 + tc * 5.0) * 0.7
		"snatch":
			base = (40.0 + st * 5.0 + tc * 6.0) * 0.55
	var cond := 0.8 + 0.2 * (gauge("energy") + gauge("cond")) / 200.0
	cond *= 0.95 + 0.1 * gauge("mood") / 100.0
	cond *= 0.96 + 0.08 * mental() / 100.0
	return base * cond


func lift_unlocked(lift: String) -> bool:
	var req: Dictionary = LIFT_REQ[lift]
	for s in req:
		if level(s) < int(req[s]):
			return false
	return true


func lift_req_text(lift: String) -> String:
	var parts := []
	for s in LIFT_REQ[lift]:
		parts.append("%s Lv.%d" % [STAT_NAMES[s], LIFT_REQ[lift][s]])
	return "해금: " + ", ".join(parts)


func pr(lift: String) -> float:
	return float(data.pr.get(lift, 0.0))


## 종목별 오늘 남은 시기. lift를 비우면 해금된 종목 전체 합.
func attempts_left(lift: String = "") -> int:
	if data.get("attempt_day", "") != today():
		data.attempt_day = today()
		data.attempts_used = {}
	if lift == "":
		var total := 0
		for l in LIFTS:
			if lift_unlocked(l):
				total += attempts_left(l)
		return total
	return ATTEMPTS_PER_DAY - int(data.attempts_used.get(lift, 0))


func attempts_max() -> int:
	var n := 0
	for l in LIFTS:
		if lift_unlocked(l):
			n += ATTEMPTS_PER_DAY
	return n


func use_attempt(lift: String) -> void:
	attempts_left()
	data.attempts_used[lift] = int(data.attempts_used.get(lift, 0)) + 1


func _migrate() -> void:
	# 예전 리듬게임 기록 키(strict)를 동작 id로 옮긴다
	var rb: Dictionary = data.get("rhythm_best", {})
	if rb.has("strict"):
		rb["pullup"] = max(int(rb.get("pullup", 0)), int(rb.strict))
		rb.erase("strict")
	data.rhythm_best = rb
	if not data.has("move_log"):
		data.move_log = {}
	for l in LIFTS:
		if not data.pr.has(l):
			data.pr[l] = 0.0
	if not data.has("workout_days"):
		data.workout_days = {}
		if not (data.get("move_log", {}) as Dictionary).is_empty():
			data.workout_days[today()] = true
	if not data.has("attempts_used"):
		data.attempts_used = {}
	if not data.has("hist"):
		data.hist = _empty_hist()
	for k in ["mental", "call", "next_fake_call", "skip_until", "pending_evo"]:
		if not data.has(k):
			data[k] = {"mental": 30.0, "call": {}, "next_fake_call": now() + 1800.0, "skip_until": 0.0, "pending_evo": {}}[k]
	if not data.has("form"):
		data.form = Forms.decide(stage())
		Forms.register(data.form, data.name)


# ---------- 운동 다양성 ----------

const VARIETY_WINDOW := 72.0 * 3600.0  # 최근 3일
const PICK_BONUS := 1.5
const CAT_BONUS := [1.0, 1.0, 1.1, 1.2, 1.3]  # WOD에 섞인 카테고리 수별 보너스
const XP_SCALE := 0.5  # 동작 XP 전체 배율 (성장 속도 조절용)


## 최근 3일 동안 이 동작을 한 세션 수.
func recent_count(id: String) -> int:
	var times: Array = data.move_log.get(id, [])
	var n := 0
	for tm in times:
		if now() - float(tm) < VARIETY_WINDOW:
			n += 1
	return n


## 같은 동작만 반복하면 효과가 줄고, 오래 안 한 동작은 보너스.
func variety_mult(id: String) -> float:
	var m: float = [1.3, 1.1, 1.0, 0.85, 0.7][mini(recent_count(id), 4)]
	if recent_count(id) >= 5:
		m = 0.6
	if daily_picks().has(id):
		m *= PICK_BONUS
	return m


func variety_label(id: String) -> String:
	var parts := []
	if daily_picks().has(id):
		parts.append("오늘의 추천!")
	var n := recent_count(id)
	if n == 0:
		parts.append("새로움 보너스")
	elif n >= 3:
		parts.append("반복 피로(최근 %d번)" % n)
	parts.append("x%s" % Pal.num(snappedf(variety_mult(id), 0.01)))
	return " ".join(parts)


## 날짜마다 바뀌는 오늘의 추천 동작 3개 (해금된 것 중, 서로 다른 카테고리에서).
func daily_picks() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today() + str(data.get("born", 0)))
	var cats: Array = Moves.CATS.keys()
	# 카테고리 순서를 날짜별로 섞는다
	for i in range(cats.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = cats[i]
		cats[i] = cats[j]
		cats[j] = tmp
	var picks := []
	for cat in cats:
		if picks.size() >= 3:
			break
		var pool := []
		for id in Moves.ids_in(cat):
			if Moves.unlocked(id):
				pool.append(id)
		if pool.size() > 0:
			picks.append(pool[rng.randi() % pool.size()])
	return picks


## 운동 결과를 반영한다. moves: [{id, reps}], 동작별 XP 분배 × 다양성 보너스 × 카테고리 보너스.
## extra_xp: 시간/퍼펙트 등 추가 XP. 결과 메시지 목록을 돌려준다.
func train(moves: Array, extra_xp: Dictionary = {}) -> Array:
	var xp := {}
	var energy := 0.0
	var cats := {}
	var ids_done := {}
	for m in moves:
		var reps := int(m.reps)
		if reps <= 0:
			continue
		var id: String = m.id
		var mult := variety_mult(id)
		var per := Moves.xp_per_rep(id)
		for s in per:
			xp[s] = float(xp.get(s, 0.0)) + per[s] * reps * mult * XP_SCALE
		energy += Moves.energy_per_rep(id) * reps
		cats[Moves.LIST[id].cat] = true
		ids_done[id] = true
	var msgs: Array = []
	var cat_mult: float = CAT_BONUS[mini(cats.size(), 4)]
	if cat_mult > 1.0:
		msgs.append("%d가지 영역을 골고루! 보너스 x%s" % [cats.size(), Pal.num(cat_mult)])
	for s in xp:
		xp[s] = float(xp[s]) * cat_mult
	for s in extra_xp:
		xp[s] = float(xp.get(s, 0.0)) + float(extra_xp[s])
	var picks := daily_picks()
	for id in ids_done:
		if picks.has(id):
			msgs.append("오늘의 추천 동작 '%s' 보너스!" % Moves.name_of(id))
		var mlog: Array = data.move_log.get(id, [])
		mlog.append(now())
		while mlog.size() > 8:
			mlog.pop_front()
		data.move_log[id] = mlog
	var gained := []
	for s in STATS:
		if float(xp.get(s, 0.0)) >= 0.5:
			gained.append("%s+%d" % [STAT_NAMES[s], int(round(xp[s]))])
	if gained.size() > 0:
		msgs.append(" ".join(gained))
	msgs.append_array(apply_workout(xp, clampf(energy, 3.0, 45.0), clampf(energy * 0.35, 1.0, 20.0)))
	return msgs


# ---------- 행동 ----------

## 운동 결과 반영. xp는 {stat: amount}. 결과 메시지 목록을 돌려준다.
const SESSIONS_FULL := 3  # 하루에 이 횟수까지는 경험치 100%, 이후는 절반


## 오늘 한 운동 세션 수.
func sessions_today() -> int:
	if data.get("session_day", "") != today():
		return 0
	return int(data.get("sessions", 0))


## 운동 결과 반영. counts_session=false면 하루 운동 횟수에 넣지 않는다(1RM 시기).
func apply_workout(xp: Dictionary, energy_cost: float, cond_cost: float, counts_session: bool = true) -> Array:
	var msgs: Array = []
	var food_mult := 0.5 if gauge("food") < 20.0 else 1.0
	if food_mult < 1.0:
		msgs.append("배가 고파서 효과가 절반이에요.")
	if counts_session:
		var n := sessions_today() + 1
		data.session_day = today()
		data.sessions = n
		if n > SESSIONS_FULL:
			food_mult *= 0.5
			msgs.append("오늘은 충분히 했어요! 내일 또 와요~ (%d번째, 경험치 절반)" % n)
	var low_cond := gauge("cond") < 25.0
	for s in xp.keys():
		var before := level(s)
		data.xp[s] = float(data.xp[s]) + float(xp[s]) * food_mult
		if level(s) > before:
			msgs.append("%s 레벨 업! Lv.%d" % [STAT_NAMES[s], level(s)])
	add_gauge("energy", -energy_cost)
	add_gauge("cond", -cond_cost)
	add_gauge("food", -energy_cost * 0.3)
	data.mess = min(3, int(data.mess) + 1)
	if not data.has("workout_days"):
		data.workout_days = {}
	data.workout_days[today()] = true
	if low_cond and randf() < 0.3:
		var hours := 2.0 if stage() < 2 else 6.0
		data.injured_until = now() + hours * 3600.0
		data.hist.injuries = int(data.hist.injuries) + 1
		msgs.append("앗! 무리해서 다쳤어요. %d시간 쉬어야 해요." % int(hours))
	msgs.append_array(check_stage_up())
	save_game()
	changed.emit()
	return msgs


func check_stage_up() -> Array:
	var msgs: Array = []
	while stage() < STAGE_NAMES.size() - 1:
		var req: Array = STAGE_REQ[stage()]
		if level_sum() >= int(req[0]) and workout_days() >= int(req[1]):
			data.stage = stage() + 1
			var old: String = data.get("form", "rookie")
			data.form = Forms.decide(stage())
			data.pending_evo = {"from": old, "to": data.form}
			msgs.append("어라...? %s의 모습이...!" % data.name)
		else:
			break
	return msgs


func next_stage_hint() -> String:
	if stage() >= STAGE_NAMES.size() - 1:
		return "최고 단계 달성!"
	var req: Array = STAGE_REQ[stage()]
	return "다음: 레벨합 %d/%d 운동한 날 %d/%d" % [level_sum(), req[0], workout_days(), req[1]]


## 음식 먹이기. 게이지와 능력치 XP가 음식마다 다르게 바뀐다.
func feed(id: String) -> String:
	if data.sleeping:
		return "자는 중이에요."
	if gauge("food") > 95.0:
		add_gauge("mood", -5)
		changed.emit()
		return "배불러서 더는 못 먹겠어요..."
	var f := Foods.get_food(id)
	var cheat := Foods.is_cheat(id)
	var hk := "cheat" if cheat else "healthy"
	data.hist[hk] = int(data.hist[hk]) + 1
	# 오늘 치팅 횟수: 한도를 넘기면 기분은 덜 오르고 능력치는 더 떨어진다
	if data.get("cheat_day", "") != today():
		data.cheat_day = today()
		data.cheat_count = 0
	var over := false
	if cheat:
		data.cheat_count = int(data.cheat_count) + 1
		over = int(data.cheat_count) > Foods.CHEAT_LIMIT
	for k in f.g:
		var v := float(f.g[k])
		if over and k == "mood" and v > 0:
			v *= 0.5
		add_gauge(k, v)
	var lines: Array = [f.say]
	var changes := []
	for s in f.xp:
		var v := float(f.xp[s])
		if over and v < 0:
			v *= 2.0
		var before := level(s)
		data.xp[s] = max(0.0, float(data.xp[s]) + v)
		changes.append("%s%+d" % [STAT_NAMES[s], int(v)])
		if level(s) > before:
			lines.append("%s 레벨 업! Lv.%d" % [STAT_NAMES[s], level(s)])
		elif level(s) < before:
			lines.append("%s 레벨이 떨어졌어요... Lv.%d" % [STAT_NAMES[s], level(s)])
	lines.insert(1, " ".join(changes))
	if over:
		lines.append("오늘 치팅만 %d번째... 몸이 무거워요." % int(data.cheat_count))
	lines.append_array(check_stage_up())
	var c := _resolve_call(["hungry", "fake_hungry"] + (["cheat"] if cheat else []))
	if c != "":
		lines.append(c)
	save_game()
	changed.emit()
	return "\n".join(lines)


func toggle_sleep() -> String:
	data.sleeping = not data.sleeping
	var c := _resolve_call(["sleepy", "fake_sleepy"]) if data.sleeping else ""
	save_game()
	changed.emit()
	var msg := "쿨쿨... 잘 자요." if data.sleeping else "기지개 쭉! 일어났어요."
	return msg + ("\n" + c if c != "" else "")


func stretch() -> String:
	if data.sleeping:
		return "자는 중이에요."
	add_gauge("cond", 20); add_gauge("energy", -3)
	changed.emit()
	return "폼롤러로 쭉쭉~ 몸이 풀렸어요."


func clean_up() -> String:
	if int(data.mess) == 0:
		return "이미 깨끗해요!"
	data.mess = 0
	add_gauge("mood", 6)
	var c := _resolve_call(["dirty"])
	changed.emit()
	return "땀 닦고 초크 정리 완료!" + ("\n" + c if c != "" else "")


func praise() -> String:
	if data.sleeping:
		return "쉿, 자고 있어요."
	if now() - float(data.praise_at) < 600.0:
		add_gauge("mood", 2)
		return "헤헤... (이미 많이 들었어요)"
	data.praise_at = now()
	add_gauge("mood", 18)
	var c := _resolve_call(["lonely"])
	changed.emit()
	return "하이파이브! 의욕이 솟아요!" + ("\n" + c if c != "" else "")


# ---------- 호출 / 훈육 ----------
# 진짜 호출은 들어줘야 하고, 꾀부림(fake)은 단호하게 거절해야 멘탈이 오른다.
# 가짜 배고픔은 진짜와 대사가 같아서 게이지를 보고 판단해야 한다.

const CALL_WINDOW := 30.0 * 60.0  # 이 시간 안에 반응하지 않으면 무시한 것
const CALLS := {
	"hungry": {"text": "배고파요! 밥 주세요!", "fake": false},
	"sleepy": {"text": "너무 졸려요... 재워주세요.", "fake": false},
	"dirty": {"text": "땀 범벅이에요! 닦아주세요.", "fake": false},
	"lonely": {"text": "심심해요! 놀아줘요~", "fake": false},
	"fake_hungry": {"text": "배고파요! 밥 주세요!", "fake": true},
	"cheat": {"text": "치킨 먹고 싶어요! 치킨! 치킨!", "fake": true},
	"skip": {"text": "오늘 운동... 쉬면 안 돼요?", "fake": true},
	"fake_sleepy": {"text": "졸려요... 하아암~ (운동 직전인데)", "fake": true},
}


func call_active() -> bool:
	return not (data.get("call", {}) as Dictionary).is_empty()


func call_type() -> String:
	return data.call.get("type", "")


func call_text() -> String:
	return CALLS[call_type()].text if call_active() else ""


## 진짜로 필요한 게 있으면 그 호출 종류를 돌려준다.
func _real_need() -> String:
	if gauge("food") < 30.0:
		return "hungry"
	if gauge("energy") < 25.0:
		return "sleepy"
	if int(data.mess) >= 2:
		return "dirty"
	if gauge("mood") < 35.0:
		return "lonely"
	return ""


func spawn_call(type: String = "") -> void:
	if type == "":
		type = _real_need()
	if type == "":
		var fakes := ["fake_hungry", "cheat", "skip", "fake_sleepy"]
		if gauge("food") < 60.0:
			fakes.erase("fake_hungry")
		type = fakes[randi() % fakes.size()]
	data.call = {"type": type, "at": now()}
	Sfx.play("call")
	toast.emit("%s이(가) 부르고 있어요!" % data.name)
	changed.emit()


func _check_calls() -> void:
	if data.sleeping:
		return
	if call_active():
		if now() - float(data.call.at) > CALL_WINDOW:
			_expire_call()
		return
	# 진짜 필요는 바로 부른다 (해결 직후 10분은 쉼)
	var need := _real_need()
	if need != "" and now() - float(data.get("last_call_end", 0.0)) > 600.0:
		spawn_call(need)
		return
	# 꾀부림은 가끔. 멘탈이 약할수록 자주.
	if now() >= float(data.next_fake_call):
		var gap := lerpf(40.0, 120.0, mental() / 100.0) * 60.0
		data.next_fake_call = now() + gap * randf_range(0.7, 1.3)
		if stage() >= 1 or randf() < 0.5:
			spawn_call()


func _end_call() -> void:
	data.call = {}
	data.last_call_end = now()


func _expire_call() -> void:
	var fake: bool = CALLS[call_type()].fake
	_end_call()
	if fake:
		add_mental(-1.0)
		return
	# 초반(등록생·스케일드)은 너그럽게
	data.hist.ignored = int(data.hist.ignored) + 1
	add_gauge("mood", -8.0 if stage() >= 2 else -4.0)
	toast.emit("불렀는데 아무도 없었어요... 서운해요.")


## 행동으로 호출을 해결했는지 확인한다. 꾀부림을 들어주면 멘탈이 떨어진다.
func _resolve_call(types: Array) -> String:
	if not call_active() or not types.has(call_type()):
		return ""
	var fake: bool = CALLS[call_type()].fake
	_end_call()
	if fake:
		data.hist.giveins = int(data.hist.giveins) + 1
		add_mental(-5.0)
		add_gauge("mood", 5)
		return "(헤헤, 조르니까 들어주네~) 멘탈 -5"
	data.hist.answered = int(data.hist.answered) + 1
	add_gauge("mood", 5)
	add_mental(1.0)
	return "부를 때 와줘서 고마워요!"


## A: 들어주기. 화면 이동이 필요한 경우 "food_menu"를 돌려준다.
func give_in() -> String:
	match call_type():
		"hungry", "fake_hungry":
			return "food_menu"
		"cheat":
			return feed("fried")
		"skip":
			_resolve_call(["skip"])
			data.skip_until = now() + 2.0 * 3600.0
			add_gauge("mood", 10)
			save_game()
			return "앗싸! 오늘은 쉰다~ (2시간 운동 안 함)\n멘탈 -5"
		"sleepy", "fake_sleepy":
			return toggle_sleep()
		"dirty":
			return clean_up()
		"lonely":
			return praise()
	return ""


## B: 단호하게. 꾀부림이면 멘탈이 오르고, 진짜 필요였으면 서운해한다.
func scold() -> String:
	if not call_active():
		return ""
	var fake: bool = CALLS[call_type()].fake
	_end_call()
	if fake:
		data.hist.scold_ok = int(data.hist.scold_ok) + 1
		add_mental(8.0)
		add_gauge("mood", -3)
		save_game()
		changed.emit()
		return "......네, 알겠어요. 참을게요.\n(멘탈 +8)"
	data.hist.scold_bad = int(data.hist.scold_bad) + 1
	add_gauge("mood", -10)
	save_game()
	changed.emit()
	return "진짜였는데... 억울해요 ㅠㅠ\n(기분 -10)"


# ---------- 테스트용 ----------

## (테스트) 시간을 h만큼 흘려보낸다. 하루(24시간)마다 운동한 날도 하나씩 쳐준다.
func debug_hours(h: float) -> void:
	if not data.has("workout_days"):
		data.workout_days = {}
	for i in int(ceil(h / 24.0)):
		data.workout_days["debug-%d" % data.workout_days.size()] = true
	data.last_tick = now() - h * 3600.0
	data.born = float(data.born) - h * 3600.0
	if call_active():
		data.call.at = float(data.call.at) - h * 3600.0
	catch_up()


func debug_xp(v: float) -> void:
	for s in STATS:
		data.xp[s] = float(data.xp[s]) + v
	toast.emit("(테스트) 모든 능력치 +%d XP" % int(v))
	check_stage_up()
	save_game()
	changed.emit()


# ---------- 실제 운동 연동 ----------

func real_checkin() -> String:
	var r: Dictionary = data.real
	if r.checkin_day == today():
		return "오늘은 이미 체크인했어요!"
	r.checkin_day = today()
	add_gauge("mood", 15)
	for s in STATS:
		data.xp[s] = float(data.xp[s]) + 6.0
	var msgs := check_stage_up()
	save_game()
	changed.emit()
	return "같이 운동했어요! 모든 능력치 +6 XP" + ("\n" + "\n".join(msgs) if msgs.size() else "")


## 실제 PR 입력. 기존 기록보다 높으면 보너스를 준다.
func real_pr(key: String, value: float) -> String:
	var prs: Dictionary = data.real.prs
	var old := float(prs.get(key, 0))
	if value <= old:
		return "기존 기록(%s)보다 높아야 보너스를 받아요." % Pal.num(old)
	prs[key] = value
	var stat: String = {"deadlift": "str", "squat": "str", "clean": "tec", "snatch": "tec", "pullup": "gym"}[key]
	data.xp[stat] = float(data.xp[stat]) + 30.0
	add_gauge("mood", 20)
	var msgs := check_stage_up()
	save_game()
	changed.emit()
	return "실제 PR 축하해요! %s +30 XP" % STAT_NAMES[stat] + ("\n" + "\n".join(msgs) if msgs.size() else "")
