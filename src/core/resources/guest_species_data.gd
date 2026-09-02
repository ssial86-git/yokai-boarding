class_name GuestSpeciesData
extends Resource
## 뜨내기 손님 종족. data/csv/guest_species.csv 한 행 = 이 리소스 하나.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var name_ko: String = ""
## common / uncommon / rare
@export var rarity: String = "common"
@export var flavor_ko: String = ""
## money / items / buff / info / none
@export var rent_type: String = "none"
@export var rent_note_ko: String = ""
## 등장 조건 키. 빈 문자열이면 무조건. 예: rain
@export var appear_condition: String = ""
## 방문자 추첨 가중치.
@export var weight: int = 1
@export var promotable: bool = false
## 32 또는 16. 소형종은 16 허용.
@export var sprite_size: int = 32
