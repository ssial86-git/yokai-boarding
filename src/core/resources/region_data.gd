class_name RegionData
extends Resource
## 탐험지·야외 구역 (마당·뒷산·개울·우물·마계 지역). data/csv/regions.csv 한 행 = 이 리소스 하나.
## 씬은 이 데이터로 조립한다 (CLAUDE.md 5.7 — 수제 씬 하드코딩 금지). build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var name_ko: String = ""
## mortal(이승) / demon(마계)
@export var realm: String = "mortal"
## yard(마당) / wild(뒷산·개울) / gate(관문) / expedition(마계 탐험지)
@export var kind: String = "wild"
## 상위 구역 id (잿빛 들 심부 → 잿빛 들). 비어 있으면 최상위
@export var parent_id: String = ""
@export var gather_point_count: int = 0
## 채집 포인트에 나오는 재료 id 목록 (materials.csv)
@export var gather_pool: Array = []
## 스포너가 뽑는 적 id 목록 (enemies.csv)
@export var enemy_pool: Array = []
## 미니보스 id (enemies.csv, tier=boss). 비어 있으면 없음
@export var boss_id: String = ""
## 들어갈 때 드는 스태미너
@export var stamina_enter_cost: int = 0
## P1 에 실제로 등장하는 구역인지 (false 면 스키마·케이던스 검증용 자리)
@export var in_p1: bool = true
