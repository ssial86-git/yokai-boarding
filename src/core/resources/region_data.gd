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
# --- 레이아웃 (P1-S2). RegionLayout 이 푼다. house 는 방 그리드에서 계산한다 ---
@export var width_px: int = 0
## 바닥 구간 "x0:x1:y" 목록 (y 는 기준 바닥 0 에서의 오프셋, 위가 음수)
@export var ground: Array = []
## 문 "region_id:x" 목록
@export var doors: Array = []
## 채집 포인트가 놓이는 x 범위 "x0:x1"
@export var gather_span: String = ""
## 텃밭 첫 칸 x (yard)
@export var farm_x: int = 0
## 배경색 hex (팔레트)
@export var sky_color: String = "8fb0b8"
## 낚시 자리 x (0 = 없음). fish.csv 에서 region_id 가 이 구역인 어종이 낚인다
@export var fishing_x: int = 0
## 들어갈 때 enemy_pool 에서 뽑아 놓는 적 수 (탐험지, 미니보스 제외)
@export var enemy_count: int = 0
## 회색 장꾼 NPC 자리 x (0 = 없음). P2-S3
@export var merchant_x: int = 0
# --- 밤 변형 (P2-S4). 채집 풀이 비면 변형 없음. DataRegistry 가 "<id>@night" 로 파생 리소스를 만든다 ---
@export var night_gather_pool: Array = []
@export var night_enemy_pool: Array = []
@export var night_enemy_count: int = 0
@export var night_sky_color: String = ""
