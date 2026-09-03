class_name SynergyData
extends Resource
## 가호 시너지(+)·간섭(−). data/csv/synergies.csv 한 행 = 이 리소스 하나 (P2-S3).
## context_kind: yokai(요리를 먹는 하숙생) / talisman_effect(부적 갈래) / crop_realm(씨앗의 작물 갈래) / recipe_stat(요리 버프 능력치)
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var blessing_id: String = ""
@export var context_kind: String = ""
@export var context_id: String = ""
## 효과에 더하는 값 (음수 = 간섭)
@export var delta: int = 0
@export var note_ko: String = ""
