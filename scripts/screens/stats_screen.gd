class_name StatsScreen
extends Screen
## 화이트보드: 능력치, 게이지, 기록을 보여준다. 아무 버튼이나 누르면 닫힌다.


func on_button(_btn: String, down: bool) -> void:
	if down:
		Sfx.play("back")
		main.pop()


func on_tap(_pos: Vector2) -> void:
	on_button("b", true)


func _draw() -> void:
	var d: Dictionary = GameState.data
	draw_rect(Rect2(Vector2.ZERO, size), Pal.DARK)
	var r := Rect2(4, 4, size.x - 8, size.y - 8)
	draw_rect(r, Pal.INK)
	draw_rect(r.grow(-1), Pal.WHITE)
	var x := r.position.x + 6
	var y := r.position.y + 4
	Pal.text(self, Vector2(x, y), "%s  %d일째" % [d.name, GameState.days_alive() + 1], Pal.INK)
	y += 12
	Pal.text(self, Vector2(x, y), GameState.title(), Pal.BLUE)
	y += 12
	Pal.text(self, Vector2(x, y), GameState.next_stage_hint(), Pal.DARK)
	y += 15
	for s in GameState.STATS:
		var lv := GameState.level(s)
		var xp := float(d.xp[s])
		var a := GameState.xp_for_level(lv)
		var b := GameState.xp_for_level(lv + 1)
		Pal.text(self, Vector2(x, y), "%s Lv.%d" % [GameState.STAT_NAMES[s], lv], Pal.INK)
		Pal.bar(self, Rect2(x + 62, y + 2, r.size.x - 74, 7), (xp - a) / (b - a), Pal.BLUE)
		y += 12
	y += 4
	draw_rect(Rect2(x, y, r.size.x - 12, 1), Pal.MID)
	y += 4
	for k in ["food", "energy", "mood", "cond"]:
		var v := GameState.gauge(k)
		Pal.text(self, Vector2(x, y), GameState.GAUGE_NAMES[k], Pal.INK)
		Pal.bar(self, Rect2(x + 62, y + 2, r.size.x - 74, 7), v / 100.0, Pal.gauge_color(v))
		y += 12
	y += 4
	draw_rect(Rect2(x, y, r.size.x - 12, 1), Pal.MID)
	y += 4
	Pal.text(self, Vector2(x, y), "PR 보드", Pal.RED)
	y += 12
	var pr := float(d.pr.get("deadlift", 0))
	Pal.text(self, Vector2(x, y), "데드리프트 1RM  %s" % (Pal.num(pr) + "kg" if pr > 0 else "-"))
	y += 12
	var rb: Dictionary = d.rhythm_best
	Pal.text(self, Vector2(x, y), "풀업 %d  버터 %d  머슬업 %d" % [int(rb.get("pullup", 0)), int(rb.get("butterfly", 0)), int(rb.get("muscleup", 0))])
	y += 14
	Pal.text(self, Vector2(x, y), "실제 기록 (나)", Pal.GREEN)
	y += 12
	var rp: Dictionary = d.real.prs
	Pal.text(self, Vector2(x, y), "DL %s  SQ %s  풀업 %s" % [_kg(rp.deadlift), _kg(rp.squat), _n(rp.pullup)])
	y += 12
	Pal.text(self, Vector2(x, y), "클린 %s  스내치 %s" % [_kg(rp.clean), _kg(rp.snatch)])


static func _kg(v) -> String:
	return "-" if float(v) <= 0 else Pal.num(float(v))


static func _n(v) -> String:
	return "-" if int(v) <= 0 else str(int(v))
