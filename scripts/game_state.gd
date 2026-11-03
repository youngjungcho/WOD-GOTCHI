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
# 다음 단계로 가기 위한 조건: [능력치 레벨 합계, 키운 일수]
const STAGE_REQ := [[8, 0], [16, 2], [28, 6], [44, 13]]

# 시간당 기본 변화량
const DECAY_PER_HOUR := {"food": 6.0, "energy": 4.0, "mood": 3.0, "cond": 2.0}

const STATS := ["str", "gym", "eng", "tec"]
const STAT_NAMES := {"str": "근력", "gym": "체조", "eng": "엔진", "tec": "기술"}
const GAUGE_NAMES := {"food": "영양", "energy": "에너지", "mood": "의욕", "cond": "컨디션"}

const LIFTS := {"deadlift": "데드리프트", "squat": "백스쿼트", "clean": "클린", "snatch": "스내치"}
const ATTEMPTS_PER_DAY := 3

var data: Dictionary = {}
var _accum := 0.0


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
		changed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
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
		"pr": {"deadlift": 0.0},
		"rhythm_best": {},
		"move_log": {},
		"attempt_day": "",
		"attempts_left": ATTEMPTS_PER_DAY,
		"real": {"checkin_day": "", "prs": {"deadlift": 0, "squat": 0, "clean": 0, "snatch": 0, "pullup": 0}},
		"wods": [
			{"name": "첫 WOD", "rounds": 3, "moves": [{"id": "pullup", "reps": 5}, {"id": "deadlift", "reps": 5}, {"id": "burpee", "reps": 5}]},
		],
	}
	save_game()
	changed.emit()


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


static func level_for_xp(xp: float) -> int:
	return int(floor(sqrt(max(xp, 0.0) / 10.0))) + 1


static func xp_for_level(lv: int) -> float:
	return 10.0 * pow(lv - 1, 2)


func level(stat: String) -> int:
	return level_for_xp(float(data.xp[stat]))


func level_sum() -> int:
	var s := 0
	for k in STATS:
		s += level(k)
	return s


func days_alive() -> int:
	return int((now() - float(data.born)) / 86400.0)


func stage() -> int:
	return int(data.stage)


func title() -> String:
	var st := stage()
	if st < 2:
		return STAGE_NAMES[st]
	var best := "str"
	for k in STATS:
		if level(k) > level(best):
			best = k
	var lo := 999
	var hi := 0
	for k in STATS:
		lo = min(lo, level(k))
		hi = max(hi, level(k))
	var branch := ""
	if hi - lo <= 1:
		branch = "올라운더"
	else:
		branch = {"str": "바벨 괴물", "gym": "체조 요정", "eng": "카디오 머신", "tec": "테크니션"}[best]
	return "%s %s" % [STAGE_NAMES[st], branch]


func is_muscular() -> bool:
	return stage() >= 2 and level("str") >= level("gym")


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
	if gauge("energy") < 15.0:
		return "너무 피곤해서 못하겠어요..."
	if gauge("mood") < 15.0:
		return "오늘은 운동하기 싫대요. 칭찬해 주세요."
	return ""


## 1RM 역량(kg). 근력·기술 레벨과 당일 컨디션으로 정해진다.
func lift_capacity(lift: String = "deadlift") -> float:
	var base := 40.0 + (level("str") - 1) * 8.0 + (level("tec") - 1) * 2.0
	if lift == "squat":
		base *= 0.85
	var cond := 0.8 + 0.2 * (gauge("energy") + gauge("cond")) / 200.0
	cond *= 0.95 + 0.1 * gauge("mood") / 100.0
	return base * cond


func attempts_left() -> int:
	if data.attempt_day != today():
		data.attempt_day = today()
		data.attempts_left = ATTEMPTS_PER_DAY
	return int(data.attempts_left)


func use_attempt() -> void:
	attempts_left()
	data.attempts_left = int(data.attempts_left) - 1


func _migrate() -> void:
	# 예전 리듬게임 기록 키(strict)를 동작 id로 옮긴다
	var rb: Dictionary = data.get("rhythm_best", {})
	if rb.has("strict"):
		rb["pullup"] = max(int(rb.get("pullup", 0)), int(rb.strict))
		rb.erase("strict")
	data.rhythm_best = rb
	if not data.has("move_log"):
		data.move_log = {}


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
func apply_workout(xp: Dictionary, energy_cost: float, cond_cost: float) -> Array:
	var msgs: Array = []
	var food_mult := 0.5 if gauge("food") < 20.0 else 1.0
	if food_mult < 1.0:
		msgs.append("배가 고파서 효과가 절반이에요.")
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
	if low_cond and randf() < 0.3:
		var hours := 2.0 if stage() < 2 else 6.0
		data.injured_until = now() + hours * 3600.0
		msgs.append("앗! 무리해서 다쳤어요. %d시간 쉬어야 해요." % int(hours))
	msgs.append_array(check_stage_up())
	save_game()
	changed.emit()
	return msgs


func check_stage_up() -> Array:
	var msgs: Array = []
	while stage() < STAGE_NAMES.size() - 1:
		var req: Array = STAGE_REQ[stage()]
		if level_sum() >= int(req[0]) and days_alive() >= int(req[1]):
			data.stage = stage() + 1
			msgs.append("진화! [%s] 이(가) 되었어요!" % STAGE_NAMES[stage()])
		else:
			break
	return msgs


func next_stage_hint() -> String:
	if stage() >= STAGE_NAMES.size() - 1:
		return "최고 단계 달성!"
	var req: Array = STAGE_REQ[stage()]
	return "다음 단계: 레벨합 %d/%d, %d/%d일" % [level_sum(), req[0], days_alive(), req[1]]


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
	save_game()
	changed.emit()
	return "\n".join(lines)


func toggle_sleep() -> String:
	data.sleeping = not data.sleeping
	save_game()
	changed.emit()
	return "쿨쿨... 잘 자요." if data.sleeping else "기지개 쭉! 일어났어요."


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
	changed.emit()
	return "땀 닦고 초크 정리 완료!"


func praise() -> String:
	if data.sleeping:
		return "쉿, 자고 있어요."
	if now() - float(data.praise_at) < 600.0:
		add_gauge("mood", 2)
		return "헤헤... (이미 많이 들었어요)"
	data.praise_at = now()
	add_gauge("mood", 18)
	changed.emit()
	return "하이파이브! 의욕이 솟아요!"


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
