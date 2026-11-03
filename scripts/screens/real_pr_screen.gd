class_name RealPrScreen
extends FormScreen
## 내 실제 PR 입력. 기존 기록보다 오르면 캐릭터가 보너스를 받는다.

const KEYS := ["deadlift", "squat", "clean", "snatch", "pullup"]


func _init() -> void:
	var prs: Dictionary = GameState.data.real.prs
	var r := []
	for k in KEYS:
		if k == "pullup":
			r.append({"label": "최대 풀업", "type": "number", "value": float(prs[k]), "min": 0.0, "max": 100.0, "step": 1.0, "fmt": "%s개"})
		else:
			r.append({"label": GameState.LIFTS[k], "type": "number", "value": float(prs[k]), "min": 0.0, "max": 400.0, "step": 2.5, "fmt": "%skg"})
	r.append({"label": "저장하기", "type": "button", "cb": _save})
	super("나의 실제 PR", r)


func _save() -> void:
	var msgs := []
	for i in KEYS.size():
		var k: String = KEYS[i]
		var v := float(value(i))
		if v > float(GameState.data.real.prs[k]):
			msgs.append(GameState.real_pr(k, v))
	main.pop_to_root()
	if msgs.is_empty():
		main.say("바뀐 기록이 없어요.")
	else:
		Sfx.play("levelup")
		main.say("\n".join(msgs))
