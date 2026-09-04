class_name ChapterData
extends Resource
## 챕터. data/csv/chapters.csv 한 행 = 이 리소스 하나 (P2-S4 챕터 1). 게이트는 병렬 목표(goals.csv) 중 일부 충족.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var order: int = 1
@export var name_ko: String = ""
## 게이트 목표(goals.csv id 목록). 이 중 gate_required 개가 완료되면 다음 챕터
@export var gate_goals: Array[String] = []
@export var gate_required: int = 0
## 다음 챕터 id (비우면 마지막)
@export var next_id: String = ""
@export var summary_ko: String = ""
