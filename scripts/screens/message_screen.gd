class_name MessageScreen
extends Screen
## 하단 대화창에 글자가 한 글자씩 찍히는 메시지. 아무 버튼이나 누르면 닫힌다.

var _text: String
var _then: Callable
var _shown := 0.0


func _init(text: String, then: Callable = Callable()) -> void:
	super()
	overlay = true
	_text = text
	_then = then


func _process(delta: float) -> void:
	super(delta)
	_shown += delta * 40.0


func _done() -> bool:
	return _shown >= _text.length()


func _advance() -> void:
	if not _done():
		_shown = _text.length()
		return
	var cb := _then
	main.pop()
	Sfx.play("move")
	if cb.is_valid():
		cb.call()


func on_button(_btn: String, down: bool) -> void:
	if down:
		_advance()


func on_tap(_pos: Vector2) -> void:
	_advance()


func _draw() -> void:
	var r := Rect2(2, size.y - 66, size.x - 4, 64)
	Pal.window(self, r)
	var shown := _text.substr(0, int(_shown))
	Pal.text_wrap(self, r.position + Vector2(8, 6), shown, r.size.x - 16, Pal.INK, 10, 4)
	if _done() and int(t * 3.0) % 2 == 0:
		# ▼ 표시
		for i in 4:
			draw_rect(Rect2(r.end.x - 14 + i, r.end.y - 10 + i, 7 - i * 2, 1), Pal.INK)
