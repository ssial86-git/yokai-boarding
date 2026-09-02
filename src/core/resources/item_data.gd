class_name ItemData
extends Resource
## 재화·재료. data/csv/items.csv 한 행 = 이 리소스 하나.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var name_ko: String = ""
## food / material / misc / key
@export var kind: String = "misc"
## 기준 가치 (M3 경제에서 판매·하숙비 환산에 사용)
@export var base_value: int = 0
