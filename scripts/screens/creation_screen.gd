class_name CreationScreen
extends FormScreen
## 회원 등록 카드: 이름과 외형을 정해서 캐릭터를 만든다.


func _init() -> void:
	super("회원 등록 카드", [
		{"label": "이름", "type": "text", "value": "초보", "max_len": 6},
		{"label": "피부", "type": "choice", "value": 0, "options": Pal.SKIN_NAMES},
		{"label": "헤어", "type": "choice", "value": 0, "options": Pal.HAIR_NAMES},
		{"label": "헤어 색", "type": "choice", "value": 0, "options": Pal.HAIR_COLOR_NAMES},
		{"label": "운동복", "type": "choice", "value": 0, "options": Pal.OUTFIT_NAMES},
		{"label": "등록하기", "type": "button", "cb": _register},
	])
	top_y = 108.0


func _back_rect() -> Rect2:
	return Rect2(-100, -100, 0, 0)


func _back() -> void:
	pass


func button_labels() -> Dictionary:
	return {"a": "다음줄", "b": "바꾸기", "menu": "-"}


func _look() -> Dictionary:
	return {"skin": value(1), "hair": value(2), "hair_color": value(3), "outfit": value(4)}


func _register() -> void:
	var n := str(value(0)).strip_edges()
	if n == "":
		main.show_toast("이름을 입력해 주세요.")
		return
	GameState.new_character(n, _look())
	Sfx.play("levelup")
	main.goto(HomeScreen.new())
	main.say("%s, 박스에 온 걸 환영해요!\n매일 밥 주고, 운동시키고, 재워주세요. 메뉴 버튼을 눌러보세요." % n)


func _draw_header() -> void:
	Pal.box_scene(self, Rect2(0, 0, size.x, 106), t)
	Pal.athlete(self, Vector2(size.x * 0.5 - 32, 6), _look(), "idle", 2, t)
	Pal.window(self, Rect2(4, 4, 62, 18))
	Pal.text(self, Vector2(10, 7), "NEW 회원!", Pal.RED)
