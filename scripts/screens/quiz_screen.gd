class_name QuizScreen
extends Screen
## 크로스핏 퀴즈 3문제. 자는 중이면 '꿈속 퀴즈'. 에너지를 쓰지 않는다.
## A: 다음 보기, B: 고르기 (보기를 직접 터치해도 된다), 메뉴: 그만두기

const COUNT := 3

var _qs: Array
var _i := 0
var _cursor := 0
var _correct := 0
var _answered := -1  # 고른 보기 (답을 보여주는 중이면 0 이상)
var _dream := false


func _init() -> void:
	super()
	_qs = Quiz.pick(COUNT)
	_dream = GameState.data.sleeping


func button_labels() -> Dictionary:
	if _answered >= 0:
		return {"a": "다음", "b": "다음", "menu": "그만"}
	return {"a": "다음보기", "b": "고르기", "menu": "그만"}


func _opt_rect(k: int) -> Rect2:
	return Rect2(8, 118 + k * 30, size.x - 16, 26)


func _choose(k: int) -> void:
	if _answered >= 0:
		_next()
		return
	_answered = k
	if k == int(_qs[_i].answer):
		_correct += 1
		Sfx.play("perfect")
	else:
		Sfx.play("miss")


func _next() -> void:
	_answered = -1
	_cursor = 0
	_i += 1
	if _i >= _qs.size():
		var msg := GameState.quiz_result(_correct, _qs.size())
		main.say(msg, func(): main.pop())


func on_button(btn: String, down: bool) -> void:
	if not down or _i >= _qs.size():
		return
	match btn:
		"a":
			if _answered >= 0:
				_next()
			else:
				_cursor = (_cursor + 1) % _qs[_i].options.size()
				Sfx.play("move")
		"b":
			_choose(_cursor)
		"menu":
			Sfx.play("back")
			main.pop()


func on_dir(d: Vector2i) -> void:
	if d.y != 0 and _answered < 0 and _i < _qs.size():
		_cursor = posmod(_cursor + d.y, _qs[_i].options.size())


func on_tap(pos: Vector2) -> void:
	if _i >= _qs.size():
		return
	if _answered >= 0:
		_next()
		return
	for k in _qs[_i].options.size():
		if _opt_rect(k).has_point(pos):
			_cursor = k
			_choose(k)
			return


func _draw() -> void:
	if _dream:
		# 꿈속: 밤하늘 배경에 별
		draw_rect(Rect2(Vector2.ZERO, size), Color("3b3566"))
		for k in 14:
			var sx := fmod(k * 53.0, size.x)
			var sy := fmod(k * 37.0, 100.0)
			if int(t * 2.0 + k) % 3 != 0:
				draw_rect(Rect2(sx, sy, 1, 1), Pal.YELLOW)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Pal.LIGHT)
	if _i >= _qs.size():
		return
	var title := "꿈속 크로스핏 퀴즈" if _dream else "크로스핏 퀴즈"
	Pal.text(self, Vector2(8, 6), "%s  %d/%d" % [title, _i + 1, _qs.size()], Pal.WHITE if _dream else Pal.INK)
	var qr := Rect2(4, 24, size.x - 8, 86)
	Pal.window(self, qr)
	Pal.athlete(self, qr.position + Vector2(4, 30), GameState.data.look, "happy" if _dream else "idle", 1, t, 0.0, GameState.style(), 30)
	Pal.text_wrap(self, qr.position + Vector2(42, 10), _qs[_i].q, qr.size.x - 50, Pal.INK, 10, 5)
	var opts: Array = _qs[_i].options
	for k in opts.size():
		var r := _opt_rect(k)
		var fill := Pal.WHITE
		if _answered >= 0:
			if k == int(_qs[_i].answer):
				fill = Pal.MINT
			elif k == _answered:
				fill = Pal.PINK
		Pal.window(self, r, fill)
		if k == _cursor and _answered < 0:
			Pal.cursor(self, r.position + Vector2(6, 9))
		Pal.text(self, r.position + Vector2(16, 7), opts[k], Pal.INK)
	if _answered >= 0:
		var ok := _answered == int(_qs[_i].answer)
		Pal.text(self, Vector2(8, 210), "정답!" if ok else "아쉬워요...", Pal.GREEN if ok else Pal.RED)
		Pal.text(self, Vector2(70, 210), "아무 버튼: 다음", Pal.WHITE if _dream else Pal.DARK)
	else:
		Pal.text(self, Vector2(8, 210), "A 다음 보기  B 고르기", Pal.WHITE if _dream else Pal.DARK)
