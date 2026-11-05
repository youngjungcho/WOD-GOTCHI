class_name Menus
extends RefCounted
## 홈에서 여는 행동 메뉴 트리.


static func main_menu(main: Node) -> ListScreen:
	var sleeping: bool = GameState.data.sleeping
	return ListScreen.new("무엇을 할까?", [
		{"label": "밥 주기", "cb": func(): main.push(food_menu(main))},
		{"label": "운동하기", "cb": func(): _try_workout(main, func(): main.push(workout_menu(main)))},
		{"label": "깨우기" if sleeping else "재우기", "cb": func(): _done(main, GameState.toggle_sleep())},
		{"label": "케어", "cb": func(): main.push(care_menu(main))},
		{"label": "꿈속 퀴즈" if sleeping else "운동·건강 퀴즈", "cb": func(): main.pop(); main.push(QuizScreen.new())},
		{"label": "내 WOD 짜기", "cb": func(): main.push(wod_list_menu(main))},
		{"label": "실제 운동 기록", "cb": func(): main.push(real_menu(main))},
		{"label": "화이트보드", "cb": func(): main.pop(); main.push(StatsScreen.new())},
		{"label": "도감", "cb": func(): main.pop(); main.push(DexScreen.new())},
		{"label": "처음부터 다시", "cb": func(): main.push(reset_menu(main))},
	])


static func _done(main: Node, msg: String) -> void:
	main.pop_to_root()
	main.say(msg)


static func _try_workout(main: Node, then: Callable) -> void:
	var why := GameState.workout_block_reason()
	if why != "":
		Sfx.play("miss")
		main.show_toast(why)
		return
	then.call()


static func food_menu(main: Node) -> ListScreen:
	return ListScreen.new("메뉴판", [
		{"label": "건강식", "cb": func(): main.push(_food_list(main, "건강식", Foods.HEALTHY)), "desc": "능력치가 골고루 올라요."},
		{"label": "일반식 (치팅)", "cb": func(): main.push(_food_list(main, "일반식 (치팅)", Foods.CHEAT)), "desc": "기분은 좋아지지만 능력치가 떨어져요. 하루 %d번 넘게 먹으면 더 손해!" % Foods.CHEAT_LIMIT},
	])


static func _food_list(main: Node, title: String, foods: Dictionary) -> ListScreen:
	var items := []
	for id in foods:
		items.append({"label": foods[id].name, "cb": func(): _done(main, GameState.feed(id)), "desc": Foods.describe(id)})
	return ListScreen.new(title, items)


static func care_menu(main: Node) -> ListScreen:
	return ListScreen.new("케어", [
		{"label": "스트레칭 (균형 게임)", "cb": func():
			if GameState.data.sleeping:
				main.show_toast("자는 중이에요.")
				return
			main.pop_to_root()
			main.push(StretchGame.new()), "desc": "에너지 없이 컨디션 회복!"},
		{"label": "땀 닦고 정리하기", "cb": func(): _done(main, GameState.clean_up())},
	])


static func workout_menu(main: Node) -> ListScreen:
	var picks := []
	for id in GameState.daily_picks():
		picks.append(Moves.name_of(id))
	var items := [{
		"label": "자유 운동 (동작 고르기)",
		"cb": func(): main.push(free_cat_menu(main)),
		"desc": "오늘의 추천 x%s: %s" % [Pal.num(GameState.PICK_BONUS), ", ".join(picks)],
	}]
	var today := WodGen.today()
	items.append({"label": "오늘의 WOD", "cb": func(): main.push(wod_preview(main, today, false)), "desc": WodGen.summary(today)})
	items.append({"label": "랜덤 WOD 뽑기", "cb": func(): main.push(wod_preview(main, WodGen.random(), true)), "desc": "방식·동작·횟수가 매번 새로!"})
	var wods: Array = GameState.data.wods
	for w in wods:
		items.append({"label": "내 WOD: %s" % w.name, "cb": func(): main.pop_to_root(); main.push(WodPlay.new(w)), "desc": wod_summary(w)})
	var left := GameState.attempts_left()
	items.append({
		"label": "1RM 챌린지 (%d/%d)" % [left, GameState.attempts_max()],
		"cb": func(): main.push(LiftSetupScreen.new()),
		"disabled": left <= 0,
		"hint": "오늘 시기를 다 썼어요. 내일 다시!",
		"desc": "데드·스쿼트·클린·스내치 최대 무게 도전! 종목마다 하루 %d번." % GameState.ATTEMPTS_PER_DAY,
	})
	items.append({"label": "조작 설명 다시 보기", "cb": func():
		GameState.reset_tutorials()
		_done(main, "다음 운동부터 조작 설명을 다시 보여드릴게요."), "desc": "동작별 버튼 사용법을 다시 봐요."})
	return ListScreen.new("운동 고르기", items)


static func wod_summary(w: Dictionary) -> String:
	var best := float(w.get("best", 0.0))
	var rec := ""
	if best > 0.0:
		match w.get("type", "fortime"):
			"amrap":
				rec = "  내 기록 %d회" % int(best)
			"emom":
				rec = "  내 기록 %d분" % int(best)
			_:
				rec = "  내 기록 %s" % WodPlay._fmt(best)
	return WodGen.summary(w) + rec


## WOD 미리보기: 시작 / (랜덤이면) 다시 뽑기 / 내 WOD에 저장
static func wod_preview(main: Node, w: Dictionary, reroll: bool) -> ListScreen:
	var items := [{"label": "시작!", "cb": func(): main.pop_to_root(); main.push(WodPlay.new(w)), "desc": WodGen.summary(w)}]
	if reroll:
		items.append({"label": "다시 뽑기", "cb": func(): main.pop(); main.push(wod_preview(main, WodGen.random(), true)), "desc": "다른 WOD로 바꿔요."})
	items.append({"label": "내 WOD에 저장", "cb": func(): _save_wod(main, w), "desc": "저장하면 언제든 다시 하고 기록을 비교할 수 있어요."})
	return ListScreen.new(w.name, items)


static func save_wod_menu(main: Node, w: Dictionary) -> ListScreen:
	return ListScreen.new("이 WOD를 저장할까요?", [
		{"label": "저장하기 (%d/5)" % GameState.data.wods.size(), "cb": func(): _save_wod(main, w), "desc": WodGen.summary(w)},
		{"label": "괜찮아요", "cb": func(): main.pop_to_root()},
	])


static func _save_wod(main: Node, w: Dictionary) -> void:
	var wods: Array = GameState.data.wods
	if wods.size() >= 5:
		main.show_toast("내 WOD가 가득 찼어요 (5개). 하나 지워 주세요.")
		return
	var copy := w.duplicate(true)
	copy.erase("temp")
	copy.name = String(copy.name).replace("오늘의 WOD: ", "")
	wods.append(copy)
	GameState.save_game()
	main.pop_to_root()
	main.say("'%s' 저장 완료! 운동하기 메뉴에서 다시 할 수 있어요." % copy.name)


static func free_cat_menu(main: Node) -> ListScreen:
	var items := []
	for cat in Moves.CATS:
		var total := Moves.ids_in(cat).size()
		var open := 0
		for id in Moves.ids_in(cat):
			if Moves.unlocked(id):
				open += 1
		items.append({
			"label": "%s (%d/%d)" % [Moves.CATS[cat], open, total],
			"cb": func(): main.push(free_move_menu(main, cat)),
			"desc": "해금한 동작 %d개 / 전체 %d개" % [open, total],
		})
	return ListScreen.new("자유 운동", items)


## 동작 목록. 오늘의 추천은 ★, 잠긴 동작은 (잠김).
static func _move_label(id: String) -> String:
	var star := "★" if GameState.daily_picks().has(id) else ""
	if not Moves.unlocked(id):
		return "%s (잠김)" % Moves.name_of(id)
	return star + Moves.name_of(id)


static func free_move_menu(main: Node, cat: String) -> ListScreen:
	var items := []
	for id in Moves.ids_in(cat):
		items.append({
			"label": _move_label(id),
			"cb": func(): _start_move(main, id),
			"disabled": not Moves.unlocked(id),
			"hint": Moves.req_text(id),
			"desc": Moves.describe(id),
		})
	return ListScreen.new(Moves.CATS[cat], items)


static func _start_move(main: Node, id: String) -> void:
	main.pop_to_root()
	# 자유 운동도 1라운드짜리 WOD로 실행한다
	main.push(WodPlay.new({"name": Moves.name_of(id), "rounds": 1, "moves": [{"id": id, "reps": Moves.default_reps(id)}]}))


## WOD 편집용 동작 고르기. 잠긴 동작도 넣을 수 있다(실행할 때 스케일).
static func move_picker(main: Node, on_pick: Callable) -> ListScreen:
	var items := [{"label": "(비우기)", "cb": func(): main.pop(); on_pick.call("none"), "desc": "이 칸을 비워요."}]
	for cat in Moves.CATS:
		items.append({"label": Moves.CATS[cat], "cb": func(): main.push(_picker_moves(main, cat, on_pick)), "desc": "%d개 동작" % Moves.ids_in(cat).size()})
	return ListScreen.new("동작 고르기", items)


static func _picker_moves(main: Node, cat: String, on_pick: Callable) -> ListScreen:
	var items := []
	for id in Moves.ids_in(cat):
		items.append({"label": _move_label(id), "cb": func(): main.pop(); main.pop(); on_pick.call(id), "desc": Moves.describe(id)})
	return ListScreen.new(Moves.CATS[cat], items)


static func wod_list_menu(main: Node) -> ListScreen:
	var items := []
	var wods: Array = GameState.data.wods
	for i in wods.size():
		var w: Dictionary = wods[i]
		items.append({"label": w.name, "cb": func(): main.push(wod_actions_menu(main, i))})
	if wods.size() < 5:
		items.append({"label": "+ 새 WOD 만들기", "cb": func(): main.pop(); main.push(WodEditor.new(-1))})
	return ListScreen.new("내 WOD 목록", items)


static func wod_actions_menu(main: Node, idx: int) -> ListScreen:
	var w: Dictionary = GameState.data.wods[idx]
	return ListScreen.new(w.name, [
		{"label": "지금 하기", "cb": func(): _try_workout(main, func(): main.pop_to_root(); main.push(WodPlay.new(w)))},
		{"label": "고치기", "cb": func(): main.pop(); main.pop(); main.push(WodEditor.new(idx))},
		{"label": "지우기", "cb": func():
			GameState.data.wods.remove_at(idx)
			GameState.save_game()
			_done(main, "WOD를 지웠어요.")},
	])


static func real_menu(main: Node) -> ListScreen:
	return ListScreen.new("실제 운동 기록", [
		{"label": "오늘 나도 운동했어요!", "cb": func(): _done(main, GameState.real_checkin())},
		{"label": "실제 PR 입력", "cb": func(): main.pop(); main.push(RealPrScreen.new())},
	])


static func reset_menu(main: Node) -> ListScreen:
	return ListScreen.new("정말 처음부터?", [
		{"label": "아니요", "cb": func(): main.pop_to_root()},
		{"label": "네, 새로 시작할래요", "cb": func():
			GameState.reset_game()
			main.goto(CreationScreen.new())},
	])
