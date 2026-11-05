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
