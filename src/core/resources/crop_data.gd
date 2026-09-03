class_name CropData
extends Resource
## 텃밭 작물. data/csv/crops.csv 한 행 = 이 리소스 하나. 씨앗·수확물은 items.csv 의 아이템이다.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var name_ko: String = ""
## mortal(이승) / demon(마계)
@export var realm: String = "mortal"
@export var seed_item: String = ""
@export var harvest_item: String = ""
@export var grow_days: int = 3
## 하루에 물을 줘야 하는 횟수 (0 이면 물 없이 자람)
@export var water_per_day: int = 1
@export var yield_min: int = 1
@export var yield_max: int = 1
## 음기 짙은 날 성장 가속 배율 보너스 (마계 작물용, 0 이면 없음)
@export var yin_growth_bonus: float = 0.0
## any / spring / summer / autumn / winter
@export var season: String = "any"
