class_name LiftSetupScreen
extends FormScreen
## 1RM 도전 종목과 무게를 고른다. 오늘 컨디션 기준 난이도를 미리 보여준다.

const ORDER := ["deadlift", "squat", "clean", "snatch"]


func _init() -> void:
	var names := []
	for l in ORDER:
		names.append(GameState.LIFTS[l] if GameState.lift_unlocked(l) else GameState.LIFTS[l] + "(잠김)")
	super("1RM 챌린지", [
		{"label": "종목", "type": "choice", "value": 0, "options": names, "on_change": _suggest},
		{"label": "도전 무게", "type": "number", "value": 20.0, "min": 20.0, "max": 400.0, "step": 2.5, "fmt": "%skg"},
		{"label": "도전!", "type": "button", "cb": _start},
	])
	top_y = 92.0
	_suggest()


func _lift() -> String:
	return ORDER[int(value(0))]


## 종목을 바꾸면 PR+5kg(없으면 역량의 80%)으로 무게를 맞춘다.
func _suggest() -> void:
	var l := _lift()
	var pr := GameState.pr(l)
	rows[1].value = pr + 5.0 if pr > 0 else maxf(20.0, snappedf(GameState.lift_capacity(l) * 0.8, 2.5))


func _start() -> void:
	var l := _lift()
	if not GameState.lift_unlocked(l):
		Sfx.play("miss")
		main.show_toast(GameState.lift_req_text(l))
		return
	if GameState.attempts_left(l) <= 0:
		Sfx.play("miss")
		main.show_toast("%s은(는) 오늘 시기를 다 썼어요." % GameState.LIFTS[l])
		return
	main.pop_to_root()
	main.push(LiftGame.new(l, float(value(1))))


func _draw_header() -> void:
	var r := Rect2(2, 2, size.x - 4, 86)
	Pal.window(self, r)
	var l := _lift()
	if not GameState.lift_unlocked(l):
		Pal.text(self, r.position + Vector2(8, 6), GameState.LIFTS[l], Pal.INK)
		Pal.text(self, r.position + Vector2(8, 22), GameState.lift_req_text(l), Pal.RED)
		return
	var pr := GameState.pr(l)
	var real := float(GameState.data.real.prs.get(l, 0))
	var ratio := float(value(1)) / GameState.lift_capacity(l)
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
	Pal.text(self, r.position + Vector2(8, 5), "게임 PR: %s" % (Pal.num(pr) + "kg" if pr > 0 else "없음"))
	Pal.text(self, r.position + Vector2(8, 18), "내 실제 PR: %s" % (Pal.num(real) + "kg" if real > 0 else "-"), Pal.GREEN)
	Pal.text(self, r.position + Vector2(8, 31), "오늘 남은 시기: %d번" % GameState.attempts_left(l))
	Pal.text(self, r.position + Vector2(8, 44), "예상 난이도:", Pal.INK)
	Pal.text(self, r.position + Vector2(78, 44), diff, col)
	var how: String = {"deadlift": "연타", "squat": "깊이 → 연타", "clean": "연타 → 받기 → 연타", "snatch": "연타 → 받기 → 균형"}[l]
	Pal.text(self, r.position + Vector2(8, 60), how, Pal.DARK)
