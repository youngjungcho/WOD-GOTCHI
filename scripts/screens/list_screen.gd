class_name ListScreen
extends Screen
## 선택 메뉴. 항목을 바로 터치하거나, A=다음 항목 / B=선택 / 메뉴=뒤로.
## 왼쪽 위 '◀뒤로'를 눌러도 돌아가고, 항목이 많으면 ▲▼로 넘긴다.
## items: [{label, cb: Callable, disabled: bool, hint: String, desc: String}]
## desc가 있으면 커서가 놓인 항목의 설명을 창 아래쪽에 보여준다.

const ROW_H := 18
const HEAD_H := 22

var title: String
var items: Array
var cursor := 0
var _box: Rect2
var _scroll := 0


func _init(p_title: String, p_items: Array) -> void:
	super()
	overlay = true
	title = p_title
	items = p_items


func button_labels() -> Dictionary:
	return {"a": "다음", "b": "선택", "menu": "뒤로"}


func _has_desc() -> bool:
	for it in items:
		if it.has("desc"):
			return true
	return false


func _desc_h() -> int:
	return 40 if _has_desc() else 0


func _visible_rows() -> int:
	return clampi(int((size.y - 12 - HEAD_H - _desc_h() - 6) / ROW_H), 3, 10)


func _layout() -> void:
	var rows := mini(items.size(), _visible_rows())
	var h := HEAD_H + rows * ROW_H + 6 + _desc_h()
	_box = Rect2(6, max(4.0, (size.y - h) * 0.5), size.x - 12, h)


func _back_rect() -> Rect2:
	return Rect2(_box.position + Vector2(4, 3), Vector2(36, 16))


func _row_rect(i: int) -> Rect2:
	return Rect2(_box.position.x + 4, _box.position.y + HEAD_H + i * ROW_H, _box.size.x - 8, ROW_H - 1)


func _move(d: int) -> void:
	if items.is_empty():
		return
	cursor = posmod(cursor + d, items.size())
	_fit_scroll()
	Sfx.play("move")


func _fit_scroll() -> void:
	if cursor < _scroll:
		_scroll = cursor
	elif cursor >= _scroll + _visible_rows():
		_scroll = cursor - _visible_rows() + 1


func _select() -> void:
	if items.is_empty():
		return
	var it: Dictionary = items[cursor]
	if it.get("disabled", false):
		Sfx.play("miss")
		if it.has("hint"):
			main.show_toast(it.hint)
		return
	var cb: Callable = it.cb
	cb.call()


func _back() -> void:
	Sfx.play("back")
	main.pop()


func on_button(btn: String, down: bool) -> void:
	if not down:
		return
	match btn:
		"a":
			_move(1)
		"b":
			_select()
		"menu":
			_back()


func on_dir(d: Vector2i) -> void:
	if d.y != 0:
		_move(d.y)


func on_tap(pos: Vector2) -> void:
	_layout()
	if _back_rect().grow(4).has_point(pos) or not _box.has_point(pos):
		_back()
		return
	# 스크롤 화살표
	var rows := _visible_rows()
	if items.size() > rows:
		if _scroll > 0 and Rect2(_box.end.x - 22, _box.position.y + 2, 20, 18).has_point(pos):
			_scroll = maxi(0, _scroll - rows)
			cursor = _scroll
			Sfx.play("move")
			return
		var down_r := Rect2(_box.end.x - 22, _box.position.y + HEAD_H + rows * ROW_H - 16, 20, 18)
		if down_r.has_point(pos) and _scroll + rows < items.size():
			_scroll = mini(items.size() - rows, _scroll + rows)
			cursor = _scroll
			Sfx.play("move")
			return
	for i in mini(items.size() - _scroll, rows):
		if _row_rect(i).has_point(pos):
			cursor = _scroll + i
			_select()
			return


func _draw() -> void:
	_layout()
	draw_rect(Rect2(Vector2.ZERO, size), Color(Pal.INK, 0.35))
	Pal.window(self, _box)
	# 머리: ◀뒤로 + 제목
	var br := _back_rect()
	Pal.round_rect(self, br, Pal.MID)
	Pal.text(self, br.position + Vector2(3, 2), "◀뒤로", Pal.INK)
	Pal.text(self, Vector2(br.end.x + 6, _box.position.y + 5), title, Pal.DARK)
	draw_rect(Rect2(_box.position.x + 4, _box.position.y + HEAD_H - 2, _box.size.x - 8, 1), Pal.MID)
	var rows := _visible_rows()
	for i in mini(items.size() - _scroll, rows):
		var idx := _scroll + i
		var it: Dictionary = items[idx]
		var r := _row_rect(i)
		var col := Pal.INK if not it.get("disabled", false) else Color(Pal.INK, 0.35)
		if idx == cursor:
			Pal.round_rect(self, r, Color("fdeedd"))
			Pal.cursor(self, r.position + Vector2(3, 5))
		Pal.text(self, r.position + Vector2(12, 4), it.label, col)
	# 스크롤 화살표
	if items.size() > rows:
		if _scroll > 0:
			Pal.text(self, Vector2(_box.end.x - 16, _box.position.y + 5), "▲", Pal.BLUE)
		if _scroll + rows < items.size():
			Pal.text(self, Vector2(_box.end.x - 16, _box.position.y + HEAD_H + rows * ROW_H - 13), "▼", Pal.BLUE)
	if _has_desc() and not items.is_empty():
		var dy := _box.end.y - _desc_h()
		draw_rect(Rect2(_box.position.x + 6, dy - 2, _box.size.x - 12, 1), Pal.MID)
		Pal.text_wrap(self, Vector2(_box.position.x + 8, dy + 1), items[cursor].get("desc", ""), _box.size.x - 16, Pal.BLUE, 10, 3)
