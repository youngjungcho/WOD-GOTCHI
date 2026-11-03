class_name Moves
extends RefCounted
## 크로스핏 동작 라이브러리.
## xp: 1회당 능력치 XP [근력, 체조, 엔진, 기술]
## mash 동작은 taps(1회당 연타 수), rhythm 동작은 rhythm(리듬 패턴)을 가진다.
## rhythm.pat: a/b = 탭, A/B = 1박 길게 누르기, "." = 쉬는 박. each=true면 노트마다 1회, 아니면 패턴 1번이 1회.
## req: 해금 조건(능력치 레벨), scale: 잠겼을 때 대신 할 동작, unit: 횟수 단위

const CATS := {"barbell": "바벨", "kb": "케틀벨·덤벨·기타", "gym": "체조", "cardio": "카디오"}
const STAT_KEYS := ["str", "gym", "eng", "tec"]

const LIST := {
	# ---------- 바벨 ----------
	"deadlift": {"name": "데드리프트", "cat": "barbell", "taps": 2, "xp": [1.2, 0, 0.2, 0.2]},
	"backsquat": {"name": "백스쿼트", "cat": "barbell", "taps": 2, "xp": [1.1, 0, 0.3, 0.2]},
	"frontsquat": {"name": "프론트 스쿼트", "cat": "barbell", "taps": 2, "xp": [1.0, 0, 0.3, 0.4], "req": {"str": 2}, "scale": "backsquat"},
	"ohs": {"name": "오버헤드 스쿼트", "cat": "barbell", "taps": 3, "xp": [0.7, 0.2, 0.2, 0.9], "req": {"tec": 3}, "scale": "frontsquat"},
	"press": {"name": "스트릭트 프레스", "cat": "barbell", "taps": 2, "xp": [0.9, 0.2, 0.1, 0.2]},
	"pushpress": {"name": "푸시 프레스", "cat": "barbell", "taps": 2, "xp": [0.9, 0, 0.3, 0.3]},
	"pushjerk": {"name": "푸시 저크", "cat": "barbell", "taps": 2, "xp": [0.8, 0, 0.3, 0.6], "req": {"tec": 2}, "scale": "pushpress"},
	"splitjerk": {"name": "스플릿 저크", "cat": "barbell", "taps": 3, "xp": [0.8, 0, 0.2, 0.9], "req": {"tec": 4}, "scale": "pushjerk"},
	"hangclean": {"name": "행 파워클린", "cat": "barbell", "taps": 2, "xp": [0.7, 0, 0.3, 0.6]},
	"powerclean": {"name": "파워 클린", "cat": "barbell", "taps": 2, "xp": [0.9, 0, 0.3, 0.6], "req": {"tec": 2}, "scale": "hangclean"},
	"squatclean": {"name": "스쿼트 클린", "cat": "barbell", "taps": 3, "xp": [1.0, 0, 0.3, 0.8], "req": {"tec": 3, "str": 3}, "scale": "powerclean"},
	"cleanjerk": {"name": "클린 앤 저크", "cat": "barbell", "taps": 4, "xp": [1.2, 0, 0.4, 1.0], "req": {"tec": 4, "str": 4}, "scale": "powerclean"},
	"powersnatch": {"name": "파워 스내치", "cat": "barbell", "taps": 3, "xp": [0.7, 0, 0.3, 0.9], "req": {"tec": 3}, "scale": "dbsnatch"},
	"squatsnatch": {"name": "스쿼트 스내치", "cat": "barbell", "taps": 4, "xp": [0.8, 0.1, 0.3, 1.3], "req": {"tec": 5, "str": 3}, "scale": "powersnatch"},
	"thruster": {"name": "쓰러스터", "cat": "barbell", "taps": 3, "xp": [0.8, 0, 0.7, 0.3]},
	"sdhp": {"name": "스모 데드 하이풀", "cat": "barbell", "taps": 2, "xp": [0.7, 0, 0.5, 0.3]},
	"lunge": {"name": "바벨 런지", "cat": "barbell", "taps": 2, "xp": [0.8, 0, 0.4, 0.2]},
	"bench": {"name": "벤치 프레스", "cat": "barbell", "taps": 2, "xp": [1.0, 0.1, 0.1, 0.1]},
	# ---------- 케틀벨·덤벨·기타 ----------
	"kbswing": {"name": "케틀벨 스윙", "cat": "kb", "taps": 2, "xp": [0.5, 0, 0.5, 0.2]},
	"goblet": {"name": "고블릿 스쿼트", "cat": "kb", "taps": 2, "xp": [0.5, 0, 0.4, 0.1]},
	"tgu": {"name": "터키쉬 겟업", "cat": "kb", "taps": 4, "xp": [0.6, 0.5, 0.1, 0.7], "req": {"tec": 2}, "scale": "goblet"},
	"dbsnatch": {"name": "덤벨 스내치", "cat": "kb", "taps": 2, "xp": [0.5, 0, 0.5, 0.4]},
	"dbcj": {"name": "덤벨 클린앤저크", "cat": "kb", "taps": 3, "xp": [0.6, 0, 0.4, 0.4]},
	"devilpress": {"name": "데빌 프레스", "cat": "kb", "taps": 4, "xp": [0.6, 0.1, 0.9, 0.3], "req": {"eng": 2}, "scale": "dbsnatch"},
	"dbthruster": {"name": "덤벨 쓰러스터", "cat": "kb", "taps": 2, "xp": [0.5, 0, 0.6, 0.2]},
	"wallball": {"name": "월볼", "cat": "kb", "taps": 2, "xp": [0.4, 0, 0.7, 0.3]},
	"sandbag": {"name": "샌드백 클린", "cat": "kb", "taps": 2, "xp": [0.7, 0, 0.4, 0.1]},
	"farmer": {"name": "파머스 캐리", "cat": "kb", "taps": 2, "xp": [0.6, 0.1, 0.4, 0], "unit": "x10m"},
	"sled": {"name": "썰매 밀기", "cat": "kb", "taps": 3, "xp": [0.7, 0, 0.7, 0], "unit": "x10m"},
	# ---------- 체조 ----------
	"pullup": {"name": "스트릭트 풀업", "cat": "gym", "rhythm": {"bpm": 70, "pat": "a"}, "xp": [0.3, 1.0, 0.1, 0.2], "anim": "bar"},
	"kippull": {"name": "키핑 풀업", "cat": "gym", "rhythm": {"bpm": 100, "pat": "a"}, "xp": [0.1, 0.8, 0.3, 0.4], "anim": "bar", "req": {"gym": 2}, "scale": "ringrow"},
	"c2b": {"name": "체스트 투 바", "cat": "gym", "rhythm": {"bpm": 95, "pat": "a"}, "xp": [0.2, 1.0, 0.3, 0.4], "anim": "bar", "req": {"gym": 3}, "scale": "kippull"},
	"butterfly": {"name": "버터플라이 풀업", "cat": "gym", "rhythm": {"bpm": 150, "pat": "ab", "each": true}, "xp": [0.1, 0.8, 0.5, 0.6], "anim": "bar", "req": {"gym": 4, "tec": 2}, "scale": "kippull"},
	"k2e": {"name": "니 투 엘보", "cat": "gym", "rhythm": {"bpm": 100, "pat": "ab"}, "xp": [0, 0.6, 0.2, 0.2], "anim": "bar"},
	"t2b": {"name": "토 투 바", "cat": "gym", "rhythm": {"bpm": 110, "pat": "ab"}, "xp": [0, 0.9, 0.3, 0.5], "anim": "bar", "req": {"gym": 2}, "scale": "k2e"},
	"muscleup": {"name": "바 머슬업", "cat": "gym", "rhythm": {"bpm": 110, "pat": "aaA."}, "xp": [0.6, 1.6, 0.2, 1.0], "anim": "bar", "mu": true, "req": {"gym": 5, "str": 3}, "scale": "c2b"},
	"ringmu": {"name": "링 머슬업", "cat": "gym", "rhythm": {"bpm": 95, "pat": "aaA."}, "xp": [0.7, 1.8, 0.2, 1.2], "anim": "bar", "mu": true, "req": {"gym": 6, "str": 4}, "scale": "ringdip"},
	"ringdip": {"name": "링 딥", "cat": "gym", "rhythm": {"bpm": 70, "pat": "a"}, "xp": [0.6, 0.8, 0.1, 0.2], "anim": "floor", "req": {"gym": 2}, "scale": "pushup"},
	"shspu": {"name": "스트릭트 HSPU", "cat": "gym", "rhythm": {"bpm": 60, "pat": "A."}, "xp": [0.6, 1.0, 0.1, 0.4], "anim": "floor", "req": {"gym": 4, "str": 3}, "scale": "pushup"},
	"khspu": {"name": "키핑 HSPU", "cat": "gym", "rhythm": {"bpm": 100, "pat": "ab"}, "xp": [0.3, 1.0, 0.3, 0.6], "anim": "floor", "req": {"gym": 3}, "scale": "pushup"},
	"hswalk": {"name": "핸드스탠드 워크", "cat": "gym", "rhythm": {"bpm": 120, "pat": "abab"}, "xp": [0.2, 1.2, 0.3, 1.0], "anim": "floor", "unit": "x1.5m", "req": {"gym": 5, "tec": 3}, "scale": "pushup"},
	"rope": {"name": "로프 클라임", "cat": "gym", "rhythm": {"bpm": 120, "pat": "abab"}, "xp": [0.6, 1.4, 0.4, 0.6], "anim": "bar", "req": {"gym": 3}, "scale": "ringrow"},
	"leglessrope": {"name": "레그리스 로프", "cat": "gym", "rhythm": {"bpm": 90, "pat": "ABAB"}, "xp": [1.0, 2.0, 0.3, 0.6], "anim": "bar", "req": {"gym": 6, "str": 5}, "scale": "rope"},
	"pistol": {"name": "피스톨 스쿼트", "cat": "gym", "rhythm": {"bpm": 80, "pat": "ab", "each": true}, "xp": [0.5, 0.5, 0.1, 0.6], "anim": "floor", "req": {"tec": 2}, "scale": "airsquat"},
	"ringrow": {"name": "링 로우", "cat": "gym", "taps": 1, "xp": [0.3, 0.4, 0.1, 0]},
	"pushup": {"name": "푸시업", "cat": "gym", "taps": 1, "xp": [0.3, 0.4, 0.2, 0]},
	"situp": {"name": "싯업", "cat": "gym", "taps": 1, "xp": [0, 0.3, 0.3, 0]},
	"ghd": {"name": "GHD 싯업", "cat": "gym", "taps": 2, "xp": [0.1, 0.6, 0.3, 0.1], "req": {"gym": 2}, "scale": "situp"},
	"airsquat": {"name": "에어 스쿼트", "cat": "gym", "taps": 1, "xp": [0.1, 0.1, 0.4, 0.1]},
	# ---------- 카디오 ----------
	"row": {"name": "로잉", "cat": "cardio", "taps": 2, "xp": [0.1, 0, 0.8, 0.1], "unit": "cal"},
	"bike": {"name": "에어바이크", "cat": "cardio", "taps": 2, "xp": [0.1, 0, 1.0, 0], "unit": "cal"},
	"ski": {"name": "스키에르그", "cat": "cardio", "taps": 2, "xp": [0.1, 0.1, 0.8, 0.1], "unit": "cal"},
	"run": {"name": "달리기", "cat": "cardio", "taps": 2, "xp": [0, 0, 0.9, 0.1], "unit": "x50m"},
	"shuttle": {"name": "셔틀런", "cat": "cardio", "taps": 1, "xp": [0, 0, 0.5, 0.1], "unit": "x10m"},
	"su": {"name": "싱글 언더", "cat": "cardio", "taps": 1, "xp": [0, 0, 0.2, 0.1]},
	"du": {"name": "더블 언더", "cat": "cardio", "taps": 1, "xp": [0, 0, 0.4, 0.4], "req": {"eng": 2}, "scale": "su"},
	"tu": {"name": "트리플 언더", "cat": "cardio", "taps": 1, "xp": [0, 0, 0.6, 0.9], "req": {"eng": 4, "tec": 4}, "scale": "du"},
	"boxjump": {"name": "박스 점프", "cat": "cardio", "taps": 2, "xp": [0.2, 0, 0.5, 0.1]},
	"bjo": {"name": "박스 점프 오버", "cat": "cardio", "taps": 2, "xp": [0.2, 0, 0.6, 0.2]},
	"burpee": {"name": "버피", "cat": "cardio", "taps": 3, "xp": [0.1, 0.1, 0.8, 0]},
	"bfb": {"name": "바 페이싱 버피", "cat": "cardio", "taps": 3, "xp": [0.1, 0.1, 0.9, 0.1]},
	"burpeebox": {"name": "버피 박스점프오버", "cat": "cardio", "taps": 4, "xp": [0.2, 0.1, 1.1, 0.1], "req": {"eng": 2}, "scale": "burpee"},
}


static func ids() -> Array:
	return LIST.keys()


static func ids_in(cat: String) -> Array:
	var out := []
	for id in LIST:
		if LIST[id].cat == cat:
			out.append(id)
	return out


static func name_of(id: String) -> String:
	return LIST[id].name


static func is_rhythm(id: String) -> bool:
	return LIST[id].has("rhythm")


static func unit_of(id: String) -> String:
	return LIST[id].get("unit", "회")


## 1회당 XP를 {str, gym, eng, tec} 사전으로.
static func xp_per_rep(id: String) -> Dictionary:
	var arr: Array = LIST[id].xp
	var out := {}
	for i in 4:
		if float(arr[i]) > 0.0:
			out[STAT_KEYS[i]] = float(arr[i])
	return out


## 1회당 에너지 소모. 연타가 많고 패턴이 길수록 힘들다.
static func energy_per_rep(id: String) -> float:
	var m: Dictionary = LIST[id]
	if m.has("rhythm"):
		return 0.3 + 0.12 * String(m.rhythm.pat).replace(".", "").length()
	return 0.15 + 0.15 * int(m.taps)


## 아무것도 안 정했을 때 기본 횟수.
static func default_reps(id: String) -> int:
	if is_rhythm(id):
		return clampi(4 + GameState.level("gym"), 5, 15)
	return 10


static func unlocked(id: String) -> bool:
	var req: Dictionary = LIST[id].get("req", {})
	for s in req:
		if GameState.level(s) < int(req[s]):
			return false
	return true


static func req_text(id: String) -> String:
	var req: Dictionary = LIST[id].get("req", {})
	var parts := []
	for s in req:
		parts.append("%s Lv.%d" % [GameState.STAT_NAMES[s], req[s]])
	return "해금: " + ", ".join(parts)


## 잠긴 동작은 해금된 스케일 동작이 나올 때까지 내려간다 (실제 크로스핏처럼).
static func scaled(id: String) -> String:
	var cur := id
	for i in 5:
		if unlocked(cur):
			return cur
		cur = LIST[cur].get("scale", cur)
	return cur


## 메뉴 설명: XP 분배와 보너스 표시.
static func describe(id: String) -> String:
	var parts := []
	var xp := xp_per_rep(id)
	for s in STAT_KEYS:
		if xp.has(s):
			parts.append("%s %s" % [GameState.STAT_NAMES[s], Pal.num(snappedf(xp[s], 0.1))])
	var line2 := ""
	if not unlocked(id):
		line2 = req_text(id) + " (스케일: %s)" % name_of(scaled(id))
	else:
		line2 = GameState.variety_label(id)
	return "1회당 " + " ".join(parts) + "\n" + line2
