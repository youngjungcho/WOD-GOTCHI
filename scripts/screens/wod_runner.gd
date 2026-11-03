class_name WodRunner
extends Screen
## 내가 짠 WOD를 라운드×동작 순서대로 실행하고 시간을 잰다.

var wod: Dictionary
var _queue: Array = []  # [{id, reps, round}]
var _idx := 0
var _start_ms := 0
var _done: Array = []  # [{id, reps}] 실제로 한 횟수
var _scaled: Array = []
var _quit := false


func _init(p_wod: Dictionary) -> void:
	super()
	wod = p_wod
	for r in int(wod.rounds):
		for m in wod.moves:
			var id := Moves.scaled(m.id)
			if id != m.id and not _scaled.has(m.id):
				_scaled.append(m.id)
			_queue.append({"id": id, "reps": int(m.reps), "round": r + 1})


func _ready() -> void:
	var lines := ["%s 시작! %d라운드" % [wod.name, int(wod.rounds)]]
	for s in _scaled:
		lines.append("%s → %s 로 스케일!" % [Moves.name_of(s), Moves.name_of(Moves.scaled(s))])
	main.say.call_deferred("\n".join(lines), func():
		_start_ms = Time.get_ticks_msec()
		_next())


func _next() -> void:
	if _quit or _idx >= _queue.size():
		_finish()
		return
	var q: Dictionary = _queue[_idx]
	if Moves.is_rhythm(q.id):
		main.push(RhythmGame.new(q.id, q.reps, _segment_done))
	else:
		main.push(MashGame.new(q.id, q.reps, _segment_done))


func _segment_done(done: int) -> void:
	var q: Dictionary = _queue[_idx]
	if done < 0:
		_quit = true
		done = -done - 1
	_done.append({"id": q.id, "reps": done})
	_idx += 1
	_next.call_deferred()


func _finish() -> void:
	var secs := (Time.get_ticks_msec() - _start_ms) / 1000.0
	var total := 0
	for d in _done:
		total += int(d.reps)
	var msgs := ["%s %s!" % [wod.name, "포기" if _quit else "완료"], "기록 %d:%02d  총 %d회" % [int(secs) / 60, int(secs) % 60, total]]
	# 오래 버틴 만큼 엔진 보너스, 끝까지 하면 완주 보너스
	var extra := {"eng": secs / 40.0}
	if not _quit:
		extra["eng"] += 3.0
	msgs.append_array(GameState.train(_done, extra))
	Sfx.play("fail" if _quit else "success")
	main.say("\n".join(msgs), func(): main.pop())


func on_button(_btn: String, _down: bool) -> void:
	pass


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Pal.LIGHT)
	Pal.window(self, Rect2(4, 4, size.x - 8, 120))
	Pal.text(self, Vector2(12, 10), "오늘의 WOD", Pal.RED)
	Pal.text(self, Vector2(12, 24), "%s - %d라운드" % [wod.name, int(wod.rounds)])
	var y := 40
	for m in wod.moves:
		Pal.text(self, Vector2(16, y), "%d%s  %s" % [int(m.reps), Moves.unit_of(m.id), Moves.name_of(m.id)])
		y += 13
