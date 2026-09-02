class_name DialogueData
extends Resource
## 대화 하나(노드 그래프). data/csv/dialogue.csv 의 dialogue_id 별 행 묶음 = 이 리소스 하나.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
## 노드 Dictionary 목록: node, speaker, text_ko, portrait, next, option1_ko, option1_next, option2_ko, option2_next, effect
@export var nodes: Array = []
