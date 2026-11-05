class_name Shop
extends RefCounted
## 꾸미기 상점 목록. 코인으로 사고, 칸(slot)마다 하나씩 착용한다.
## wear: 캐릭터에 입히는 것 (style에 합쳐진다) / room: 홈 박스 배경

# id: {name, price, tab, slot, style 또는 room}
const ITEMS := {
	"band_red": {"name": "빨간 헤어밴드", "price": 30, "tab": "wear", "slot": "head", "style": {"headband": "ff6f7f"}},
	"band_blue": {"name": "파란 헤어밴드", "price": 30, "tab": "wear", "slot": "head", "style": {"headband": "6aa8f0"}},
	"band_gold": {"name": "금색 헤어밴드", "price": 60, "tab": "wear", "slot": "head", "style": {"headband": "ffcf4a"}},
	"cap_navy": {"name": "남색 캡모자", "price": 80, "tab": "wear", "slot": "head", "style": {"cap": "3b4a7a"}},
	"cap_pink": {"name": "분홍 캡모자", "price": 80, "tab": "wear", "slot": "head", "style": {"cap": "ff9db0"}},
	"glasses": {"name": "동그란 안경", "price": 50, "tab": "wear", "slot": "eyes", "style": {"glasses": true}},
	"shades": {"name": "선글라스", "price": 90, "tab": "wear", "slot": "eyes", "style": {"shades": true}},
	"shoe_red": {"name": "빨간 리프팅화", "price": 60, "tab": "wear", "slot": "shoes", "style": {"shoe": "ff6f7f"}},
	"shoe_black": {"name": "검정 운동화", "price": 40, "tab": "wear", "slot": "shoes", "style": {"shoe": "3a3a4a"}},
	"shoe_gold": {"name": "황금 운동화", "price": 150, "tab": "wear", "slot": "shoes", "style": {"shoe": "ffcf4a"}},
	"wrist": {"name": "손목밴드", "price": 30, "tab": "wear", "slot": "wrist", "style": {"wrist": true}},
	"sleeves": {"name": "니슬리브", "price": 50, "tab": "wear", "slot": "legs", "style": {"sleeves": true}},
	"belt": {"name": "리프팅 벨트", "price": 70, "tab": "wear", "slot": "waist", "style": {"belt": true}},
	"logo_star": {"name": "별 티셔츠", "price": 40, "tab": "wear", "slot": "logo", "style": {"logo": "star"}},
	"logo_bolt": {"name": "번개 티셔츠", "price": 40, "tab": "wear", "slot": "logo", "style": {"logo": "bolt"}},
	"wall_mint": {"name": "민트 벽지", "price": 60, "tab": "room", "slot": "wall", "room": {"wall": "e6f7f1"}},
	"wall_pink": {"name": "핑크 벽지", "price": 60, "tab": "room", "slot": "wall", "room": {"wall": "fdeaf0"}},
	"wall_sky": {"name": "하늘 벽지", "price": 60, "tab": "room", "slot": "wall", "room": {"wall": "e8f2fd"}},
	"mat_pink": {"name": "핑크 매트", "price": 40, "tab": "room", "slot": "mat", "room": {"mat": "ffc2d1"}},
	"mat_purple": {"name": "라벤더 매트", "price": 40, "tab": "room", "slot": "mat", "room": {"mat": "cbb8f5"}},
	"poster_cf": {"name": "크로스핏 포스터", "price": 50, "tab": "room", "slot": "poster", "room": {"poster": "cf"}},
	"poster_cat": {"name": "고양이 포스터", "price": 50, "tab": "room", "slot": "poster", "room": {"poster": "cat"}},
	"trophy": {"name": "트로피", "price": 120, "tab": "room", "slot": "deco", "room": {"deco": "trophy"}},
	"bear": {"name": "곰돌이 인형", "price": 90, "tab": "room", "slot": "deco", "room": {"deco": "bear"}},
	"plant_big": {"name": "큰 화분", "price": 70, "tab": "room", "slot": "deco", "room": {"deco": "plant"}},
}


static func ids_in(tab: String) -> Array:
	var out := []
	for id in ITEMS:
		if ITEMS[id].tab == tab:
			out.append(id)
	return out
