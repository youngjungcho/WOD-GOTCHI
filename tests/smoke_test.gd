extends Node
## 자동 스모크 테스트: 실제 화면 흐름을 입력으로 몰아보고 스크린샷을 남긴다.
## 실행: godot --path . res://tests/SmokeTest.tscn

var main: Node
var out_dir := "user://shots"
var step := 0
const BACKUP := "user://save_backup_for_test.json"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	# 플레이 중인 저장 데이터는 백업해 두고 끝나면 되돌린다
	if FileAccess.file_exists(GameState.SAVE_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH), ProjectSettings.globalize_path(BACKUP))
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
	# 1RM: 메뉴 두번째 항목
	await press("a"); await press("b")
	await wait(0.2)
	await shot("lift_setup")
	await press("a"); await press("b")  # 도전!
	await wait(2.6)
	for i in 30:
		await press("a" if i % 2 == 0 else "b", 0.02)
		await wait(0.06)
	await shot("lifting")
	await wait(7.0)
	await shot("lift_result")
	await press("a"); await wait(0.1); await press("a")
	await wait(0.3)
	print("pr=", GameState.data.pr, " xp=", GameState.data.xp, " attempts=", GameState.attempts_left())
	# 리듬게임 직접 실행 (정확한 타이밍으로 자동 입력)
	var rg = RhythmGame.new("pullup", 4)
	main.push(rg)
	await wait(0.1)
	for n in rg._notes:
		while rg._now() < n.t - 0.01:
			await get_tree().process_frame
		await press(n.btn, 0.03)
		if rg._now() > n.t and rg._reps == 2:
			await shot("rhythm")
	await wait(1.5)
	await shot("rhythm_result")
	await press("a"); await wait(0.1); await press("a")
	await wait(0.3)
	print("rhythm_best=", GameState.data.rhythm_best)
	# WOD 실행
	main.push(WodRunner.new({"name": "테스트", "rounds": 1, "moves": [{"id": "burpee", "reps": 2}, {"id": "muscleup", "reps": 3}]}))
	await wait(0.5)
	await shot("wod_start")
	await press("a"); await press("a")
	await wait(0.2)
	await shot("wod_mash")
	for i in 6:
		await press("a")
	await wait(0.3)
	await shot("wod_after_mash")
	print("top=", main.top().get_script().get_global_name())
	# 머슬업이 잠겨 있으니 풀업으로 스케일 되었어야 함 -> 리듬 3개 대충 놓쳐서 떨어지게
	await wait(8.0)
	await shot("wod_result")
	await press("a"); await wait(0.1); await press("a"); await wait(0.1); await press("a")
	await wait(0.3)
	# 자유 운동: 카테고리 -> 동작 목록
	main.push(Menus.free_cat_menu(main))
	await wait(0.2)
	await shot("free_cats")
	await press("b")  # 바벨
	await wait(0.2)
	await shot("free_barbell")
	main.pop_to_root()
	# 리듬 패턴 여러 개 차트 생성 확인
	for id in ["t2b", "muscleup", "rope", "shspu", "butterfly", "pistol"]:
		var g = RhythmGame.new(id, 3)
		var reps := 0
		for n in g._notes:
			if n.rep: reps += 1
		print(id, " notes=", g._notes.size(), " reps=", reps)
		g.free()
	# 여러 영역 섞은 WOD 결과 (다양성 보너스)
	print(" / ".join(GameState.train([{"id": "thruster", "reps": 21}, {"id": "pullup", "reps": 21}, {"id": "row", "reps": 15}, {"id": "wallball", "reps": 10}])))
	print(" / ".join(GameState.train([{"id": "thruster", "reps": 21}])))
	print("picks=", GameState.daily_picks())
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
	GameState.data.sleeping = true
	await wait(0.3)
	await shot("sleeping")
	print("DONE gauges=", GameState.data.gauges, " stage=", GameState.data.stage)
	GameState.reset_game()
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(BACKUP), ProjectSettings.globalize_path(GameState.SAVE_PATH))
	get_tree().quit()
