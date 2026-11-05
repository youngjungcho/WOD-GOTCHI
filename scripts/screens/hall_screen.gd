class_name HallScreen
extends Screen
## 명예의 전당: 은퇴한 선배들. 아무 버튼이나 누르면 닫힌다.

var _list: Array = []


func _ready() -> void:
	_list = Hall.members()


func button_labels() -> Dictionary:
	return {"a": "닫기", "b": "닫기", "menu": "뒤로"}


func on_button(_btn: String, down: bool) -> void:
	if down:
		Sfx.play("back")
		main.pop()


func on_tap(_pos: Vector2) -> void:
	on_button("b", true)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("3b3566"))
	Pal.text(self, Vector2(8, 5), "명예의 전당  %d명" % _list.size(), Pal.YELLOW)
	var bonus := Hall.xp_bonus()
	Pal.text(self, Vector2(8, 18), "지금 성장 보너스 +%d%%" % int(bonus * 100), Pal.WHITE)
	if _list.is_empty():
		Pal.text_wrap(self, Vector2(10, 50), "아직 아무도 없어요.\n게임즈 선수가 되면 메뉴에서 은퇴식을 열 수 있어요.", size.x - 20, Pal.WHITE)
		return
	# 최근 은퇴한 순서로 위에서부터
	var y := 34.0
	for i in range(_list.size() - 1, -1, -1):
		if y > size.y - 40:
			break
		var m: Dictionary = _list[i]
		var r := Rect2(4, y, size.x - 8, 38)
		Pal.window(self, r)
		Pal.athlete(self, r.position + Vector2(2, 3), m.look, "idle", 1, 1.0, 0.0, Forms.style_of(m.form), 33)
		Pal.text(self, r.position + Vector2(38, 4), "%d대 %s" % [int(m.get("gen", i + 1)), m.name], Pal.INK)
		Pal.text(self, r.position + Vector2(38, 15), String(m.title), Pal.BLUE)
		var pr: Dictionary = m.get("pr", {})
		Pal.text(self, r.position + Vector2(38, 26), "%d일 · DL %s · %s" % [int(m.days), Pal.num(float(pr.get("deadlift", 0))), m.date], Pal.DARK)
		y += 40
