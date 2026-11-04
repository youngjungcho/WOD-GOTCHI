class_name DexScreen
extends Screen
## 도감: 지금까지 만난 진화형. 못 본 진화형은 실루엣과 힌트만 보인다.
## A/방향키: 이동, B/메뉴: 닫기, 칸을 터치하면 선택.

const COLS := 5
const CELL := Vector2(33, 31)
const TOP := 20.0

var _ids: Array = []
var _seen: Dictionary = {}
var cursor := 0


func _ready() -> void:
	for st in 5:
		_ids.append_array(Forms.ids_at(st))
	_seen = Forms.load_dex().seen


func on_button(btn: String, down: bool) -> void:
	if not down:
		return
	if btn == "a":
		cursor = (cursor + 1) % _ids.size()
		Sfx.play("move")
	else:
		Sfx.play("back")
		main.pop()


func on_dir(d: Vector2i) -> void:
	cursor = posmod(cursor + d.x + d.y * COLS, _ids.size())
	Sfx.play("move")


func on_tap(pos: Vector2) -> void:
	for i in _ids.size():
		if _cell(i).has_point(pos):
			cursor = i
			Sfx.play("move")
			return


func _cell(i: int) -> Rect2:
	return Rect2(4 + (i % COLS) * (CELL.x + 1), TOP + (i / COLS) * (CELL.y + 1), CELL.x, CELL.y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Pal.LIGHT)
	Pal.text(self, Vector2(6, 4), "도감  %d / %d" % [_seen.size(), _ids.size()], Pal.INK)
	var look: Dictionary = GameState.data.look
	for i in _ids.size():
		var id: String = _ids[i]
		var r := _cell(i)
		var seen := _seen.has(id)
		draw_rect(r, Pal.INK if i == cursor else Pal.DARK)
		draw_rect(r.grow(-1), Pal.WHITE if seen else Pal.MID)
		var st := Forms.style_of(id).duplicate()
		if not seen:
			st.sil = Color(Pal.INK, 0.55)
		Pal.athlete(self, r.position + Vector2(1, 1), look, "idle", 1, 1.0, 0.0, st, 29)
	var r2 := Rect2(2, size.y - 44, size.x - 4, 42)
	Pal.window(self, r2)
	var cid: String = _ids[cursor]
	var info: Dictionary = Forms.LIST[cid]
	var stage_name: String = GameState.STAGE_NAMES[int(info.stage)]
	if _seen.has(cid):
		var label: String = info.name if info.name == stage_name else "%s · %s" % [info.name, stage_name]
		Pal.text(self, r2.position + Vector2(8, 5), label, Pal.INK)
		Pal.text(self, r2.position + Vector2(8, 19), "%s 님이 %s 발견" % [_seen[cid].by, _seen[cid].at], Pal.DARK)
	else:
		Pal.text(self, r2.position + Vector2(8, 5), "??? · %s" % stage_name, Pal.INK)
		Pal.text(self, r2.position + Vector2(8, 19), info.hint, Pal.DARK)
