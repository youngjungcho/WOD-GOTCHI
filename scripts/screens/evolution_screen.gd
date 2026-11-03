class_name EvolutionScreen
extends Screen
## 진화 연출: 이전 모습과 새 모습이 점점 빠르게 깜빡이다가 새 모습이 나타난다.

const FLASH_TIME := 3.6

var from_id: String
var to_id: String
var _is_new := false
var _done := false


func _init(p_from: String, p_to: String) -> void:
	super()
	from_id = p_from
	to_id = p_to


func _ready() -> void:
	Sfx.play("evolve")


func _process(delta: float) -> void:
	super(delta)
	if not _done and t >= FLASH_TIME:
		_done = true
		_is_new = Forms.register(to_id, GameState.data.name)
		Sfx.play("levelup")


func on_button(_btn: String, down: bool) -> void:
	if down:
		_skip_or_close()


func on_tap(_pos: Vector2) -> void:
	_skip_or_close()


func _skip_or_close() -> void:
	if not _done:
		t = FLASH_TIME
		return
	if t < FLASH_TIME + 0.6:
		return
	GameState.data.pending_evo = {}
	GameState.save_game()
	main.pop()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Pal.WHITE)
	var look: Dictionary = GameState.data.look
	var o := Vector2(size.x * 0.5 - 24, 50)
	if not _done:
		# 처음엔 천천히, 끝으로 갈수록 빠르게 번갈아 보인다
		var speed := lerpf(2.0, 14.0, t / FLASH_TIME)
		var show_new := int(t * speed) % 2 == 1
		var st := Forms.style_of(to_id if show_new else from_id).duplicate()
		st.sil = Pal.INK if int(t * 20.0) % 2 == 0 else Pal.DARK
		Pal.athlete(self, o, look, "idle", 3, 0.0, 0.0, st)
		var r := Rect2(2, size.y - 66, size.x - 4, 64)
		Pal.window(self, r)
		Pal.text_wrap(self, r.position + Vector2(8, 6), "어라...?\n%s의 모습이...!" % GameState.data.name, r.size.x - 16)
		return
	# 반짝이 효과
	for i in 8:
		var a := t * 2.0 + i * TAU / 8.0
		var p := o + Vector2(24, 36) + Vector2(cos(a), sin(a)) * (46.0 + sin(t * 4.0) * 4.0)
		draw_rect(Rect2(p, Vector2(2, 2)), [Pal.YELLOW, Pal.RED, Pal.BLUE, Pal.GREEN][i % 4])
	Pal.athlete(self, o, look, "happy", 3, t, 0.0, Forms.style_of(to_id))
	var r := Rect2(2, size.y - 66, size.x - 4, 64)
	Pal.window(self, r)
	var msg := "축하해요! %s은(는)\n[%s](으)로 진화했다!" % [GameState.data.name, GameState.title()]
	Pal.text_wrap(self, r.position + Vector2(8, 6), msg, r.size.x - 16)
	if _is_new:
		Pal.text(self, r.position + Vector2(8, 38), "★ 도감에 새로 등록!", Pal.RED)
