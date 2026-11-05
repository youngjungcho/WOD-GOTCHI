class_name MissionScreen
extends Screen
## 출석 도장 카드 + 오늘의 미션 3개 + 코인.
## stamp=true면 오늘 도장을 '쾅' 찍는 연출로 연다. 아무 버튼이나 누르면 닫힌다.

var _stamp := false
var _reward := 0


func _init(stamp: bool = false) -> void:
	super()
	_stamp = stamp
	if stamp:
		_reward = int(GameState.data.get("pending_stamp", 0))
		GameState.data.erase("pending_stamp")
		GameState.save_game()


func _ready() -> void:
	if _stamp:
		get_tree().create_timer(0.5).timeout.connect(func(): Sfx.play("levelup"); Sfx.buzz(60))


func button_labels() -> Dictionary:
	return {"a": "닫기", "b": "닫기", "menu": "뒤로"}


func on_button(_btn: String, down: bool) -> void:
	if down:
		_close()


func on_tap(_pos: Vector2) -> void:
	_close()


func _close() -> void:
	if _stamp and t < 0.8:
		return
	Sfx.play("back")
	main.pop()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Pal.LIGHT)
	var d: Dictionary = GameState.data
	var att: Dictionary = d.get("attend", {"streak": 1, "best": 1})
	var streak := int(att.get("streak", 1))
	# 머리: 코인
	Pal.text(self, Vector2(8, 5), "오늘의 미션", Pal.INK)
	var coin_text := "%d코인" % GameState.coins()
	Pal.icon(self, Vector2(size.x - 14 - Pal.text_width(coin_text), 6), "coin")
	Pal.text(self, Vector2(size.x - 6 - Pal.text_width(coin_text), 5), coin_text, Pal.DARK)

	# 출석 도장 카드 (7칸)
	var card := Rect2(4, 20, size.x - 8, 66)
	Pal.window(self, card)
	Pal.text(self, card.position + Vector2(8, 5), "출석 도장  연속 %d일 (최고 %d일)" % [streak, int(att.get("best", streak))], Pal.INK)
	var filled := (streak - 1) % 7 + 1  # 이번 카드에서 찍힌 칸 수
	for i in 7:
		var c := Vector2(card.position.x + 16 + i * 23, card.position.y + 36)
		draw_circle(c, 10, Pal.INK)
		draw_circle(c, 9, Pal.WHITE if i >= filled else Pal.PINK)
		var today_slot := i == filled - 1
		if i < filled:
			# 도장: 오늘 칸은 커졌다 작아지며 찍힌다
			var s := 1.0
			if _stamp and today_slot:
				s = clampf(2.2 - t * 2.4, 1.0, 2.2)
			draw_circle(c, 7.0 * s, Pal.RED)
			draw_circle(c, 5.5 * s, Pal.PINK)
			Pal.icon(self, c - Vector2(3, 3), "heart")
		var lbl := "선물" if i == 6 else "%d일" % (i + 1)
		Pal.text_center(self, Rect2(c.x - 14, c.y + 11, 28, 11), lbl, Pal.RED if i == 6 else Pal.DARK)

	# 미션 3개
	var ms: Dictionary = d.get("missions", {"list": []})
	var y := 92.0
	for m in ms.list:
		var info: Array = GameState.MISSIONS[m.id]
		var target: int = info[1]
		var r := Rect2(4, y, size.x - 8, 30)
		Pal.window(self, r, Pal.MINT.lightened(0.5) if m.done else Pal.WHITE)
		Pal.text(self, r.position + Vector2(8, 4), info[0], Pal.INK)
		Pal.text(self, Vector2(r.end.x - 40, r.position.y + 4), "+%d" % GameState.MISSION_REWARD, Pal.DARK)
		Pal.icon(self, Vector2(r.end.x - 16, r.position.y + 5), "coin")
		Pal.bar(self, Rect2(r.position.x + 8, r.position.y + 18, r.size.x - 64, 6), float(m.progress) / target, Pal.GREEN if m.done else Pal.BLUE)
		Pal.text(self, Vector2(r.end.x - 46, r.position.y + 15), "완료!" if m.done else "%d/%d" % [int(m.progress), target], Pal.GREEN if m.done else Pal.INK)
		y += 33
	# 올클리어 보너스
	var b := Rect2(4, y, size.x - 8, 22)
	Pal.window(self, b, Pal.YELLOW.lightened(0.6) if ms.get("bonus", false) else Pal.WHITE)
	var btxt := "올클리어 보너스 받음!" if ms.get("bonus", false) else "3개 모두: +%d코인, 멘탈 +3" % GameState.MISSION_BONUS
	Pal.text(self, b.position + Vector2(8, 5), btxt, Pal.INK)

	if _stamp and _reward > 0 and t > 0.5:
		var pr := Rect2(14, b.end.y + 4, size.x - 28, 22)
		Pal.window(self, pr, Pal.YELLOW.lightened(0.5))
		Pal.text_center(self, pr, "출석 %d일째! +%d코인" % [streak, _reward], Pal.RED)
