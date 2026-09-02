class_name EventData
extends Resource
## 사연·튜토리얼 이벤트 트리거. data/csv/events.csv 한 행 = 이 리소스 하나.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
## tutorial / story / arrival
@export var kind: String = "story"
## 사연 주인 하숙생. 빈 문자열이면 요괴 조건 없음.
@export var yokai_id: String = ""
## morning / day / evening / night / any
@export var phase: String = "night"
@export var day_min: int = 1
## 0 이면 상한 없음
@export var day_max: int = 0
@export var min_affinity: int = 0
@export var requires_item: String = ""
@export var requires_flag: String = ""
@export var once: bool = true
@export var priority: int = 0
@export var dialogue_id: String = ""
@export var title_ko: String = ""
