class_name ListScreen
extends Screen
## RPG 스타일 선택 메뉴. A=다음 항목, B=결정, 메뉴=뒤로. 항목을 바로 터치해도 된다.
## items: [{label, cb: Callable, disabled: bool, hint: String, desc: String}]
## desc가 있으면 커서가 놓인 항목의 설명을 창 아래쪽에 보여준다.

const ROW_H := 15

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


func _visible_rows() -> int:
	return 6 if _has_desc() else 10


func _has_desc() -> bool:
	for it in items:
		if it.has("desc"):
			return true
	return false


func _layout() -> void:
	var rows := mini(items.size(), _visible_rows())
	var h := 22 + rows * ROW_H + 18 + (40 if _has_desc() else 0)
	_box = Rect2(10, max(4, (size.y - h) * 0.5 - 10), size.x - 20, h)


func _move(d: int) -> void:
	if items.is_empty():
		return
	cursor = posmod(cursor + d, items.size())
	if cursor < _scroll:
		_scroll = cursor
	elif cursor >= _scroll + _visible_rows():
		_scroll = cursor - _visible_rows() + 1
	Sfx.play("move")


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


func on_button(btn: String, down: bool) -> void:
	if not down:
		return
	match btn:
		"a":
			_move(1)
		"b":
			_select()
		"menu":
			Sfx.play("back")
			main.pop()


func on_dir(d: Vector2i) -> void:
	if d.y != 0:
		_move(d.y)


func on_tap(pos: Vector2) -> void:
	_layout()
	if not _box.has_point(pos):
		Sfx.play("back")
		main.pop()
		return
	var row := int((pos.y - _box.position.y - 20) / ROW_H)
	var idx := _scroll + row
	if row >= 0 and row < _visible_rows() and idx < items.size():
		cursor = idx
		_select()


func _draw() -> void:
	_layout()
	draw_rect(Rect2(Vector2.ZERO, size), Color(Pal.INK, 0.35))
	Pal.window(self, _box)
	Pal.text(self, _box.position + Vector2(8, 5), title, Pal.DARK)
	draw_rect(Rect2(_box.position.x + 6, _box.position.y + 17, _box.size.x - 12, 1), Pal.MID)
	for i in mini(items.size() - _scroll, _visible_rows()):
		var idx := _scroll + i
		var it: Dictionary = items[idx]
		var y := _box.position.y + 21 + i * ROW_H
		var col := Pal.INK if not it.get("disabled", false) else Color(Pal.INK, 0.35)
		if idx == cursor:
			Pal.cursor(self, Vector2(_box.position.x + 7, y + 2))
		Pal.text(self, Vector2(_box.position.x + 16, y), it.label, col)
	if _has_desc() and not items.is_empty():
		var dy := _box.end.y - 57
		draw_rect(Rect2(_box.position.x + 6, dy - 2, _box.size.x - 12, 1), Pal.MID)
		Pal.text_wrap(self, Vector2(_box.position.x + 8, dy), items[cursor].get("desc", ""), _box.size.x - 16, Pal.BLUE, 10, 3)
	var help := "A 이동  B 결정  메뉴 뒤로"
	Pal.text(self, Vector2(_box.position.x + 8, _box.end.y - 15), help, Pal.DARK)
	if _scroll + _visible_rows() < items.size():
		draw_rect(Rect2(_box.end.x - 12, _box.end.y - 20, 5, 2), Pal.INK)
