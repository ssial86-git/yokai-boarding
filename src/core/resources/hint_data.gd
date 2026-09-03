class_name HintData
extends Resource
## 상황별 안내 문구 (성주 영감 튜토리얼). data/csv/hints.csv 한 행 = 이 리소스 하나.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
## 시간대: morning / day / evening / night / any
@export var timeband: String = "any"
@export var day_min: int = 1
## 0 이면 상한 없음
@export var day_max: int = 0
@export var requires_flag: String = ""
## 이 플래그가 서면 더는 보이지 않는다
@export var blocked_by_flag: String = ""
@export var priority: int = 0
@export var text_ko: String = ""
