class_name ChainData
extends Resource
## 콘텐츠 용도 사슬 (docs/08 재미 원칙 3 "한 행동은 세 갈래 이상"). data/csv/chains.csv 한 행 = 이 리소스 하나.
## use1~3 이 전부 차야 빌드가 통과한다 — 검증은 build_resources.py 가 한다. 손으로 편집하지 않는다.

## = content_id (파일명 키)
@export var id: String = ""
## material / crop / talisman / fish / recipe
@export var content_type: String = "material"
@export var content_id: String = ""
## "kind:detail" — kind: cook / craft / sell / gift / buff / quest / feed / bait / decor / combat / gather / travel / upgrade / event
@export var use1: String = ""
@export var use2: String = ""
@export var use3: String = ""
