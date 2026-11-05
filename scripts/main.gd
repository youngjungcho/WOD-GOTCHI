extends Control
## 화면 스택, 하단 다마고치식 버튼(메뉴 / B / A), 입력 분배, 토스트를 담당한다.
## 화면 비율이 세로로 길면(휴대폰) 늘어난 높이만큼 아래 본체가 커지고 버튼도 커진다.

const W := 180
const BASE_H := 320
const SCREEN_H := 236

const BTN_LABELS := {"menu": "메뉴", "b": "B", "a": "A"}

var H := BASE_H  # 실제 화면 높이 (stretch aspect = keep_width)
var stack: Array[Screen] = []
var _buttons := {}  # btn -> 중심 좌표
var _radius := 17.0
var _held := {}  # btn -> 누르고 있는 포인터 id
var _touch_seen := false
var _toasts: Array[String] = []
var _toast_time := 0.0
var _screen_root: Control
var _overlay: Control


func _ready() -> void:
	_screen_root = Control.new()
	_screen_root.size = Vector2(W, SCREEN_H)
	_screen_root.clip_contents = true
	_screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen_root)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_toast)
	add_child(_overlay)
	get_viewport().size_changed.connect(_layout)
	_layout()
	GameState.toast.connect(func(m): _toasts.append(m))
	if GameState.is_created():
		goto(HomeScreen.new())
	else:
		goto(CreationScreen.new())


## 화면 높이에 맞춰 본체와 버튼 위치·크기를 정한다.
func _layout() -> void:
	H = maxi(BASE_H, int(get_viewport_rect().size.y))
	size = Vector2(W, H)
	_overlay.size = Vector2(W, H)
	var panel := float(H - SCREEN_H)
	# 아래쪽 홈 바 영역을 피하려고 길쭉한 화면이면 바닥을 조금 띄운다
	var bottom_pad := clampf((panel - 84.0) * 0.25, 0.0, 24.0)
	var area := panel - bottom_pad
	_radius = clampf(area * 0.2, 17.0, 26.0)
	var cy := SCREEN_H + area * 0.55
	_buttons = {
		"menu": Vector2(32, cy + _radius * 0.35),
		"b": Vector2(98, cy + _radius * 0.35),
		"a": Vector2(150, cy - _radius * 0.35),
	}


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
	# 덮어 그리는 화면이라도, 메뉴 위에 메뉴를 열 때는 이전 메뉴 창을 숨긴다
	if top() and (not s.overlay or (top() is ListScreen and s is ListScreen) or (top() is FormScreen and s is ListScreen)):
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
	# stretch mode가 viewport라서 이벤트 좌표는 이미 게임 좌표(가로 180) 기준이다
	var pos := screen_pos
	if down:
		for b in _buttons:
			if pos.distance_to(_buttons[b]) <= _radius + 8:
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
	# 테스트용 키 (개발 빌드에서만): F1 호출, F2 6시간 경과(+운동한 날 1일), F3 경험치 +50
	if OS.is_debug_build() and GameState.is_created():
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
	# 파스텔 민트 본체
	draw_rect(Rect2(0, SCREEN_H, W, H - SCREEN_H), Color("b8e6d8"))
	draw_rect(Rect2(0, SCREEN_H, W, 2), Pal.INK)
	draw_rect(Rect2(0, SCREEN_H + 2, W, 2), Color("dcf5ee"))
	draw_rect(Rect2(0, H - 4, W, 4), Color("94d0bf"))
	Pal.text(self, Vector2(8, SCREEN_H + 7), "WOD-GOTCHI", Color("4f9c88"))
	Pal.icon(self, Vector2(W - 16, SCREEN_H + 8), "heart")
	var hints: Dictionary = top().button_hints() if top() else {}
	var labels: Dictionary = top().button_labels() if top() else {}
	var r0 := _radius
	for b in _buttons:
		var c: Vector2 = _buttons[b]
		var pressed := _held.has(b)
		var off := Vector2(0, 1) if pressed else Vector2.ZERO
		# 눌러야 할 버튼: 은은한 테두리, 타이밍이 맞으면 반짝이는 테두리와 화살표
		var h := int(hints.get(b, 0))
		if h > 0 and b != "menu":
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
			var ring := Color(Pal.YELLOW, 0.45) if h == 1 else Color(Pal.YELLOW, 0.7 + 0.3 * pulse)
			draw_circle(c, r0 + (3 if h == 1 else 4 + pulse * 2), ring)
			if h == 2:
				var ay := c.y - r0 - 13 - pulse * 2
				for i in 5:
					draw_rect(Rect2(c.x - 4 + i, ay + i, 9 - i * 2, 1), Pal.RED)
		if b == "menu":
			var r := Rect2(c - Vector2(17, 7), Vector2(34, 14))
			draw_rect(Rect2(r.position + Vector2(0, 2), r.size), Pal.INK)
			draw_rect(Rect2(r.position + off, r.size), Pal.INK)
			draw_rect(Rect2(r.position + off + Vector2(1, 1), r.size - Vector2(2, 2)), Color("c9b8f0") if not pressed else Color("a894d8"))
			Pal.text_center(self, Rect2(c.x - 30, c.y + 10, 60, 12), labels.get(b, BTN_LABELS[b]), Color("4f9c88"))
		else:
			draw_circle(c + Vector2(0, 2), r0, Pal.INK)
			draw_circle(c + off, r0, Pal.INK)
			draw_circle(c + off, r0 - 1, Color("ff8a9a") if not pressed else Color("e8687c"))
			draw_circle(c + off + Vector2(-r0 * 0.3, -r0 * 0.3), r0 * 0.24, Color("ffc2cc"))
			Pal.text_center(self, Rect2(c.x - 26, c.y + r0 + 3, 52, 12), labels.get(b, BTN_LABELS[b]), Color("4f9c88"))


func _draw_toast() -> void:
	if _toasts.size() > 0:
		var r := Rect2(6, 4, W - 12, 28)
		Pal.window(_overlay, r, Pal.YELLOW.lightened(0.6))
		Pal.text_wrap(_overlay, r.position + Vector2(6, 3), _toasts[0], r.size.x - 12, Pal.INK, 10, 2)
