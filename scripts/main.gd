extends Control
## 화면 스택, 하단 다마고치식 버튼(≡ / B / A), 입력 분배, 토스트를 담당한다.

const W := 180
const H := 320
const SCREEN_H := 236

const BTN_RADIUS := 17
const BUTTONS := {
	"menu": Vector2(32, 276),
	"b": Vector2(96, 282),
	"a": Vector2(146, 270),
}
const BTN_LABELS := {"menu": "메뉴", "b": "B", "a": "A"}

var stack: Array[Screen] = []
var _held := {}  # btn -> 누르고 있는 포인터 id
var _touch_seen := false
var _toasts: Array[String] = []
var _toast_time := 0.0
var _screen_root: Control
var _overlay: Control


func _ready() -> void:
	size = Vector2(W, H)
	_screen_root = Control.new()
	_screen_root.size = Vector2(W, SCREEN_H)
	_screen_root.clip_contents = true
	_screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen_root)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.size = Vector2(W, H)
	_overlay.draw.connect(_draw_toast)
	add_child(_overlay)
	GameState.toast.connect(func(m): _toasts.append(m))
	if GameState.is_created():
		goto(HomeScreen.new())
	else:
		goto(CreationScreen.new())


func _process(delta: float) -> void:
	if _toasts.size() > 0:
		_toast_time += delta
		if _toast_time > 2.6:
			_toasts.pop_front()
			_toast_time = 0.0
	queue_redraw()
	_overlay.queue_redraw()


# ---------- 화면 스택 ----------

func top() -> Screen:
	return stack.back() if stack.size() > 0 else null


func push(s: Screen) -> void:
	if top() and not s.overlay:
		top().visible = false
	s.main = self
	s.size = Vector2(W, SCREEN_H)
	stack.append(s)
	_screen_root.add_child(s)
	Sfx.play("select")


func pop() -> void:
	if stack.size() <= 1:
		return
	var s: Screen = stack.pop_back()
	s.queue_free()
	_release_all()
	top().visible = true
	top().on_resume()


func goto(s: Screen) -> void:
	for old in stack:
		old.queue_free()
	stack.clear()
	_release_all()
	push(s)


## 맨 아래(홈)까지 돌아간다.
func pop_to_root() -> void:
	while stack.size() > 1:
		var s: Screen = stack.pop_back()
		s.queue_free()
	_release_all()
	top().visible = true
	top().on_resume()


func say(text: String, then: Callable = Callable()) -> void:
	push(MessageScreen.new(text, then))


func show_toast(m: String) -> void:
	_toasts.append(m)


# ---------- 입력 ----------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touch_seen = true
		_pointer(event.position, event.pressed, event.index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not _touch_seen:
		_pointer(event.position, event.pressed, 0)


func _pointer(screen_pos: Vector2, down: bool, id: int) -> void:
	# stretch mode가 viewport라서 이벤트 좌표는 이미 180x320 기준이다
	var pos := screen_pos
	if down:
		for b in BUTTONS:
			if pos.distance_to(BUTTONS[b]) <= BTN_RADIUS + 6:
				_press(b, true, id)
				return
		if pos.y < SCREEN_H and top():
			top().on_tap(pos)
	else:
		for b in _held.keys():
			if _held[b] == id:
				_press(b, false, id)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or k.echo:
		return
	var btn := ""
	match k.keycode:
		KEY_Z, KEY_SPACE:
			btn = "a"
		KEY_X:
			btn = "b"
		KEY_ENTER, KEY_ESCAPE, KEY_TAB, KEY_C:
			btn = "menu"
	if btn != "":
		_press(btn, k.pressed, -1)
		return
	if not k.pressed or top() == null:
		return
	# 테스트용 키 (PC): F1 호출, F2 6시간 경과(+운동한 날 1일), F3 경험치 +50
	if GameState.is_created():
		match k.keycode:
			KEY_F1:
				GameState.spawn_call()
				return
			KEY_F2:
				GameState.debug_hours(6.0)
				return
			KEY_F3:
				GameState.debug_xp(50.0)
				return
	match k.keycode:
		KEY_UP:
			top().on_dir(Vector2i(0, -1))
		KEY_DOWN:
			top().on_dir(Vector2i(0, 1))
		KEY_LEFT:
			top().on_dir(Vector2i(-1, 0))
		KEY_RIGHT:
			top().on_dir(Vector2i(1, 0))


func _press(btn: String, down: bool, id: int) -> void:
	if down:
		if _held.has(btn):
			return
		_held[btn] = id
	else:
		if not _held.has(btn):
			return
		_held.erase(btn)
	if top():
		top().on_button(btn, down)


func _release_all() -> void:
	_held.clear()


# ---------- 그리기 (하단 본체) ----------

func _draw() -> void:
	# 본체
	draw_rect(Rect2(0, SCREEN_H, W, H - SCREEN_H), Color("6858a8"))
	draw_rect(Rect2(0, SCREEN_H, W, 2), Pal.INK)
	draw_rect(Rect2(0, SCREEN_H + 2, W, 1), Color("8878c8"))
	Pal.text(self, Vector2(8, SCREEN_H + 6), "WOD-GOTCHI", Color("b8b0e8"))
	Pal.text(self, Vector2(W - 58, SCREEN_H + 6), "COLOR", Color("f0a0a0"))
	for b in BUTTONS:
		var c: Vector2 = BUTTONS[b]
		var pressed := _held.has(b)
		var off := Vector2(0, 1) if pressed else Vector2.ZERO
		if b == "menu":
			var r := Rect2(c - Vector2(16, 6), Vector2(32, 12))
			draw_rect(Rect2(r.position + Vector2(0, 2), r.size), Pal.INK)
			draw_rect(Rect2(r.position + off, r.size), Pal.INK)
			draw_rect(Rect2(r.position + off + Vector2(1, 1), r.size - Vector2(2, 2)), Color("a8a0b8") if not pressed else Color("888098"))
			Pal.text_center(self, Rect2(c.x - 30, c.y + 9, 60, 12), BTN_LABELS[b], Color("d8d0f8"))
		else:
			draw_circle(c + Vector2(0, 2), BTN_RADIUS, Pal.INK)
			draw_circle(c + off, BTN_RADIUS, Pal.INK)
			draw_circle(c + off, BTN_RADIUS - 1, Color("c03858") if not pressed else Color("982848"))
			draw_circle(c + off + Vector2(-5, -5), 4, Color("e06080"))
			Pal.text_center(self, Rect2(c.x - 20, c.y + BTN_RADIUS + 3, 40, 12), BTN_LABELS[b], Color("d8d0f8"))


func _draw_toast() -> void:
	if _toasts.size() > 0:
		var r := Rect2(6, 4, W - 12, 28)
		Pal.window(_overlay, r, Pal.YELLOW.lightened(0.6))
		Pal.text_wrap(_overlay, r.position + Vector2(6, 3), _toasts[0], r.size.x - 12, Pal.INK, 10, 2)
