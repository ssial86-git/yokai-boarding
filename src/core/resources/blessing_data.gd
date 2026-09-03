class_name BlessingData
extends Resource
## 하숙생의 가호. data/csv/blessings.csv 한 행 = 이 리소스 하나 (P2-S3). 씨앗·요리·부적에 붙는다.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var yokai_id: String = ""
@export var name_ko: String = ""
## 가호가 붙은 아이템 이름 앞에 붙는 짧은 표시
@export var short_ko: String = ""
## 붙여 주는 데 필요한 호감도
@export var affinity_min: int = 1
## 대상 종류별 기본 효과 (시너지·간섭은 synergies.csv)
@export var seed_yield_bonus: int = 0
@export var dish_buff_bonus: int = 0
@export var talisman_power_bonus: int = 0
@export var flavor_ko: String = ""
