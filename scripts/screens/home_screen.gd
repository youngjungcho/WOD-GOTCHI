class_name HomeScreen
extends Screen
## 메인 화면: 캐릭터를 돌보는 곳. A=칭찬, B=상태, 메뉴=행동 메뉴.
## 호출 중일 때는 A=들어주기, B=단호하게.

const SCENE := Rect2(0, 30, 180, 136)

var _x := 90.0
var _target_x := 90.0
var _wander := 0.0
var _happy_until := 0.0


func _ready() -> void:
	GameState.changed.connect(queue_redraw)


func _process(delta: float) -> void:
	super(delta)
	var d: Dictionary = GameState.data
	if d.is_empty():
		return
	_wander -= delta
	if _wander <= 0.0:
		_wander = randf_range(2.0, 5.0)
		_target_x = randf_range(50.0, 130.0)
	if not d.sleeping and _pose() == "idle":
		_x = move_toward(_x, _target_x, delta * 12.0)
	_check_evolution()


## 진화가 대기 중이면 (다른 화면이 없을 때) 진화 연출을 띄운다.
func _check_evolution() -> void:
	var evo: Dictionary = GameState.data.get("pending_evo", {})
	if evo.is_empty() or main.top() != self:
		return
	main.push(EvolutionScreen.new(evo.from, evo.to))


func _pose() -> String:
	var d: Dictionary = GameState.data
	if d.sleeping:
		return "sleep"
	if t < _happy_until:
		return "happy"
	if GameState.is_injured() or GameState.gauge("energy") < 25.0:
		return "tired"
	if GameState.gauge("mood") < 25.0:
		return "refuse"
	return "idle"


func _mood_line() -> String:
	var d: Dictionary = GameState.data
	if GameState.call_active():
		return "! " + GameState.call_text()
	if d.sleeping:
		return "쿨쿨... (에너지 회복 중)"
	if GameState.is_injured():
		return "아야... 부상 회복 중이에요."
	if GameState.gauge("food") < 25.0:
		return "배고파요... 밥 주세요!"
	if GameState.gauge("energy") < 25.0:
		return "너무 피곤해요. 재워주세요."
	if GameState.gauge("cond") < 25.0:
		return "몸이 뻐근해요. 스트레칭 할래요."
	if int(d.mess) >= 2:
		return "땀이랑 초크가 엉망이에요..."
	if GameState.gauge("mood") < 25.0:
		return "운동하기 싫어요... 칭찬해 줘요."
	if GameState.sessions_today() >= GameState.SESSIONS_FULL:
		return "오늘 운동은 충분해요. 푹 쉬고 내일 봐요!"
	if GameState.attempts_left() == GameState.attempts_max() and GameState.stage() >= 1:
		return "오늘 1RM 도전해 볼까요?"
	return "오늘도 WOD 하러 가볼까요!"


func on_resume() -> void:
	queue_redraw()


func on_button(btn: String, down: bool) -> void:
	if not down:
		return
	if GameState.call_active() and btn != "menu":
		_answer_call(btn == "a")
		return
	match btn:
		"a":
			var msg := GameState.praise()
			if not GameState.data.sleeping:
				_happy_until = t + 1.5
			Sfx.play("good")
			main.show_toast(msg)
		"b":
			main.push(StatsScreen.new())
		"menu":
			main.push(Menus.main_menu(main))


func _answer_call(give: bool) -> void:
	if not give:
		Sfx.play("back")
		main.say(GameState.scold())
		return
	var res := GameState.give_in()
	if res == "food_menu":
		main.push(Menus.food_menu(main))
		return
	_happy_until = t + 1.5
	Sfx.play("good")
	main.say(res)


func on_tap(pos: Vector2) -> void:
	# 캐릭터를 직접 쓰다듬어도 칭찬
	var char_rect := Rect2(_x - 30, SCENE.position.y + 30, 60, 96)
	if char_rect.has_point(pos):
		on_button("a", true)


func _draw() -> void:
	var d: Dictionary = GameState.data
	if d.is_empty():
		return
	# 상단 상태 바
	draw_rect(Rect2(0, 0, size.x, SCENE.position.y), Pal.WHITE)
	draw_rect(Rect2(0, SCENE.position.y - 1, size.x, 1), Pal.INK)
	Pal.text(self, Vector2(4, 2), d.name, Pal.INK)
	var ttl := GameState.title()
	Pal.text(self, Vector2(size.x - 4 - Pal.text_width(ttl), 2), ttl, Pal.BLUE)
	var keys := ["food", "energy", "mood", "cond"]
	var icons := {"food": "food", "energy": "energy", "mood": "heart", "cond": "cond"}
	for i in 4:
		var k: String = keys[i]
		var x := 3 + i * 44
		var v := GameState.gauge(k)
		Pal.icon(self, Vector2(x, 16), icons[k])
		Pal.bar(self, Rect2(x + 9, 17, 32, 6), v / 100.0, Pal.gauge_color(v))

	# 배경
	Pal.box_scene(self, SCENE, t)
	var floor_y := SCENE.position.y + SCENE.size.y * 0.68
	# 땀/초크 자국
	for i in int(d.mess):
		var mx := 20.0 + i * 52.0
		draw_rect(Rect2(mx, floor_y + 18 + (i % 2) * 8, 8, 3), Pal.WHITE)
		draw_rect(Rect2(mx + 2, floor_y + 16 + (i % 2) * 8, 4, 2), Pal.WHITE)
	# 캐릭터
	var pose := _pose()
	var cx := 90.0 if pose == "sleep" else _x
	# 홈에서는 2배로 크게 (칸 하나 = 2px)
	var cy := floor_y - 88
	# 바닥 그림자
	if pose != "sleep":
		Pal.round_rect(self, Rect2(cx - 18, floor_y + 4, 36, 4), Color(Pal.INK, 0.12))
	var st := GameState.style()
	if GameState.is_injured() and pose != "sleep":
		st = st.duplicate()
		st.bandage = true
	Pal.athlete(self, Vector2(cx - 32, cy), d.look, pose, 2, t, 0.0, st)
	# 머리 위 감정 말풍선
	var bp := Vector2(cx + 22, cy - 6 + (int(t * 2) % 2))
	if GameState.call_active():
		if int(t * 3) % 2 == 0:
			Pal.bubble(self, bp, "alert")
	elif pose == "happy":
		Pal.bubble(self, bp, "heart")
	elif pose == "tired":
		Pal.bubble(self, bp, "sweat")
	elif pose == "refuse":
		Pal.bubble(self, bp, "anger")
	# 밤(자는 중) 효과
	if d.sleeping:
		draw_rect(SCENE, Color(Color("202048"), 0.45))
		var zt := fmod(t, 2.0)
		Pal.text(self, Vector2(cx + 8 + zt * 6, floor_y - 30 - zt * 10), "Z", Pal.WHITE)
		Pal.text(self, Vector2(cx + 18 + zt * 4, floor_y - 44 - zt * 8), "z", Pal.WHITE)

	# 대화창
	var r := Rect2(2, SCENE.end.y + 2, size.x - 4, size.y - SCENE.end.y - 4)
	Pal.window(self, r)
	Pal.text_wrap(self, r.position + Vector2(8, 6), _mood_line(), r.size.x - 16, Pal.INK, 10, 2)
	var help := "A 들어주기  B 단호하게" if GameState.call_active() else "A 칭찬  B 상태  메뉴 행동"
	Pal.text(self, Vector2(r.position.x + 8, r.end.y - 16), help, Pal.RED if GameState.call_active() else Pal.DARK)
