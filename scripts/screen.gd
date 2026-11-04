class_name Screen
extends Control
## 모든 화면의 기반. Main이 버튼/방향/터치 입력을 전달한다.

## true면 아래 화면을 숨기지 않고 위에 겹쳐 그린다.
var overlay := false
var main: Node
var t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


## btn: "a", "b", "menu" / down: 눌림(true), 뗌(false)
func on_button(_btn: String, _down: bool) -> void:
	pass


## 키보드 방향키. (0,-1) 위, (0,1) 아래, (-1,0) 왼쪽, (1,0) 오른쪽
func on_dir(_d: Vector2i) -> void:
	pass


## 화면 영역 안을 터치/클릭했을 때 (화면 좌표)
func on_tap(_pos: Vector2) -> void:
	pass


## 본체 버튼 아래에 보여줄 이름. 비어 있는 키는 기본 이름(A / B / 메뉴).
func button_labels() -> Dictionary:
	return {}


## 지금 눌러야 할 버튼 힌트. {"a": 1(은은하게) 또는 2(지금!)}
func button_hints() -> Dictionary:
	return {}


## 다시 맨 위 화면이 되었을 때
func on_resume() -> void:
	pass
