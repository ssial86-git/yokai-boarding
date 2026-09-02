class_name YokaiData
extends Resource
## 장기 하숙생 1명의 정적 데이터. data/csv/yokai.csv 한 행 = 이 리소스 하나.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var name_ko: String = ""
@export var species_ko: String = ""
## rooms.csv 의 id. 이 방에 배치되면 work_bonus 가 적용된다.
@export var preferred_room: String = ""
@export var work_bonus: float = 0.0
## 0(무음)~3(옆방 수면 방해). 배치 퍼즐 제약.
@export var noise: int = 0
@export var night_worker: bool = false
## money / items / errand / none
@export var rent_type: String = "none"
@export var rent_note_ko: String = ""
## items 형: 아이템 id 또는 "kind:<item_kind>"(그 종류에서 무작위). 그 외 형: 빈 문자열.
@export var rent_item: String = ""
## money: 금액 / items: 개수 / errand: 모두의 컨디션 회복량
@export var rent_amount: int = 0
## 며칠마다 지불하는가 (1 = 매일)
@export var rent_interval_days: int = 1
## start = 새 게임부터 입주 / intake = join_day 저녁에 '빈 카드' 방문자로 도착
@export var join_mode: String = "start"
@export var join_day: int = 0
@export var stat_strength: int = 0
@export var stat_skill: int = 0
@export var stat_sight: int = 0
@export var stat_courage: int = 0
## 32 또는 16. 스프라이트 규격(px).
@export var sprite_size: int = 32
## true 면 호감도가 낮을수록 흐리게 그린다 (어둑이 — '관심받으면 또렷해짐')
@export var clarity_by_affinity: bool = false
@export var in_slice: bool = false
