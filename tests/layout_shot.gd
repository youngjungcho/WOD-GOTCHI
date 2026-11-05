extends Node
## 휴대폰 비율(390x844) 창에서 화면 배치만 빠르게 찍어 본다. 저장 데이터는 건드리지 않는다.
## 실행: godot --path . res://tests/LayoutShot.tscn

var main: Node


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(390, 844))
	await get_tree().create_timer(0.3).timeout
	GameState.data = {}
	GameState.new_character("치비", {"skin": 0, "hair": 1, "hair_color": 2, "outfit": 3})
	GameState.mark_tutorial("call")
	GameState.mark_tutorial("home")
	GameState.data.erase("pending_stamp")
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.8).timeout
	await _shot("phone_guide")
	for i in 10:
		main._press("a", true, -1); main._press("a", false, -1)
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(0.4).timeout
	await _shot("phone_home")
	GameState.data.pending_stamp = 10
	main.push(MissionScreen.new(true))
	await get_tree().create_timer(1.0).timeout
	await _shot("phone_mission")
	main.pop_to_root()
	GameState.data.workout_days = {GameState.today(): true}
	GameState.log_reps(64)
	GameState.log_item("오늘의 땀범벅 3:12")
	GameState.log_item("1RM 데드리프트 60kg 성공", true)
	main.push(CalendarScreen.new())
	await get_tree().create_timer(0.3).timeout
	await _shot("phone_calendar")
	main.pop_to_root()
	# 상점: 코인을 주고 몇 개 사서 입혀 본다
	GameState.data.coins = 1000
	for id in ["cap_navy", "shades", "shoe_gold", "logo_star", "belt", "wall_pink", "poster_cat", "bear", "mat_purple"]:
		print("buy ", id, " '", GameState.buy(id), "'")
	print("style=", GameState.style(), " room=", GameState.room(), " coins=", GameState.coins())
	var sh = ShopScreen.new()
	main.push(sh)
	await get_tree().create_timer(0.3).timeout
	sh.cursor = 4
	await get_tree().create_timer(0.2).timeout
	await _shot("phone_shop_wear")
	sh.on_dir(Vector2i(1, 0))
	sh.cursor = 6
	await get_tree().create_timer(0.2).timeout
	await _shot("phone_shop_room")
	main.pop_to_root()
	await get_tree().create_timer(0.3).timeout
	await _shot("phone_home_decorated")
	# 배경음악
	Sfx.bgm("home")
	await get_tree().create_timer(0.2).timeout
	print("bgm playing=", Sfx._bgm_player.playing, " len=", snappedf(Sfx._bgm_player.stream.get_length(), 0.1), "s name=", Sfx._bgm_name)
	# 커진 미니게임
	for k in ["power", "rope", "cadence", "combo", "beat"]:
		GameState.mark_tutorial(k)
	for mv in ["thruster", "su", "pullup"]:
		var wp = WodPlay.new({"name": "점검", "rounds": 1, "moves": [{"id": mv, "reps": 5}]})
		main.push(wp)
		await get_tree().create_timer(1.6).timeout
		await _shot("phone_wod_" + mv)
		main.pop_to_root()
	print("bgm after wod=", Sfx._bgm_name)
	var lg = LiftGame.new("deadlift", 40.0)
	main.push(lg)
	await get_tree().create_timer(2.8).timeout
	for i in 6:
		lg._press("a")
	await get_tree().create_timer(0.1).timeout
	await _shot("phone_lift")
	main.pop_to_root()
	# 은퇴식 → 명예의 전당 → 다음 세대
	GameState.data.stage = 4
	GameState.data.form = "gm_legend"
	main.push(RetireScreen.new())
	await get_tree().create_timer(0.5).timeout
	await _shot("phone_retire")
	main._press("b", true, -1); main._press("b", false, -1)
	await get_tree().create_timer(1.8).timeout
	await _shot("phone_after_retire")
	print("hall=", Hall.members().size(), " bonus=", Hall.xp_bonus(), " legacy=", Hall.load_all().legacy.keys())
	for i in 3:
		main._press("a", true, -1); main._press("a", false, -1)
		await get_tree().create_timer(0.1).timeout
	main.top().rows[0].value = "후배"
	main.top()._register()
	GameState.mark_tutorial("home")
	GameState.mark_tutorial("call")
	GameState.data.erase("pending_stamp")
	print("new char coins=", GameState.coins(), " owned=", GameState.data.get("owned", {}).keys())
	for i in 3:
		main._press("a", true, -1); main._press("a", false, -1)
		await get_tree().create_timer(0.15).timeout
	await get_tree().create_timer(0.3).timeout
	await _shot("phone_home_coach")
	main.push(HallScreen.new())
	await get_tree().create_timer(0.2).timeout
	await _shot("phone_hall")
	main.pop_to_root()
	main.push(Menus.settings_menu(main))
	await get_tree().create_timer(0.3).timeout
	await _shot("phone_settings")
	main.pop_to_root()
	main.push(SaveCodeScreen.new(true))
	await get_tree().create_timer(0.3).timeout
	await _shot("phone_savecode")
	get_tree().quit()


func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	print(name, " ", img.get_size())
	img.save_png(ProjectSettings.globalize_path("user://shots/%s.png" % name))
