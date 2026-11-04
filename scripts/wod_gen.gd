class_name WodGen
extends RefCounted
## 랜덤 WOD 생성기. 해금된 동작 중 여러 카테고리를 섞어 방식·횟수·시간을 정한다.
## WOD 사전: {name, type: fortime|amrap|emom, rounds, minutes(amrap·emom), cap(fortime 타임캡 분), moves}
## 시간은 모두 게임 시간(분). 게임 시계는 실제 1초에 TIME_SCALE초씩 흐른다.

const TIME_SCALE := 6.0
const TYPE_NAMES := {"fortime": "FOR TIME", "amrap": "AMRAP", "emom": "EMOM"}

const NAMES := [
	"불꽃", "땀범벅", "심장 폭발", "월요병 퇴치", "토리의 도전", "아침 번개", "지옥의 계단",
	"꿀벅지", "강철 그립", "폐활량 테스트", "주말 특집", "코치의 선물", "숨멎", "하트 비트",
]


## 오늘의 WOD: 같은 날에는 같은 WOD (캐릭터마다 다름).
static func today() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("wod" + GameState.today() + str(GameState.data.get("born", 0)))
	var w := generate(rng)
	w.name = "오늘의 WOD: " + w.name
	return w


static func random() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return generate(rng)


static func generate(rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randf()
	var type := "fortime"
	if roll > 0.75:
		type = "emom"
	elif roll > 0.42:
		type = "amrap"
	var chipper := type == "fortime" and rng.randf() < 0.2
	var n_moves := 1 + rng.randi_range(1, 3)  # 2~4개
	if type == "emom":
		n_moves = rng.randi_range(1, 3)
	if chipper:
		n_moves = rng.randi_range(3, 5)
	var ids := _pick_moves(rng, n_moves)
	# 실제 플레이가 1~2분 정도가 되도록 횟수를 맞춘다 (단계가 오를수록 조금씩 늘어남)
	var lv_mult := 0.8 + 0.12 * GameState.stage()
	var moves := []
	for id in ids:
		var reps := _reps_for(rng, id, lv_mult)
		match type:
			"amrap":
				reps = maxi(2, int(reps * 0.7))
			"emom":
				# 실제 약 6.5초 안에 끝낼 수 있는 횟수
				reps = clampi(int(6.5 / Moves.rival_sec_per_rep(id)), 2, 15)
		if chipper:
			reps = int(reps * 2.2)
		moves.append({"id": id, "reps": reps})
	var w := {"name": NAMES[rng.randi() % NAMES.size()], "type": type, "rounds": 1, "moves": moves, "temp": true}
	match type:
		"fortime":
			w.rounds = 1 if chipper else rng.randi_range(2, 3)
			w.cap = cap_for(w)
			if chipper:
				w.name += " 칩퍼"
		"amrap":
			w.minutes = rng.randi_range(5, 10)
		"emom":
			w.minutes = [6, 8, 10][rng.randi() % 3]
	return w


## For Time 타임캡(게임 분): 라이벌 예상 시간의 1.5배.
static func cap_for(w: Dictionary) -> int:
	var sec := 0.0
	for m in w.moves:
		sec += Moves.rival_sec_per_rep(Moves.scaled(m.id)) * int(m.reps) + 1.0
	sec *= int(w.get("rounds", 1)) * TIME_SCALE
	return clampi(int(ceil(sec * 1.5 / 60.0)), 3, 30)


static func _pick_moves(rng: RandomNumberGenerator, n: int) -> Array:
	var cats: Array = Moves.CATS.keys()
	# 카테고리 순서를 섞어서 서로 다른 영역부터 고른다
	for i in range(cats.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = cats[i]
		cats[i] = cats[j]
		cats[j] = tmp
	var out := []
	var k := 0
	while out.size() < n and k < 20:
		var cat: String = cats[k % cats.size()]
		k += 1
		var pool := []
		for id in Moves.ids_in(cat):
			if Moves.unlocked(id) and not out.has(id):
				pool.append(id)
		if pool.is_empty():
			continue
		# 최근에 덜 한 동작이 더 잘 뽑힌다
		pool.sort_custom(func(x, y): return GameState.recent_count(x) < GameState.recent_count(y))
		var top := pool.slice(0, maxi(3, pool.size() / 2))
		out.append(top[rng.randi() % top.size()])
	return out


static func _reps_for(rng: RandomNumberGenerator, id: String, mult: float) -> int:
	var inp := Moves.input_of(id)
	var lo := 5
	var hi := 12
	match inp.type:
		"rope":
			lo = 15 if id == "su" else 8
			hi = 30 if id == "su" else 20
		"cadence":
			lo = 6
			hi = 15
		"beat":
			lo = 3
			hi = 8
			if Moves.LIST[id].get("mu", false):
				lo = 2
				hi = 5
		"combo":
			lo = 5
			hi = 15
	return maxi(1, int(rng.randi_range(lo, hi) * mult))


## 메뉴에 보여줄 한 줄 요약.
static func summary(w: Dictionary) -> String:
	var parts := []
	for m in w.moves:
		parts.append("%s %d" % [Moves.name_of(m.id), int(m.reps)])
	var head := ""
	match w.get("type", "fortime"):
		"amrap":
			head = "AMRAP %d분" % int(w.minutes)
		"emom":
			head = "EMOM %d분 (매 분 교대)" % int(w.minutes)
		_:
			head = "FOR TIME %d라운드 (캡 %d분)" % [int(w.rounds), int(w.get("cap", cap_for(w)))]
	return head + ": " + ", ".join(parts)
