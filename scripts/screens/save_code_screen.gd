class_name SaveCodeScreen
extends FormScreen
## 저장 코드 보기·복사(export) / 붙여넣기·불러오기(import).
## 복사가 막힌 브라우저에서도 칸을 길게 눌러 직접 복사할 수 있다.


var _export := false


func _init(export_mode: bool) -> void:
	_export = export_mode
	if export_mode:
		var rows := [
			{"label": "저장 코드", "type": "text", "value": GameState.export_code(), "max_len": 100000},
			{"label": "복사하기", "type": "button", "cb": _copy},
		]
		if OS.has_feature("web"):
			rows.append({"label": "파일로 내려받기", "type": "button", "cb": _download})
		super("저장 코드", rows)
	else:
		super("저장 코드 불러오기", [
			{"label": "코드", "type": "text", "value": "", "max_len": 100000},
			{"label": "붙여넣기", "type": "button", "cb": _paste},
			{"label": "불러오기", "type": "button", "cb": _import},
		])
	top_y = 60.0


func _copy() -> void:
	DisplayServer.clipboard_set(str(value(0)))
	main.show_toast("복사했어요! 메모장 등에 붙여넣어 보관하세요.")


func _download() -> void:
	JavaScriptBridge.download_buffer(str(value(0)).to_utf8_buffer(), "wod-gotchi-save.txt", "text/plain")


func _paste() -> void:
	var clip := DisplayServer.clipboard_get()
	if clip == "":
		main.show_toast("클립보드가 비어 있어요. 칸을 눌러 직접 붙여넣어 주세요.")
		return
	rows[0].value = clip
	(_edits[0] as LineEdit).text = clip


func _import() -> void:
	var err := GameState.import_code(str(value(0)))
	if err != "":
		Sfx.play("miss")
		main.show_toast(err)
		return
	Sfx.play("levelup")
	main.goto(HomeScreen.new())
	main.say("불러오기 완료! %s 다시 만나서 반가워요." % GameState.data.name)


func _draw_header() -> void:
	var r := Rect2(2, 2, size.x - 4, 54)
	Pal.window(self, r)
	var msg := "코드를 보관하면 기기를 바꿔도\n그대로 이어서 키울 수 있어요." if _export else "보관한 WG1: 코드를 붙여넣고\n불러오기! (지금 캐릭터는 바뀌어요)"
	Pal.text_wrap(self, r.position + Vector2(8, 6), msg, r.size.x - 16, Pal.INK, 10, 3)
