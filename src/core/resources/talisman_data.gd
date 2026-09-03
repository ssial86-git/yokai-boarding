class_name TalismanData
extends Resource
## 부적. data/csv/talismans.csv 한 행 = 이 리소스 하나. id 는 items.csv 에도 있어야 한다(제작·소지 공용).
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var name_ko: String = ""
## throw(투척) / gather(채집) / return(귀환)
@export var effect: String = "throw"
@export var cooldown_seconds: float = 1.0
## 효과 강도 (투척 피해, 채집 배율 %, 귀환은 미사용)
@export var power: int = 1
@export var range_px: int = 0
## 제작 재료 "item_id:n" 목록
@export var craft_cost: Array = []
@export var craft_seconds: float = 0.0
