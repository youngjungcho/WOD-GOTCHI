class_name WodEditor
extends FormScreen
## WOD 직접 짜기: 이름, 방식(For Time/AMRAP/EMOM), 시간, 라운드, 동작 최대 4개와 횟수.
## 동작 칸을 누르면 카테고리별 동작 목록이 열린다.

const SLOTS := 4
const TYPES := ["fortime", "amrap", "emom"]
const FIRST_MOVE_ROW := 4

var _idx: int


func _init(idx: int) -> void:
	_idx = idx
	var w: Dictionary = GameState.data.wods[idx] if idx >= 0 else {"name": "내 WOD", "type": "fortime", "rounds": 3, "cap": 10, "moves": []}
	var wtype: String = w.get("type", "fortime")
	var minutes: float = float(w.get("minutes", w.get("cap", 10)))
	var r := [
		{"label": "이름", "type": "text", "value": w.name, "max_len": 8},
		{"label": "방식", "type": "choice", "value": TYPES.find(wtype), "options": ["FOR TIME", "AMRAP", "EMOM"]},
		{"label": "시간(분)", "type": "number", "value": minutes, "min": 3.0, "max": 30.0, "step": 1.0, "fmt": "%s분"},
		{"label": "라운드", "type": "number", "value": float(w.get("rounds", 3)), "min": 1.0, "max": 10.0, "step": 1.0},
	]
	for i in SLOTS:
		var m: Dictionary = w.moves[i] if i < w.moves.size() else {"id": "none", "reps": 10}
		var row := {"label": "동작 %d" % (i + 1), "type": "pick", "value": m.id, "show": _show_move}
		row.cb = func(): main.push(Menus.move_picker(main, func(id): row.value = id))
		r.append(row)
		r.append({"label": "  횟수", "type": "number", "value": float(m.reps), "min": 1.0, "max": 100.0, "step": 1.0})
	r.append({"label": "저장하기", "type": "button", "cb": _save})
	super("WOD 짜기", r)
	row_h = 13


func _show_move(id: String) -> String:
	if id == "none":
		return "(비어 있음)"
	return Moves.name_of(id) + ("" if Moves.unlocked(id) else "*")


func _moves() -> Array:
	var moves := []
	for i in SLOTS:
		var id: String = value(FIRST_MOVE_ROW + i * 2)
		if id != "none":
			moves.append({"id": id, "reps": int(value(FIRST_MOVE_ROW + 1 + i * 2))})
	return moves


func _save() -> void:
	var moves := _moves()
	if moves.is_empty():
		main.show_toast("동작을 하나 이상 넣어주세요.")
		return
	var n := str(value(0)).strip_edges()
	var wtype: String = TYPES[int(value(1))]
	var w := {"name": n if n != "" else "내 WOD", "type": wtype, "rounds": int(value(3)), "moves": moves}
	# For Time은 시간이 타임캡, AMRAP·EMOM은 진행 시간
	if wtype == "fortime":
		w.cap = int(value(2))
	else:
		w.minutes = int(value(2))
	if _idx >= 0:
		GameState.data.wods[_idx] = w
	else:
		GameState.data.wods.append(w)
	GameState.save_game()
	main.pop_to_root()
	main.say("'%s' 저장 완료! 운동하기 메뉴에서 할 수 있어요." % w.name)


func _draw() -> void:
	super()
	# 아래쪽: 이 WOD로 예상되는 능력치 분배
	var xp := {}
	var cats := {}
	for m in _moves():
		cats[Moves.LIST[m.id].cat] = true
		var per := Moves.xp_per_rep(Moves.scaled(m.id))
		for s in per:
			xp[s] = float(xp.get(s, 0.0)) + per[s] * int(m.reps) * int(value(3))
	var y := size.y - 23
	draw_rect(Rect2(2, y - 2, size.x - 4, 25), Pal.WHITE)
	Pal.frame(self, Rect2(2, y - 2, size.x - 4, 25), Pal.INK)
	var total := 0.0
	for s in xp:
		total += xp[s]
	var x := 6.0
	var cols := {"str": Pal.RED, "gym": Pal.BLUE, "eng": Pal.GREEN, "tec": Pal.YELLOW}
	for s in GameState.STATS:
		if total <= 0.0:
			break
		var w := (size.x - 12) * float(xp.get(s, 0.0)) / total
		draw_rect(Rect2(x, y + 2, w, 6), cols[s])
		x += w
	var parts := []
	for s in GameState.STATS:
		if float(xp.get(s, 0.0)) >= 1.0:
			parts.append("%s%d" % [GameState.STAT_NAMES[s].left(1), int(xp[s] * GameState.XP_SCALE)])
	Pal.text(self, Vector2(6, y + 11), "예상XP %s · %d영역" % [" ".join(parts), cats.size()], Pal.INK)
