class_name RetireScreen
extends Screen
## 은퇴식. 시상대 위의 캐릭터, 꽃가루, 커리어 요약.
## B: 은퇴하기 (명예의 전당 → 새 회원), 메뉴: 아직이요

var _confirmed := false


func button_labels() -> Dictionary:
	return {"a": "-", "b": "은퇴하기", "menu": "아직이요"}


func on_button(btn: String, down: bool) -> void:
	if not down or _confirmed:
		return
	match btn:
		"b":
			_retire()
		"menu":
			Sfx.play("back")
			main.pop()


func on_tap(pos: Vector2) -> void:
	if _confirmed:
		return
	if Rect2(10, size.y - 30, 76, 24).has_point(pos):
		_retire()
	elif Rect2(94, size.y - 30, 76, 24).has_point(pos):
		Sfx.play("back")
		main.pop()


func _retire() -> void:
	_confirmed = true
	Sfx.play("levelup")
	Sfx.buzz(100)
	var name: String = GameState.data.name
	get_tree().create_timer(1.2).timeout.connect(func():
		var entry := GameState.retire()
		main.goto(CreationScreen.new())
		main.say("%s 선배가 명예의 전당에 올랐어요!\n이제 박스의 코치로 새 회원을 도와줄 거예요.\n다음 세대 성장 보너스 +%d%%" % [name, int(Hall.xp_bonus() * 100)]))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("3b3566"))
	# 꽃가루
	for k in 40:
		var x := fmod(k * 37.0 + t * (12 + k % 5 * 4), size.x)
		var y := fmod(k * 23.0 + t * (30 + k % 7 * 6), 150.0)
		draw_rect(Rect2(x, y, 2, 2), [Pal.YELLOW, Pal.PINK, Pal.MINT, Pal.BLUE, Pal.RED][k % 5])
	# 시상대
	var pd := Rect2(56, 118, 68, 24)
	Pal.round_rect(self, pd, Pal.INK)
	Pal.round_rect(self, pd.grow(-1), Pal.YELLOW)
	Pal.text_center(self, pd, "1", Pal.INK, 10)
	var d: Dictionary = GameState.data
	Pal.athlete(self, Vector2(58, 26 + (2 if _confirmed and int(t * 8) % 2 == 0 else 0)), d.look, "happy", 2, t, 0.0, GameState.style())
	# 요약
	var r := Rect2(4, 146, size.x - 8, size.y - 182)
	Pal.window(self, r)
	var pr: Dictionary = d.pr
	var lines := [
		"%s · %s" % [d.name, GameState.title()],
		"%d일 동안 · 운동한 날 %d일" % [GameState.days_alive() + 1, GameState.workout_days()],
		"DL %s  SQ %s  클린 %s  스내치 %s" % [Pal.num(float(pr.get("deadlift", 0))), Pal.num(float(pr.get("squat", 0))), Pal.num(float(pr.get("clean", 0))), Pal.num(float(pr.get("snatch", 0)))],
		"다음 회원: 성장 +%d%%, 유산 상속" % int(minf(Hall.BONUS_MAX, (Hall.members().size() + 1) * Hall.BONUS_PER_GEN) * 100),
	]
	for i in lines.size():
		Pal.text(self, r.position + Vector2(8, 5 + i * 12), lines[i], Pal.INK if i < 3 else Pal.DARK)
	if _confirmed:
		Pal.text_center(self, Rect2(0, size.y - 28, size.x, 20), "축하해요! 수고했어요!", Pal.YELLOW)
		return
	for i in 2:
		var b := Rect2(10 + i * 84, size.y - 30, 76, 24)
		Pal.round_rect(self, b, Pal.INK)
		Pal.round_rect(self, b.grow(-1), Pal.PINK if i == 0 else Pal.WHITE)
		Pal.text_center(self, b, "은퇴하기" if i == 0 else "아직이요", Pal.INK)
