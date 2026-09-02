class_name SpiritData
extends Resource
## 가택신. data/csv/spirits.csv 한 행 = 이 리소스 하나.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var name_ko: String = ""
@export var role_ko: String = ""
## 상주 시설 room id. 빈 문자열이면 집 전체(성주).
@export var room_id: String = ""
