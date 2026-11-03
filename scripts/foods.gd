class_name Foods
extends RefCounted
## 메뉴판. g: 게이지 변화(food/energy/mood/cond), xp: 능력치 XP 변화(str/gym/eng/tec)
## 건강식은 능력치를 고르게 올려주고, 일반식(치팅)은 기분은 크게 오르지만 능력치가 떨어진다.

const CHEAT_LIMIT := 2  # 하루에 이 횟수를 넘기면 치팅 페널티가 커진다

const HEALTHY := {
	"chicken": {"name": "닭가슴살", "g": {"food": 30, "cond": 3}, "xp": {"str": 3}, "say": "퍽퍽하지만 근육이 좋아해요!"},
	"steak": {"name": "소고기 스테이크", "g": {"food": 35, "energy": 5, "mood": 5}, "xp": {"str": 5}, "say": "육즙 가득! 힘이 솟아요!"},
	"salmon": {"name": "연어 포케", "g": {"food": 28, "cond": 8}, "xp": {"tec": 3, "gym": 1}, "say": "오메가3로 몸이 가벼워요."},
	"eggs": {"name": "삶은 계란", "g": {"food": 20, "cond": 4}, "xp": {"gym": 3}, "say": "계란 두 알 꿀꺽!"},
	"shake": {"name": "단백질 쉐이크", "g": {"food": 15, "energy": 5}, "xp": {"str": 2, "gym": 2}, "say": "초코맛 쉐이크 꿀꺽!"},
	"potato": {"name": "고구마", "g": {"food": 25, "energy": 10}, "xp": {"eng": 3}, "say": "달달한 고구마 최고!"},
	"oatmeal": {"name": "오트밀 바나나", "g": {"food": 22, "energy": 12}, "xp": {"eng": 2, "tec": 1}, "say": "든든한 아침 탄수화물!"},
	"yogurt": {"name": "그릭요거트 베리", "g": {"food": 15, "cond": 6, "mood": 3}, "xp": {"gym": 2, "tec": 1}, "say": "새콤달콤 상큼해요."},
	"poke": {"name": "현미 닭가슴살 덮밥", "g": {"food": 32, "energy": 6}, "xp": {"str": 1, "gym": 1, "eng": 1, "tec": 1}, "say": "밸런스 완벽한 한 끼!"},
	"electrolyte": {"name": "전해질 음료", "g": {"food": 5, "energy": 8, "cond": 5}, "xp": {"eng": 2}, "say": "땀 흘린 뒤엔 이거죠!"},
}

const CHEAT := {
	"fried": {"name": "후라이드 치킨", "g": {"food": 35, "mood": 20, "energy": -5}, "xp": {"str": -2, "eng": -3}, "say": "치킨은 못 참지!"},
	"pizza": {"name": "피자", "g": {"food": 35, "mood": 18}, "xp": {"gym": -3, "eng": -2}, "say": "치즈 쭉~ 행복해요!"},
	"ramen": {"name": "라면", "g": {"food": 30, "mood": 12, "cond": -5}, "xp": {"eng": -2, "tec": -1}, "say": "밤에 먹는 라면이 최고..."},
	"tteok": {"name": "떡볶이", "g": {"food": 25, "mood": 18}, "xp": {"gym": -2, "eng": -1}, "say": "매콤달콤 떡볶이!"},
	"burger": {"name": "햄버거 세트", "g": {"food": 35, "mood": 15, "energy": -3}, "xp": {"eng": -3, "gym": -1}, "say": "콜라까지 완벽해요!"},
	"malatang": {"name": "마라탕", "g": {"food": 30, "mood": 16, "cond": -3}, "xp": {"tec": -2, "eng": -1}, "say": "얼얼하다! 맛있다!"},
	"samgyeop": {"name": "삼겹살", "g": {"food": 35, "mood": 15}, "xp": {"str": 1, "gym": -3, "eng": -2}, "say": "지글지글~ 고기 파티!"},
	"icecream": {"name": "아이스크림", "g": {"food": 10, "mood": 15}, "xp": {"gym": -1, "eng": -1}, "say": "시원~ 달콤해요."},
}

const GAUGE_SHORT := {"food": "밥", "energy": "힘", "mood": "기분", "cond": "몸"}


static func get_food(id: String) -> Dictionary:
	if HEALTHY.has(id):
		return HEALTHY[id]
	return CHEAT[id]


static func is_cheat(id: String) -> bool:
	return CHEAT.has(id)


## 메뉴 아래에 보여줄 효과 요약. 예) "밥+30 몸+3 / 근력+3"
static func describe(id: String) -> String:
	var f := get_food(id)
	var parts := []
	for k in f.g:
		parts.append("%s%+d" % [GAUGE_SHORT[k], int(f.g[k])])
	var stats := []
	for k in f.xp:
		stats.append("%s%+d" % [GameState.STAT_NAMES[k], int(f.xp[k])])
	return " ".join(parts) + "\n" + " ".join(stats)
