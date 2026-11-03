class_name Forms
extends RefCounted
## 진화형 목록과 분기 조건. 도감은 user://dex.json에 따로 저장돼서 새로 시작해도 남는다.
## style: body(slim/normal/wide/huge/chubby), headband(색), belt, wrist, sleeves, glasses, cape(색), crown, bandage, sweat

const DEX_PATH := "user://dex.json"

const LIST := {
	"rookie": {"name": "등록생", "stage": 0, "style": {}, "hint": "처음 박스에 온 초보"},
	"scaled": {"name": "스케일드", "stage": 1, "style": {"headband": "fcfcf4"}, "hint": "꾸준히 나오면 된다"},
	# RX
	"rx_str": {"name": "바벨 괴물", "stage": 2, "style": {"body": "wide", "belt": true}, "hint": "근력 위주로 키우기"},
	"rx_gym": {"name": "체조 요정", "stage": 2, "style": {"body": "slim", "wrist": true}, "hint": "체조 위주로 키우기"},
	"rx_eng": {"name": "카디오 머신", "stage": 2, "style": {"body": "slim", "headband": "d84838", "sweat": true}, "hint": "엔진 위주로 키우기"},
	"rx_tec": {"name": "테크니션", "stage": 2, "style": {"sleeves": true, "headband": "4878c8"}, "hint": "기술 위주로 키우기"},
	"rx_all": {"name": "올라운더", "stage": 2, "style": {"headband": "f0c030", "wrist": true}, "hint": "네 능력치를 고르게"},
	"rx_food": {"name": "먹방 리프터", "stage": 2, "style": {"body": "chubby"}, "hint": "??? (먹는 걸 너무 좋아하면...)"},
	# 컴피티터
	"cp_str": {"name": "파워 리프터", "stage": 3, "style": {"body": "huge", "belt": true, "sleeves": true}, "hint": "근력의 길"},
	"cp_gym": {"name": "짐내스트", "stage": 3, "style": {"body": "slim", "wrist": true, "headband": "8048b0"}, "hint": "체조의 길"},
	"cp_eng": {"name": "엔진 괴물", "stage": 3, "style": {"body": "slim", "headband": "d84838", "sweat": true, "wrist": true}, "hint": "엔진의 길"},
	"cp_tec": {"name": "올림픽 리프터", "stage": 3, "style": {"sleeves": true, "belt": true, "glasses": true}, "hint": "기술의 길"},
	"cp_all": {"name": "만능 선수", "stage": 3, "style": {"headband": "f0c030", "wrist": true, "belt": true}, "hint": "끝까지 균형있게"},
	"cp_mental": {"name": "멘탈 갑", "stage": 3, "style": {"headband": "282020", "wrist": true, "belt": true}, "hint": "??? (꾀부림에 흔들리지 않으면...)"},
	"cp_cheat": {"name": "치팅데이 킹", "stage": 3, "style": {"body": "chubby", "belt": true}, "hint": "??? (치킨을 사랑하면...)"},
	"cp_glass": {"name": "유리몸 투혼", "stage": 3, "style": {"bandage": true, "sleeves": true}, "hint": "??? (자주 다치면...)"},
	# 게임즈 선수
	"gm_str": {"name": "헐크", "stage": 4, "style": {"body": "huge", "belt": true, "sleeves": true, "cape": "c83838"}, "hint": "근력의 정점"},
	"gm_gym": {"name": "스파이더", "stage": 4, "style": {"body": "slim", "wrist": true, "headband": "8048b0", "cape": "4878c8"}, "hint": "체조의 정점"},
	"gm_eng": {"name": "철인", "stage": 4, "style": {"body": "slim", "headband": "d84838", "wrist": true, "cape": "58b048"}, "hint": "엔진의 정점"},
	"gm_tec": {"name": "마에스트로", "stage": 4, "style": {"sleeves": true, "belt": true, "glasses": true, "cape": "f0c030"}, "hint": "기술의 정점"},
	"gm_legend": {"name": "레전드", "stage": 4, "style": {"body": "wide", "belt": true, "wrist": true, "cape": "c83838", "crown": true}, "hint": "??? (다치지 않고, 멘탈 강하게, 고르게, 늘 곁에서)"},
	"gm_pizza": {"name": "피자 챔피언", "stage": 4, "style": {"body": "chubby", "crown": true}, "hint": "??? (치팅의 끝)"},
	"gm_phoenix": {"name": "불사조", "stage": 4, "style": {"bandage": true, "cape": "f08030", "sleeves": true}, "hint": "??? (넘어져도 다시 일어나면)"},
}

const STAGE_PREFIX := ["등록생", "스케일드", "RX", "컴피티터", "게임즈"]


static func name_of(id: String) -> String:
	return LIST[id].name


static func style_of(id: String) -> Dictionary:
	return LIST.get(id, LIST.rookie).style


static func ids_at(stage: int) -> Array:
	var out := []
	for id in LIST:
		if int(LIST[id].stage) == stage:
			out.append(id)
	return out


## 지금까지 키운 방식으로 이번 단계의 진화형을 정한다.
static func decide(stage: int) -> String:
	if stage == 0:
		return "rookie"
	if stage == 1:
		return "scaled"
	var gs = GameState
	var h: Dictionary = gs.data.hist
	var lv := {}
	var lo := 999
	var hi := 0
	var best := "str"
	for s in gs.STATS:
		lv[s] = gs.level(s)
		lo = mini(lo, lv[s])
		hi = maxi(hi, lv[s])
		if lv[s] > lv[best]:
			best = s
	var eaten: int = int(h.cheat) + int(h.healthy)
	var cheat_ratio := float(h.cheat) / eaten if eaten >= 5 else 0.0
	var mental := float(gs.data.mental)
	match stage:
		2:
			if cheat_ratio > 0.45:
				return "rx_food"
			if hi - lo <= 1:
				return "rx_all"
			return "rx_" + best
		3:
			if int(h.injuries) >= 3:
				return "cp_glass"
			if cheat_ratio > 0.45:
				return "cp_cheat"
			if mental >= 70.0:
				return "cp_mental"
			if hi - lo <= 2:
				return "cp_all"
			return "cp_" + best
		_:
			if int(h.injuries) == 0 and mental >= 70.0 and hi - lo <= 3 and int(h.ignored) <= 3:
				return "gm_legend"
			if int(h.injuries) >= 3:
				return "gm_phoenix"
			if cheat_ratio > 0.45:
				return "gm_pizza"
			return "gm_" + best


# ---------- 도감 ----------

static func load_dex() -> Dictionary:
	if FileAccess.file_exists(DEX_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(DEX_PATH))
		if typeof(d) == TYPE_DICTIONARY:
			return d
	return {"seen": {}}


## 처음 본 진화형이면 true.
static func register(id: String, char_name: String) -> bool:
	var d := load_dex()
	var seen: Dictionary = d.seen
	var is_new := not seen.has(id)
	if is_new:
		seen[id] = {"by": char_name, "at": Time.get_date_string_from_system()}
		var f := FileAccess.open(DEX_PATH, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(d))
	return is_new
