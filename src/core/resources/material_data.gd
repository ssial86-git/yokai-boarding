class_name MaterialData
extends Resource
## 채집·채광·벌목·전리품 재료. data/csv/materials.csv 한 행 = 이 리소스 하나. id 는 items.csv 에도 있어야 한다(인벤토리 공용).
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var name_ko: String = ""
## mortal(이승) / demon(마계) / both
@export var realm: String = "mortal"
## gather / chop / mine / drop / fish / farm / craft
@export var source: String = "gather"
## none / axe / pickaxe / hoe / rod — 채집에 필요한 도구 갈래
@export var tool_kind: String = "none"
@export var min_tool_level: int = 0
## any / spring / summer / autumn / winter (P1 은 봄 고정, P2 절기용 자리)
@export var season: String = "any"
## any / low / high — 음기 지수 조건 (원칙 4: 음기 짙은 날의 다른 기회)
@export var yin_condition: String = "any"
## common / uncommon / rare
@export var rarity: String = "common"
