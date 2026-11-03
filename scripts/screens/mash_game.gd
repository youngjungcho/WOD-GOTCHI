class_name MashGame
extends Screen
## 연타 동작. 정해진 횟수만큼 A/B를 연타해서 동작을 끝낸다.
## on_done이 없으면 단독 운동으로 보고 결과를 직접 반영한다.

var move_id: String
var reps: int
var on_done: Callable
var _taps := 0
var _done := 0
var _need: int
var _bounce := 0.0


func _init(p_move: String, p_reps: int, p_on_done: Callable = Callable()) -> void:
	super()
	move_id = p_move
	reps = p_reps
	on_done = p_on_done
	_need = int(Moves.LIST[move_id].taps)


func _process(delta: float) -> void:
	super(delta)
	_bounce = max(0.0, _bounce - delta * 4.0)


func _tap() -> void:
	_taps += 1
	Sfx.play("tap")
	if _taps >= _need:
		_taps = 0
		_done += 1
		_bounce = 1.0
		Sfx.play("good")
		if _done >= reps:
			_finish(_done)


func _finish(result: int) -> void:
	if on_done.is_valid():
		var cb := on_done
		main.pop()
		cb.call(result)
		return
	var n := result if result >= 0 else -result - 1
	var msgs: Array = ["%s %d%s %s!" % [Moves.name_of(move_id), n, Moves.unit_of(move_id), "완료" if result >= 0 else "에서 멈춤"]]
	msgs.append_array(GameState.train([{"id": move_id, "reps": n}]))
	Sfx.play("success" if result >= 0 else "fail")
	main.say("\n".join(msgs), func(): main.pop())


func on_button(btn: String, down: bool) -> void:
	if not down:
		return
	if btn == "menu":
		_finish(-_done - 1)  # 음수 = 중단
		return
	_tap()


func on_tap(_p: Vector2) -> void:
	_tap()


func _draw() -> void:
	var scene := Rect2(0, 0, size.x, 170)
	Pal.box_scene(self, scene, t)
	var floor_y := scene.size.y * 0.68
	var look: Dictionary = GameState.data.look
	var o := Vector2(74, floor_y - 44)
	var cat: String = Moves.LIST[move_id].cat
	if cat == "barbell" or cat == "kb":
		var p := 1.0 - _bounce if _bounce > 0 else float(_taps) / _need
		Pal.athlete(self, o, look, "lift", 2, t, p, GameState.is_muscular())
		var hand := Vector2(90, o.y + lerpf(20.0, 15.0, p) * 2 + 1)
		if cat == "barbell":
			Pal.barbell(self, hand, 30, 2)
		else:
			draw_rect(Rect2(hand - Vector2(5, 0), Vector2(10, 9)), Pal.INK)
			draw_rect(Rect2(hand - Vector2(4, -1), Vector2(8, 7)), Pal.PANTS)
	else:
		var pose := "happy" if _bounce > 0.5 else ("tired" if _taps > 0 else "idle")
		Pal.athlete(self, o - Vector2(0, _bounce * 10.0), look, pose, 2, t)
	var r := Rect2(2, 172, size.x - 4, size.y - 174)
	Pal.window(self, r)
	Pal.text(self, r.position + Vector2(8, 5), Moves.name_of(move_id), Pal.INK)
	Pal.text(self, r.position + Vector2(8, 19), "%d / %d %s" % [_done, reps, Moves.unit_of(move_id)], Pal.BLUE)
	Pal.bar(self, Rect2(r.position.x + 8, r.position.y + 34, r.size.x - 16, 7), float(_taps) / _need, Pal.GREEN)
	Pal.text(self, r.position + Vector2(8, 46), "A·B 연타!  메뉴: 포기", Pal.DARK)
