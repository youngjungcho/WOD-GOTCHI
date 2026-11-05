extends Node
## 밸런스 시뮬레이션: 실제 GameState 규칙을 그대로 쓰고, 시계(GameState.time_offset)만 앞으로 돌린다.
## 플레이 스타일별로 60일을 돌려 진화 날짜·레벨·코인·못 한 운동·부상을 표로 출력한다.
## 실행: godot --headless --path . res://tests/BalanceSim.tscn
## 주의: 저장 파일(save/dex/hall)을 덮어쓰므로 실행 전후로 백업·복원할 것.

const DAYS := 60
const HEALTHY := ["chicken", "steak", "salmon", "eggs", "shake", "potato", "oatmeal", "yogurt", "poke"]

# wods: 운동하는 시각, feeds: 밥 주는 시각, praise/quiz/lift: 하루 횟수
# days: all(매일) / weekend(주말에만 운동) / every3(3일에 한 번 접속)
const PROFILES := {
	"가볍게": {"wods": [19], "feeds": [8, 19], "praise": 1, "quiz": 0, "stretch": false, "lift": 0, "days": "all"},
	"보통": {"wods": [12, 19], "feeds": [8, 13, 19], "praise": 2, "quiz": 1, "stretch": true, "lift": 1, "days": "all"},
	"열심히": {"wods": [8, 12, 17, 20], "feeds": [8, 12, 17, 21], "praise": 3, "quiz": 3, "stretch": true, "lift": 2, "days": "all"},
	"주말만": {"wods": [11, 16], "feeds": [9, 20], "praise": 1, "quiz": 0, "stretch": false, "lift": 1, "days": "weekend"},
	"방치형": {"wods": [19], "feeds": [19], "praise": 1, "quiz": 0, "stretch": false, "lift": 0, "days": "every3"},
}

var _midnight := 0.0
var _feed_i := 0


func _ready() -> void:
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var real := Time.get_unix_time_from_system()
	_midnight = floor((real + bias * 60) / 86400.0) * 86400.0 - bias * 60
	var rows := []
	for name in PROFILES:
		rows.append(_run(name, PROFILES[name]))
	print("\n===== 밸런스 시뮬레이션 (%d일) =====" % DAYS)
	print("스타일 | 스케일드 | RX | 컴피티터 | 게임즈 | 레벨합 d7/d14/d30/d60 | 코인 d7/d30 | 하루 운동 | 에너지로 못함 | 부상 | 멘탈")
	for r in rows:
		print(r)
	GameState.time_offset = 0.0
	get_tree().quit()


func _at(day: int, hour: float) -> void:
	GameState.time_offset = _midnight + day * 86400.0 + hour * 3600.0 - Time.get_unix_time_from_system()
	GameState.catch_up()


func _visit_day(p: Dictionary, day: int) -> bool:
	match p.days:
		"every3":
			return day % 3 == 0
	return true


func _workout_day(p: Dictionary, day: int) -> bool:
	match p.days:
		"weekend":
			return day % 7 >= 5
		"every3":
			return day % 3 == 0
	return true


func _run(name: String, p: Dictionary) -> String:
	GameState.data = {}
	_at(0, 8.0)
	GameState.new_character(name, {"skin": 0, "hair": 0, "hair_color": 0, "outfit": 0})
	var stage_day := {}
	var lv := {}
	var coins := {}
	var sessions := 0
	var skipped := 0
	for day in DAYS:
		if not _visit_day(p, day):
			if day + 1 in [7, 14, 30, 60]:
				lv[day + 1] = GameState.level_sum()
			if day + 1 in [7, 30]:
				coins[day + 1] = GameState.coins()
			continue
		# 하루 일정: (시각, 할 일)
		var events := []
		for h in p.feeds:
			events.append([float(h), "feed"])
		if _workout_day(p, day):
			for h in p.wods:
				events.append([float(h) + 0.5, "wod"])
			for i in p.lift:
				events.append([14.0 + i, "lift"])
		for i in p.praise:
			events.append([9.0 + i * 0.3, "praise"])
		for i in p.quiz:
			events.append([21.0 + i * 0.2, "quiz"])
		if p.stretch:
			events.append([18.0, "stretch"])
		if p.days != "every3":
			events.append([23.0, "sleep"])
		events.sort_custom(func(a, b): return a[0] < b[0])
		for ev in events:
			_at(day, ev[0])
			if GameState.data.sleeping and ev[1] != "sleep":
				GameState.toggle_sleep()  # 아침에 아직 자고 있으면 깨운다
			_answer_call()
			match ev[1]:
				"feed":
					if GameState.gauge("food") < 70.0:
						GameState.feed(HEALTHY[_feed_i % HEALTHY.size()])
						_feed_i += 1
					if int(GameState.data.mess) >= 2:
						GameState.clean_up()
				"praise":
					GameState.praise()
				"quiz":
					GameState.quiz_result(2, 3)
				"stretch":
					if GameState.gauge("cond") < 70.0:
						GameState.stretch_result(0.8)
				"lift":
					if GameState.workout_block_reason() == "":
						_lift()
				"wod":
					if GameState.workout_block_reason() != "":
						skipped += 1
					else:
						_wod()
						sessions += 1
				"sleep":
					if not GameState.data.sleeping:
						GameState.toggle_sleep()
			var st := GameState.stage()
			if st > 0 and not stage_day.has(st):
				stage_day[st] = day + 1
		if day + 1 in [7, 14, 30, 60]:
			lv[day + 1] = GameState.level_sum()
		if day + 1 in [7, 30]:
			coins[day + 1] = GameState.coins()
	var sd := []
	for s in [1, 2, 3, 4]:
		sd.append(str(stage_day.get(s, "-")))
	var wd := 0
	for d in DAYS:
		if _workout_day(p, d):
			wd += 1
	return "%s | %s | %s/%s/%s/%s | %s/%s | %.1f | %d | %d | %d" % [
		name, " | ".join(sd), lv.get(7, "-"), lv.get(14, "-"), lv.get(30, "-"), lv.get(60, "-"),
		coins.get(7, "-"), coins.get(30, "-"), float(sessions) / max(1, wd), skipped,
		int(GameState.data.hist.injuries), int(GameState.mental()),
	]


## 호출이 와 있으면: 꾀부림은 단호하게, 진짜는 들어준다.
func _answer_call() -> void:
	if not GameState.call_active():
		return
	if GameState.CALLS[GameState.call_type()].fake:
		GameState.scold()
	elif GameState.give_in() == "food_menu":
		GameState.feed(HEALTHY[_feed_i % HEALTHY.size()])
		_feed_i += 1


## 랜덤 WOD 한 번. 실제 플레이처럼 라이벌보다 약간 빠르게 하고, 절반은 토리를 이긴다고 본다.
func _wod() -> void:
	var w := WodGen.random()
	var base := []
	var round_sec := 0.0
	for m in w.moves:
		var id := Moves.scaled(m.id)
		base.append({"id": id, "reps": int(m.reps)})
		round_sec += Moves.rival_sec_per_rep(id) * 0.9 * int(m.reps) + 0.4
	var done := []
	var secs := 0.0
	match w.type:
		"amrap":
			secs = float(w.minutes) * 60.0 / WodGen.TIME_SCALE
			var rounds := secs / round_sec
			for b in base:
				done.append({"id": b.id, "reps": int(b.reps * rounds)})
		"emom":
			secs = float(w.minutes) * 60.0 / WodGen.TIME_SCALE
			for i in int(w.minutes):
				var b: Dictionary = base[i % base.size()]
				done.append({"id": b.id, "reps": b.reps})
		_:
			secs = round_sec * int(w.rounds)
			for r in int(w.rounds):
				for b in base:
					done.append(b.duplicate())
	var total := 0
	for d in done:
		total += int(d.reps)
	var extra := {"eng": secs / 40.0 + 3.0}
	if randf() < 0.5:
		extra["tec"] = 2.0
		extra.eng += 2.0
	GameState.train(done, extra)
	GameState.mission_event("reps", total)
	GameState.mission_event("wod")


## 1RM 한 번: 역량의 95%를 들면 성공한다고 본다.
func _lift() -> void:
	var lift := "deadlift" if GameState.attempts_left("deadlift") > 0 else "squat"
	if GameState.attempts_left(lift) <= 0:
		return
	var cap := GameState.lift_capacity(lift)
	var w := snappedf(cap * 0.95, 2.5)
	GameState.use_attempt(lift)
	GameState.mission_event("lift")
	var base: Dictionary = LiftGame.LIFTS[lift].xp
	var xp := {}
	if w > GameState.pr(lift):
		GameState.data.pr[lift] = w
		for s in base:
			xp[s] = base[s] * 0.95
	else:
		for s in base:
			xp[s] = base[s] * 0.5
	GameState.apply_workout(xp, 12.0, 6.0, false)
