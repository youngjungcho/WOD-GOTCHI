class_name ShopScreen
extends Screen
## 꾸미기 상점. 위쪽 탭(착용 / 박스), 미리보기, 아이템 목록.
## A 다음 아이템, B 사기·착용·해제, 메뉴 뒤로. 줄을 터치하면 고르고, 고른 줄을 한 번 더 누르면 B와 같다.

const ROW_H := 16
const LIST_Y := 108.0

var _tab := "wear"
var _ids: Array = []
var cursor := 0
var _scroll := 0


func _ready() -> void:
	_load_tab()


func _load_tab() -> void:
	_ids = Shop.ids_in(_tab)
	cursor = 0
	_scroll = 0


func _sel() -> String:
	return _ids[cursor] if cursor < _ids.size() else ""


func _action_label() -> String:
	var id := _sel()
	if id == "":
		return "-"
	if not GameState.owns(id):
		return "사기"
	return "해제" if GameState.is_equipped(id) else "착용"


func button_labels() -> Dictionary:
	return {"a": "다음", "b": _action_label(), "menu": "뒤로"}


func _rows() -> int:
	return int((size.y - LIST_Y - 2) / ROW_H)


func _move(d: int) -> void:
	cursor = posmod(cursor + d, _ids.size())
	if cursor < _scroll:
		_scroll = cursor
	elif cursor >= _scroll + _rows():
		_scroll = cursor - _rows() + 1
	Sfx.play("move")


func _act() -> void:
	var id := _sel()
	if id == "":
		return
	if not GameState.owns(id):
		var err := GameState.buy(id)
		if err != "":
			Sfx.play("miss")
			main.show_toast(err)
			return
		Sfx.play("levelup")
		main.show_toast("%s 구매! 바로 착용했어요." % Shop.ITEMS[id].name)
	else:
		GameState.toggle_equip(id)
		Sfx.play("select")


func on_button(btn: String, down: bool) -> void:
	if not down:
		return
	match btn:
		"a":
			_move(1)
		"b":
			_act()
		"menu":
			Sfx.play("back")
			main.pop()


func on_dir(d: Vector2i) -> void:
	if d.y != 0:
		_move(d.y)
	elif d.x != 0:
		_tab = "room" if _tab == "wear" else "wear"
		_load_tab()


func _tab_rect(i: int) -> Rect2:
	return Rect2(4 + i * 88, 22, 84, 16)


func on_tap(pos: Vector2) -> void:
	if Rect2(4, 3, 36, 16).grow(3).has_point(pos):
		Sfx.play("back")
		main.pop()
		return
	for i in 2:
		if _tab_rect(i).has_point(pos):
			var t2 := "wear" if i == 0 else "room"
			if t2 != _tab:
				_tab = t2
				_load_tab()
				Sfx.play("move")
			return
	for i in mini(_ids.size() - _scroll, _rows()):
		var r := Rect2(4, LIST_Y + i * ROW_H, size.x - 8, ROW_H - 1)
		if r.has_point(pos):
			var idx := _scroll + i
			if idx == cursor:
				_act()
			else:
				cursor = idx
				Sfx.play("move")
			return


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Pal.LIGHT)
	Pal.round_rect(self, Rect2(4, 3, 36, 16), Pal.MID)
	Pal.text(self, Vector2(7, 5), "◀뒤로", Pal.INK)
	Pal.text(self, Vector2(46, 5), "꾸미기 상점", Pal.DARK)
	var ct := "%d코인" % GameState.coins()
	Pal.icon(self, Vector2(size.x - 14 - Pal.text_width(ct), 6), "coin")
	Pal.text(self, Vector2(size.x - 6 - Pal.text_width(ct), 5), ct, Pal.INK)
	# 탭
	for i in 2:
		var on := (i == 0) == (_tab == "wear")
		var tr := _tab_rect(i)
		Pal.round_rect(self, tr, Pal.INK)
		Pal.round_rect(self, tr.grow(-1), Pal.WHITE if on else Pal.MID)
		Pal.text_center(self, tr, "캐릭터 꾸미기" if i == 0 else "박스 꾸미기", Pal.INK if on else Pal.DARK)
	# 미리보기
	var id := _sel()
	var pv := Rect2(4, 41, 100, 64)
	if _tab == "wear":
		Pal.round_rect(self, pv, Pal.INK)
		Pal.round_rect(self, pv.grow(-1), Color("fdeedd"))
		var items := GameState.equipped().duplicate()
		if id != "":
			items[Shop.ITEMS[id].slot] = id
		var st := GameState.style_with(GameState.data.get("form", "rookie"), items)
		Pal.athlete(self, Vector2(pv.position.x + 34, pv.position.y + 12), GameState.data.look, "happy", 1, t, 0.0, st)
	else:
		# 박스는 배경 전체가 보여야 해서 가로로 넓게
		pv = Rect2(4, 41, size.x - 8, 50)
		var rm := GameState.room().duplicate()
		if id != "":
			rm.merge(Shop.ITEMS[id].room, true)
		Pal.box_scene(self, pv, t, 0.68, rm)
		Pal.frame(self, pv, Pal.INK)
	# 고른 아이템 정보
	if id != "" and _tab == "room":
		var it: Dictionary = Shop.ITEMS[id]
		var status := "%d코인" % int(it.price)
		if GameState.owns(id):
			status = "착용 중" if GameState.is_equipped(id) else "보유"
		Pal.text(self, Vector2(6, 93), "%s · %s · B: %s" % [it.name, status, _action_label()], Pal.INK)
	elif id != "":
		var it: Dictionary = Shop.ITEMS[id]
		var ix := pv.end.x + 6
		Pal.text_wrap(self, Vector2(ix, 44), it.name, size.x - ix - 4, Pal.INK, 10, 2)
		var status := "%d코인" % int(it.price)
		var col := Pal.INK
		if GameState.owns(id):
			status = "착용 중" if GameState.is_equipped(id) else "가지고 있음"
			col = Pal.GREEN
		elif GameState.coins() < int(it.price):
			col = Pal.RED
		Pal.text(self, Vector2(ix, 70), status, col)
		Pal.text(self, Vector2(ix, 86), "B: " + _action_label(), Pal.BLUE)
	# 목록
	for i in mini(_ids.size() - _scroll, _rows()):
		var idx := _scroll + i
		var iid: String = _ids[idx]
		var it: Dictionary = Shop.ITEMS[iid]
		var r := Rect2(4, LIST_Y + i * ROW_H, size.x - 8, ROW_H - 1)
		if idx == cursor:
			Pal.round_rect(self, r, Color("fdeedd"))
			Pal.cursor(self, r.position + Vector2(2, 4))
		Pal.text(self, r.position + Vector2(10, 2), it.name, Pal.INK)
		var right := "%d" % int(it.price)
		var rc := Pal.DARK
		if GameState.owns(iid):
			right = "착용" if GameState.is_equipped(iid) else "보유"
			rc = Pal.GREEN
		Pal.text(self, Vector2(r.end.x - 4 - Pal.text_width(right), r.position.y + 2), right, rc)
		if not GameState.owns(iid):
			Pal.icon(self, Vector2(r.end.x - 12 - Pal.text_width(right), r.position.y + 4), "coin")
	if _scroll + _rows() < _ids.size():
		Pal.text(self, Vector2(size.x - 14, size.y - 12), "▼", Pal.BLUE)
