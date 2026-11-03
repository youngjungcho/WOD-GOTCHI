class_name FormScreen
extends Screen
## 값을 고르는 폼. A=다음 줄, B=값 바꾸기/실행, 메뉴=뒤로.
## 값 영역의 왼쪽/오른쪽을 터치하면 감소/증가.
## rows: {label, type: "choice"|"number"|"text"|"button"|"pick", value, options, min, max, step, fmt, cb}
## pick: 값 표시는 show(value) 콜백, 누르면 cb 호출(보통 고르기 메뉴를 연다)

const ROW_H := 15

var title: String
var rows: Array
var cursor := 0
var top_y := 4.0  # 하위 클래스가 위쪽에 그림을 그릴 때 늘린다
var _edits := {}  # row index -> LineEdit


func _init(p_title: String, p_rows: Array) -> void:
	super()
	title = p_title
	rows = p_rows


func _ready() -> void:
	for i in rows.size():
		if rows[i].type == "text":
			var le := LineEdit.new()
			le.text = str(rows[i].value)
			le.max_length = int(rows[i].get("max_len", 8))
			le.add_theme_font_size_override("font_size", 10)
			le.add_theme_color_override("font_color", Pal.INK)
			le.add_theme_color_override("caret_color", Pal.INK)
			# 입력칸 테두리는 _draw에서 직접 그리고, LineEdit는 글자/입력만 담당한다
			var sb := StyleBoxEmpty.new()
			sb.content_margin_left = 3
			le.add_theme_stylebox_override("normal", sb)
			le.add_theme_stylebox_override("focus", sb)
			le.text_changed.connect(func(v): rows[i].value = v)
			le.text_submitted.connect(func(_v): le.release_focus())
			add_child(le)
			_edits[i] = le


func value(i: int) -> Variant:
	return rows[i].value


func _row_rect(i: int) -> Rect2:
	return Rect2(6, top_y + 20 + i * ROW_H, size.x - 12, ROW_H)


func _value_rect(i: int) -> Rect2:
	var r := _row_rect(i)
	return Rect2(r.position.x + 74, r.position.y, r.size.x - 78, r.size.y)


func _change(i: int, d: int) -> void:
	var row: Dictionary = rows[i]
	match row.type:
		"choice":
			row.value = posmod(int(row.value) + d, row.options.size())
		"number":
			var v: float = float(row.value) + d * float(row.get("step", 1))
			if v > float(row.max):
				v = float(row.min)
			elif v < float(row.min):
				v = float(row.max)
			row.value = v
		"button", "pick":
			row.cb.call()
			return
		"text":
			_edits[i].grab_focus()
			return
	Sfx.play("move")
	if row.has("on_change"):
		row.on_change.call()


func on_button(btn: String, down: bool) -> void:
	if not down:
		return
	match btn:
		"a":
			cursor = (cursor + 1) % rows.size()
			Sfx.play("move")
		"b":
			_change(cursor, 1)
		"menu":
			_back()


func _back() -> void:
	Sfx.play("back")
	main.pop()


func on_dir(d: Vector2i) -> void:
	if d.y != 0:
		cursor = posmod(cursor + d.y, rows.size())
		Sfx.play("move")
	elif rows[cursor].type in ["choice", "number"]:
		_change(cursor, d.x)


func on_tap(pos: Vector2) -> void:
	for i in rows.size():
		if _row_rect(i).has_point(pos):
			cursor = i
			var row: Dictionary = rows[i]
			if row.type in ["choice", "number"]:
				var vr := _value_rect(i)
				_change(i, -1 if pos.x < vr.position.x + vr.size.x * 0.5 else 1)
			else:
				_change(i, 1)
			return


func _fmt(row: Dictionary) -> String:
	match row.type:
		"choice":
			return str(row.options[int(row.value)])
		"pick":
			return row.show.call(row.value)
		"number":
			var v: float = row.value
			var s := str(int(v)) if is_equal_approx(v, round(v)) else "%.1f" % v
			return row.get("fmt", "%s") % s
	return str(row.get("value", ""))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Pal.LIGHT)
	_draw_header()
	var box := Rect2(2, top_y, size.x - 4, 26 + rows.size() * ROW_H)
	Pal.window(self, box)
	Pal.text(self, box.position + Vector2(8, 5), title, Pal.DARK)
	for i in rows.size():
		var row: Dictionary = rows[i]
		var r := _row_rect(i)
		if i == cursor:
			Pal.cursor(self, r.position + Vector2(2, 4))
		if row.type == "button":
			Pal.text(self, r.position + Vector2(12, 2), "[ %s ]" % row.label, Pal.BLUE if i == cursor else Pal.INK)
			continue
		Pal.text(self, r.position + Vector2(12, 2), row.label)
		var vr := _value_rect(i)
		if row.type == "text":
			var le: LineEdit = _edits.get(i)
			var ib := Rect2(vr.position + Vector2(0, 1), Vector2(vr.size.x, 13))
			draw_rect(ib, Pal.INK)
			draw_rect(ib.grow(-1), Pal.WHITE)
			if le:
				le.size = Vector2(vr.size.x, 0)
				le.position = Vector2(ib.position.x, ib.get_center().y - le.size.y * 0.5)
			continue
		if row.type == "pick":
			Pal.text(self, vr.position + Vector2(0, 2), _fmt(row), Pal.BLUE)
			continue
		Pal.text(self, vr.position + Vector2(0, 2), "◀", Pal.DARK)
		Pal.text_center(self, Rect2(vr.position.x + 8, vr.position.y + 1, vr.size.x - 16, 13), _fmt(row))
		Pal.text(self, Vector2(vr.end.x - 8, vr.position.y + 2), "▶", Pal.DARK)
	var hy := box.end.y + 4
	if hy < size.y - 14:
		Pal.text(self, Vector2(6, hy), "A 다음줄  B 바꾸기  메뉴 뒤로", Pal.DARK)


## 하위 클래스용. 폼 위쪽에 그림을 그린다.
func _draw_header() -> void:
	pass
