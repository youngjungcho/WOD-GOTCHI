extends Node
## 자동 스모크 테스트: 실제 화면 흐름을 입력으로 몰아보고 스크린샷을 남긴다.
## 실행: godot --path . res://tests/SmokeTest.tscn

var main: Node
var out_dir := "user://shots"
var step := 0
const BACKUP := "user://save_backup_for_test.json"
const DEX_BACKUP := "user://dex_backup_for_test.json"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	# 플레이 중인 저장 데이터는 백업해 두고 끝나면 되돌린다
	if FileAccess.file_exists(GameState.SAVE_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH), ProjectSettings.globalize_path(BACKUP))
	if FileAccess.file_exists(Forms.DEX_PATH):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(Forms.DEX_PATH), ProjectSettings.globalize_path(DEX_BACKUP))
	GameState.reset_game()
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	_run()


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("%s/%02d_%s.png" % [out_dir, step, name]))
	print("shot ", step, " ", name, " top=", main.top().get_script().get_global_name())
	step += 1


func press(btn: String, hold := 0.03) -> void:
	main._press(btn, true, -1)
	await wait(hold)
	main._press(btn, false, -1)
	await get_tree().process_frame


func _run() -> void:
	await wait(0.5)
	await shot("creation")
	# 외형 바꿔보기
	var cs = main.top()
	cs.rows[1].value = 1
	cs.rows[2].value = 1
	cs.rows[3].value = 3
	cs.rows[4].value = 2
	cs.rows[0].value = "철수"
	await shot("creation_custom")
	cs._register()
	await wait(0.6)
	await shot("welcome_msg")
	await press("a"); await press("a")
	await wait(0.3)
	await shot("home")
	await press("menu")
	await wait(0.2)
	await shot("menu")
	await press("b")  # 밥 주기
	await wait(0.2)
	await shot("food_category")
	await press("b")  # 건강식
	await press("a")  # 소고기 스테이크로 이동
	await wait(0.2)
	await shot("food_healthy")
	await press("b")
	await wait(0.6)
	await shot("fed")
	await press("a"); await press("a")
	# 치팅 3번 -> 페널티 확인
	GameState.data.gauges.food = 10.0
	for i in 3:
		print(GameState.feed("pizza").replace("\n", " / "))
		GameState.data.gauges.food = 10.0
	await press("menu"); await press("b"); await press("a"); await press("b")
	await wait(0.2)
	await shot("food_cheat")
	main.pop_to_root()
	# 운동 메뉴
	await press("menu"); await press("a"); await press("b")
	await wait(0.2)
	await shot("workout_menu")
	# 1RM: 메뉴 세번째 항목 (자유 운동, 첫 WOD, 1RM)
	await press("a"); await press("a"); await press("b")
	await wait(0.2)
	await shot("lift_setup")
	await press("a"); await press("a"); await press("b")  # 도전!
	await wait(2.6)
	for i in 30:
		await press("a" if i % 2 == 0 else "b", 0.02)
		await wait(0.06)
	await shot("lifting")
	await wait(7.0)
	await shot("lift_result")
	await press("a"); await wait(0.1); await press("a")
	await wait(0.3)
	print("pr=", GameState.data.pr, " xp=", GameState.data.xp, " attempts=", GameState.attempts_left("deadlift"))
	# ---- 1RM 종목별 ----
	GameState.data.xp.tec = 100.0  # 클린·스내치 해금
	GameState.data.gauges.energy = 100.0
	for lift in ["squat", "clean", "snatch"]:
		var lg = LiftGame.new(lift, 30.0)
		main.push(lg)
		await wait(2.5)
		var shots := 0
		var guard := 0
		while lg._state == "play" and guard < 600:
			guard += 1
			var ph: Dictionary = lg._phase()
			match ph.type:
				"mash":
					await press("a" if guard % 2 == 0 else "b", 0.01)
				"descend":
					if lg._depth >= 0.95:
						await shot(lift + "_descend")
						await press("a")
				"catch":
					if abs(lg._cur - lg._zone) < 0.02:
						await shot(lift + "_catch")
						await press("a")
				"balance":
					if shots == 0:
						await shot(lift + "_balance")
						shots = 1
					await press(lg._bal_next, 0.01)
					await wait(0.08)
			await get_tree().process_frame
		await wait(0.3)
		await shot(lift + "_done")
		print(lift, " success=", lg._success, " fail=", lg._fail_msg, " pr=", GameState.pr(lift), " taps=", lg._taps, " ratio=", lg._ratio, " fps=", Engine.get_frames_per_second())
		await wait(1.0)
		await press("a"); await wait(0.1); await press("a")
		await wait(0.3)
		main.pop_to_root()
	main.push(LiftSetupScreen.new())
	await wait(0.2)
	main.top()._change(0, 2)
	await wait(0.2)
	await shot("lift_setup_clean")
	main.pop_to_root()
	# ---- WOD 자동 플레이: 동작별 조작을 봇이 정확한 타이밍에 입력 ----
	GameState.data.gauges.energy = 100.0
	var wod := {"name": "테스트", "rounds": 2, "moves": [{"id": "thruster", "reps": 3}, {"id": "du", "reps": 3}, {"id": "row", "reps": 2}, {"id": "burpee", "reps": 2}, {"id": "t2b", "reps": 2}]}
	for attempt in 2:
		var wp = WodPlay.new(wod)
		main.push(wp)
		var seen := {}
		var guard := 0
		var pacing := false
		while wp._state != "done" and guard < 6000:
			guard += 1
			await get_tree().process_frame
			if wp._state != "play" or wp._locked or wp._cool > 0.0:
				continue
			var typ: String = wp._inp.type
			if attempt == 0 and not seen.has(typ):
				seen[typ] = true
				await shot("wod_" + typ)
			# 심박 관리: 80을 넘으면 손을 떼고 50까지 쉰다
			if wp._hr > 80.0:
				pacing = true
			if pacing:
				if wp._hr < 50.0:
					pacing = false
				continue
			match typ:
				"power":
					if absf(wp._cursor - 0.5) < 0.04:
						await press("a", 0.01)
				"rope":
					if absf(fmod(wp._rope, 1.0) - 0.5) < 0.04 and not wp._rope_hit:
						await press("a", 0.01)
				"cadence":
					if wp._clock - wp._last_stroke >= float(wp._inp.interval):
						await press(wp._next_btn, 0.01)
				"combo":
					await press(wp._inp.seq[wp._step], 0.01)
					await wait(0.08)
				"beat":
					var nt: float = wp._beat_t0 + wp._beat_n * wp._beat_len()
					var want: String = wp._pat[wp._beat_n % wp._pat.size()]
					if want != "" and absf(wp._clock - nt) < 0.03:
						await press(want, 0.01)
		print("wod attempt ", attempt, " time=", snappedf(wp._clock, 0.1), " rival=", snappedf(wp._rival_time, 0.1), " best=", wod.get("best"), " done=", wp._done)
		await wait(2.0)
		if attempt == 0:
			await shot("wod_result")
		await press("a"); await wait(0.1); await press("a"); await wait(0.1); await press("a")
		await wait(0.3)
		main.pop_to_root()
	# 심박 100 → 강제 휴식 확인
	var wp2 = WodPlay.new({"name": "연타", "rounds": 1, "moves": [{"id": "burpee", "reps": 30}]})
	main.push(wp2)
	await wait(2.6)
	for i in 60:
		await press(wp2._inp.seq[wp2._step], 0.005)
		if wp2._locked:
			break
	await shot("wod_locked")
	print("locked=", wp2._locked, " hr=", wp2._hr)
	await press("menu")
	await wait(2.0)
	await press("a"); await wait(0.1); await press("a")
	main.pop_to_root()
	# 자유 운동: 카테고리 -> 동작 목록
	main.push(Menus.free_cat_menu(main))
	await wait(0.2)
	await shot("free_cats")
	await press("b")  # 바벨
	await wait(0.2)
	await shot("free_barbell")
	main.pop_to_root()
	# 여러 영역 섞은 WOD 결과 (다양성 보너스)
	print(" / ".join(GameState.train([{"id": "thruster", "reps": 21}, {"id": "pullup", "reps": 21}, {"id": "row", "reps": 15}, {"id": "wallball", "reps": 10}])))
	print(" / ".join(GameState.train([{"id": "thruster", "reps": 21}])))
	print("picks=", GameState.daily_picks())
	for lv in [1, 2, 3, 5, 8, 12]:
		print("curve Lv", lv, "=", GameState.xp_for_level(lv), " back=", GameState.level_for_xp(GameState.xp_for_level(lv)), " below=", GameState.level_for_xp(GameState.xp_for_level(lv) - 0.01))
	print("sessions_today=", GameState.sessions_today())
	# WOD 에디터 + 동작 고르기
	var ed = WodEditor.new(-1)
	main.push(ed)
	await wait(0.2)
	ed.rows[2].value = "thruster"
	ed.rows[4].value = "muscleup"
	ed.rows[6].value = "row"
	await wait(0.2)
	await shot("wod_editor")
	ed._change(2, 1)  # 동작 칸 누르기 -> 피커
	await wait(0.2)
	await shot("move_picker")
	main.pop_to_root()
	main.push(RealPrScreen.new())
	await wait(0.2)
	await shot("real_pr")
	main.pop()
	main.push(StatsScreen.new())
	await wait(0.2)
	await shot("stats")
	main.pop()
	# ---- 호출 / 훈육 ----
	main.pop_to_root()
	GameState.data.gauges.food = 90.0
	GameState.spawn_call("fake_hungry")
	await wait(0.4)
	await shot("call_fake")
	await press("b")  # 단호하게 -> 정답
	await wait(0.6)
	await shot("scold_ok")
	await press("a"); await press("a")
	print("mental after scold=", GameState.mental())
	GameState.spawn_call("cheat")
	await press("a")  # 들어주기 -> 치킨
	await wait(0.4)
	print("mental after give-in=", GameState.mental(), " hist=", GameState.data.hist)
	await press("a"); await press("a"); await press("a")
	GameState.data.gauges.food = 10.0
	GameState.data.last_call_end = 0.0
	GameState._check_calls()
	print("real call=", GameState.call_type())
	await press("b")  # 진짜인데 혼냄
	await wait(0.4)
	await shot("scold_bad")
	await press("a"); await press("a")
	# 호출 만료
	GameState.spawn_call("lonely")
	GameState.debug_hours(1.0)
	print("after expire call_active=", GameState.call_active(), " ignored=", GameState.data.hist.ignored)
	main.pop_to_root()
	# ---- 진화 ----
	GameState.data.mental = 80.0
	GameState.debug_hours(30.0)
	GameState.debug_xp(80.0)
	await wait(0.5)
	await shot("evolving")
	await wait(3.6)
	await shot("evolved")
	await wait(0.7)
	await press("a")
	await wait(0.3)
	print("form=", GameState.data.form, " title=", GameState.title(), " stage=", GameState.stage())
	# 스케일드 -> RX(체조 위주)
	GameState.data.xp.gym = 400.0
	GameState.debug_hours(48.0)
	GameState.debug_xp(150.0)
	await wait(0.3)
	main.top().t = 99.0
	await wait(0.8)
	await shot("evolved_rx")
	await press("a")
	await wait(0.3)
	print("form=", GameState.data.form, " title=", GameState.title())
	await shot("home_rx")
	# 외형 미리보기: 모든 진화형
	var gallery := Control.new()
	gallery.size = Vector2(180, 236)
	gallery.draw.connect(func():
		gallery.draw_rect(Rect2(0, 0, 180, 236), Pal.LIGHT)
		var i := 0
		for id in Forms.LIST:
			var pos := Vector2(2 + (i % 5) * 36, 2 + (i / 5) * 46)
			Pal.athlete(gallery, pos, GameState.data.look, "idle", 1, 1.0, 0.0, Forms.style_of(id), 34)
			Pal.text(gallery, pos + Vector2(0, 34), Forms.name_of(id).left(3), Pal.INK)
			i += 1)
	main.add_child(gallery)
	await wait(0.2)
	await shot("all_forms")
	gallery.queue_free()
	main.push(DexScreen.new())
	await wait(0.2)
	await shot("dex")
	main.pop()
	# ---- 잠: 회복 속도와 자동 기상 ----
	GameState.data.gauges.energy = 40.0
	GameState.data.sleeping = true
	print("sleep eta=", GameState.sleep_eta_minutes(), "min rate=", GameState.sleep_rate())
	await wait(0.3)
	await shot("sleeping")
	# 꿈속 퀴즈
	main.push(QuizScreen.new())
	await wait(0.3)
	await shot("quiz_dream")
	for i in 3:
		await press("b"); await wait(0.2)
		if i == 0:
			await shot("quiz_answer")
		await press("a"); await wait(0.2)
	await wait(0.3)
	await shot("quiz_result")
	await press("a"); await wait(0.1); await press("a")
	main.pop_to_root()
	GameState._advance(2.0, true)
	print("after 2h sleep: sleeping=", GameState.data.sleeping, " energy=", GameState.gauge("energy"))
	# 스트레칭 균형 게임: 봇이 가운데를 유지
	GameState.data.gauges.cond = 30.0
	var sg = StretchGame.new()
	main.push(sg)
	while not sg._ended:
		await get_tree().process_frame
		var want_a: bool = sg._m > 0.05 or sg._v > 0.3
		var want_b: bool = sg._m < -0.05 or sg._v < -0.3
		if want_a != sg._hold_a:
			main._press("a", want_a, -1)
		if want_b != sg._hold_b:
			main._press("b", want_b, -1)
		if sg._clock > 5.0 and sg._clock < 5.05:
			await shot("stretch")
	main._press("a", false, -1); main._press("b", false, -1)
	print("stretch in_zone=", snappedf(sg._in_zone, 0.1), " cond=", GameState.gauge("cond"))
	await wait(0.3)
	await press("a"); await wait(0.1); await press("a")
	main.pop_to_root()
	print("DONE gauges=", GameState.data.gauges, " stage=", GameState.data.stage)
	GameState.reset_game()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Forms.DEX_PATH))
	if FileAccess.file_exists(DEX_BACKUP):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(DEX_BACKUP), ProjectSettings.globalize_path(Forms.DEX_PATH))
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(BACKUP), ProjectSettings.globalize_path(GameState.SAVE_PATH))
	get_tree().quit()
