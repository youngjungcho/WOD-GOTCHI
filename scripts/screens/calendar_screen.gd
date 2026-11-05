class_name CalendarScreen
extends Screen
## 운동 기록 달력. 운동한 날은 색칠(많이 할수록 진하게), PR한 날은 ★, 오늘은 테두리.
## 날짜를 누르면 그날 한 운동이 아래에 나온다. ◀ ▶로 달을 넘긴다.
## 버튼: B 이전 달, A 다음 달, 메뉴 뒤로

const CELL := Vector2(24, 17)
const GRID_Y := 46.0
const WEEK := ["일", "월", "화", "수", "목", "금", "토"]

var _year: int
var _month: int
var _sel := ""  # 고른 날짜 "YYYY-MM-DD"


func _init() -> void:
	super()
	var d := Time.get_date_dict_from_system()
	_year = d.year
	_month = d.month
	_sel = GameState.today()


func button_labels() -> Dictionary:
	return {"a": "다음달▶", "b": "◀이전달", "menu": "뒤로"}


func _shift(delta: int) -> void:
	_month += delta
	if _month < 1:
		_month = 12
		_year -= 1
	elif _month > 12:
		_month = 1
		_year += 1
	Sfx.play("move")


func on_button(btn: String, down: bool) -> void:
	if not down:
		return
	match btn:
		"a":
			_shift(1)
		"b":
			_shift(-1)
		"menu":
			Sfx.play("back")
			main.pop()


func on_dir(d: Vector2i) -> void:
	if d.x != 0:
		_shift(d.x)


static func _date_str(y: int, m: int, day: int) -> String:
	return "%04d-%02d-%02d" % [y, m, day]


static func _days_in(y: int, m: int) -> int:
	if m == 2:
		return 29 if (y % 4 == 0 and y % 100 != 0) or y % 400 == 0 else 28
	return 30 if m in [4, 6, 9, 11] else 31


## 그 달 1일의 요일 (0=일요일)
static func _first_weekday(y: int, m: int) -> int:
	var unix := Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": 1, "hour": 12})
	return Time.get_date_dict_from_unix_time(unix).weekday


func _cell_rect(day: int) -> Rect2:
	var idx := _first_weekday(_year, _month) + day - 1
	return Rect2(6 + (idx % 7) * CELL.x, GRID_Y + (idx / 7) * CELL.y, CELL.x - 1, CELL.y - 1)


func on_tap(pos: Vector2) -> void:
	if Rect2(4, 3, 36, 16).grow(3).has_point(pos):
		Sfx.play("back")
		main.pop()
		return
	if Rect2(48, 20, 16, 14).grow(4).has_point(pos):
		_shift(-1)
		return
	if Rect2(size.x - 22, 20, 16, 14).grow(4).has_point(pos):
		_shift(1)
		return
	for day in range(1, _days_in(_year, _month) + 1):
		if _cell_rect(day).has_point(pos):
			_sel = _date_str(_year, _month, day)
			Sfx.play("move")
			return


func _worked(date: String) -> bool:
	return (GameState.data.get("workout_days", {}) as Dictionary).has(date) or _log(date).get("sessions", 0) > 0


func _log(date: String) -> Dictionary:
	return (GameState.data.get("log", {}) as Dictionary).get(date, {})


func _has_pr(date: String) -> bool:
	for it in _log(date).get("items", []):
		if it.get("pr", false):
			return true
	return false


## 오늘부터 거꾸로 이어진 연속 운동 일수와, 기록 전체에서 가장 긴 연속 일수.
func _streaks() -> Vector2i:
	var days: Dictionary = GameState.data.get("workout_days", {})
	var dates := []
	for k in days:
		if String(k).length() == 10:
			dates.append(String(k))
	dates.sort()
	var best := 0
	var run := 0
	var prev := 0
	for ds in dates:
		var u := int(Time.get_unix_time_from_datetime_string(ds + "T12:00:00"))
		run = run + 1 if prev > 0 and u - prev == 86400 else 1
		best = maxi(best, run)
		prev = u
	# 현재 연속: 오늘(또는 어제)부터 거꾸로
	var cur := 0
	var u0 := int(GameState.now())
	if not days.has(GameState.today()):
		u0 -= 86400
	while days.has(GameState.local_date(u0)):
		cur += 1
		u0 -= 86400
	return Vector2i(cur, best)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Pal.LIGHT)
	# 머리: 뒤로 / 연월 / 이동
	Pal.round_rect(self, Rect2(4, 3, 36, 16), Pal.MID)
	Pal.text(self, Vector2(7, 5), "◀뒤로", Pal.INK)
	Pal.text(self, Vector2(46, 5), "운동 달력", Pal.DARK)
	Pal.text(self, Vector2(48, 22), "◀", Pal.BLUE)
	Pal.text_center(self, Rect2(60, 21, size.x - 84, 12), "%d년 %d월" % [_year, _month], Pal.INK)
	Pal.text(self, Vector2(size.x - 18, 22), "▶", Pal.BLUE)
	for i in 7:
		Pal.text_center(self, Rect2(6 + i * CELL.x, 34, CELL.x, 11), WEEK[i], Pal.RED if i == 0 else (Pal.BLUE if i == 6 else Pal.DARK))
	# 날짜 칸
	var month_days := 0
	var month_reps := 0
	var today := GameState.today()
	for day in range(1, _days_in(_year, _month) + 1):
		var ds := _date_str(_year, _month, day)
		var r := _cell_rect(day)
		var lg := _log(ds)
		var col := Pal.WHITE
		if _worked(ds):
			month_days += 1
			month_reps += int(lg.get("reps", 0))
			var reps := int(lg.get("reps", 0))
			col = Pal.MINT.lightened(0.3) if reps < 40 else (Pal.MINT if reps < 100 else Pal.GREEN)
		Pal.round_rect(self, r, col)
		if ds == _sel:
			Pal.frame(self, r.grow(1), Pal.BLUE)
		elif ds == today:
			Pal.frame(self, r, Pal.RED)
		Pal.text(self, r.position + Vector2(2, 2), str(day), Pal.INK)
		if _has_pr(ds):
			Pal.icon(self, r.position + Vector2(r.size.x - 8, r.size.y - 8), "heart")
	# 요약
	var st := _streaks()
	var y := GRID_Y + 6 * CELL.y + 2
	Pal.text(self, Vector2(6, y), "이번 달 %d일 · %d회 · 연속 %d일(최고 %d)" % [month_days, month_reps, st.x, st.y], Pal.DARK)
	# 고른 날의 기록
	var box := Rect2(2, y + 14, size.x - 4, size.y - y - 16)
	Pal.window(self, box)
	var lg := _log(_sel)
	var parts := _sel.split("-")
	var title := "%d월 %d일" % [int(parts[1]), int(parts[2])]
	if lg.is_empty():
		Pal.text(self, box.position + Vector2(8, 5), title + (" · 운동함 (상세 기록 없음)" if _worked(_sel) else " · 기록 없음"), Pal.INK)
		return
	Pal.text(self, box.position + Vector2(8, 5), "%s · %d번, %d회" % [title, int(lg.sessions), int(lg.reps)], Pal.INK)
	var items: Array = lg.get("items", [])
	var line_y := box.position.y + 19
	var start := maxi(0, items.size() - int((box.size.y - 22) / 12))
	for i in range(start, items.size()):
		var it: Dictionary = items[i]
		Pal.text(self, Vector2(box.position.x + 8, line_y), ("★ " if it.get("pr", false) else "· ") + String(it.text), Pal.RED if it.get("pr", false) else Pal.INK)
		line_y += 12
