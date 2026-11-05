class_name Hall
extends RefCounted
## 명예의 전당. 은퇴한 캐릭터와 다음 세대에 넘겨줄 유산을 user://hall.json에 따로 저장한다.
## (도감처럼 '처음부터 다시'를 해도 남는다)

const PATH := "user://hall.json"
const BONUS_PER_GEN := 0.1
const BONUS_MAX := 0.3


static func load_all() -> Dictionary:
	if FileAccess.file_exists(PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(d) == TYPE_DICTIONARY:
			return d
	return {"members": [], "legacy": {}}


static func _save(d: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


static func members() -> Array:
	return load_all().members


## 은퇴한 선배 수만큼 다음 세대 경험치 보너스 (세대당 10%, 최대 30%)
static func xp_bonus() -> float:
	return minf(BONUS_MAX, members().size() * BONUS_PER_GEN)


## 가장 최근에 은퇴한 선배 (박스 코치로 등장)
static func coach() -> Dictionary:
	var m := members()
	return m.back() if m.size() > 0 else {}


## 은퇴 등록. 다음 캐릭터가 받을 유산(코인 절반, 꾸미기 아이템)도 남긴다.
static func retire(entry: Dictionary, legacy: Dictionary) -> void:
	var d := load_all()
	(d.members as Array).append(entry)
	d.legacy = legacy
	_save(d)


## 새 캐릭터가 유산을 한 번 받아 간다.
static func take_legacy() -> Dictionary:
	var d := load_all()
	var lg: Dictionary = d.get("legacy", {})
	d.legacy = {}
	_save(d)
	return lg
