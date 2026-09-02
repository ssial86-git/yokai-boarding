class_name GuestSpeciesData
extends Resource
## 뜨내기 손님 종족. data/csv/guest_species.csv 한 행 = 이 리소스 하나.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var name_ko: String = ""
## common / uncommon / rare
@export var rarity: String = "common"
@export var flavor_ko: String = ""
## 심사 카드의 첫마디
@export var first_words_ko: String = ""
## money / items / buff / info / none — 기본 숙박비(rent_money)에 더해지는 특이 하숙비 종류
@export var rent_type: String = "none"
@export var rent_note_ko: String = ""
## 체크아웃 때 내는 기본 숙박비
@export var rent_money: int = 0
## items 형 특이 하숙비 아이템 id
@export var rent_item: String = ""
## items: 개수 / buff: 모두의 컨디션 회복량
@export var rent_amount: int = 0
## 문돌이의 감(액운 냄새) 기본값 0~3. 방문자 유형의 범위와 합산되지 않고 큰 쪽을 쓴다.
@export var omen: int = 0
## 등장 조건 키. 빈 문자열이면 무조건. 예: rain
@export var appear_condition: String = ""
## 방문자 추첨 가중치.
@export var weight: int = 1
@export var promotable: bool = false
## 32 또는 16. 소형종은 16 허용.
@export var sprite_size: int = 32
