class_name ToolData
extends Resource
## 도구 갈래·레벨. data/csv/tools.csv 한 행 = 이 리소스 하나 (id 예: axe_1).
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
## hoe(괭이) / axe(도끼) / pickaxe(곡괭이) / rod(낚싯대)
@export var kind: String = "hoe"
@export var level: int = 1
@export var name_ko: String = ""
## 한 번 휘두를 때 스태미너 소모
@export var stamina_cost: int = 1
## 채집·경작 위력 (재료 min_tool_level 과 비교)
@export var power: int = 1
## 이 레벨로 올리는 데 드는 재료 "item_id:n" 목록. 비어 있으면 시작 도구
@export var upgrade_cost: Array = []
## 이전 레벨 도구 id. 비어 있으면 시작 도구
@export var upgrade_from: String = ""
