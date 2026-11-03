class_name LiftSetupScreen
extends FormScreen
## 1RM 도전 무게를 고른다. 오늘 컨디션 기준 난이도를 미리 보여준다.


func _init() -> void:
	var pr := float(GameState.data.pr.get("deadlift", 0))
	var cap := GameState.lift_capacity("deadlift")
	var start := pr + 5.0 if pr > 0 else snappedf(cap * 0.8, 5.0)
	super("1RM 챌린지 - 데드리프트", [
		{"label": "도전 무게", "type": "number", "value": start, "min": 20.0, "max": 400.0, "step": 2.5, "fmt": "%skg"},
		{"label": "도전!", "type": "button", "cb": _start},
	])
	top_y = 86.0


func _start() -> void:
	main.pop_to_root()
	main.push(LiftGame.new(float(value(0))))


func _draw_header() -> void:
	var r := Rect2(2, 2, size.x - 4, 80)
	Pal.window(self, r)
	var pr := float(GameState.data.pr.get("deadlift", 0))
	var ratio := float(value(0)) / GameState.lift_capacity("deadlift")
	var diff := "가볍게 성공"
	var col := Pal.GREEN
	if ratio > 1.15:
		diff = "거의 불가능"
		col = Pal.RED
	elif ratio > 1.0:
		diff = "한계 돌파 도전"
		col = Pal.RED
	elif ratio > 0.88:
		diff = "빡센 도전"
		col = Pal.YELLOW.darkened(0.3)
	Pal.text(self, r.position + Vector2(8, 6), "현재 PR: %s" % (Pal.num(pr) + "kg" if pr > 0 else "없음"))
	Pal.text(self, r.position + Vector2(8, 20), "오늘 남은 시기: %d번" % GameState.attempts_left())
	Pal.text(self, r.position + Vector2(8, 34), "예상 난이도:", Pal.INK)
	Pal.text(self, r.position + Vector2(78, 34), diff, col)
	Pal.text_wrap(self, r.position + Vector2(8, 50), "컨디션(힘·몸·기분)이 좋을수록 잘 들어요.", r.size.x - 16, Pal.DARK)
