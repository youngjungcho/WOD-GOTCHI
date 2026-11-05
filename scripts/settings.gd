class_name Settings
extends RefCounted
## 기기 설정 (소리·진동). 게임 저장과 따로 user://settings.json에 둔다.

const PATH := "user://settings.json"

static var sound := true
static var vibrate := true
static var music := true
static var _loaded := false


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(d) == TYPE_DICTIONARY:
			sound = d.get("sound", true)
			vibrate = d.get("vibrate", true)
			music = d.get("music", true)


static func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"sound": sound, "vibrate": vibrate, "music": music}))
