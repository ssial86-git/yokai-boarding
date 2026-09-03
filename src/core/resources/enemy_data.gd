class_name EnemyData
extends Resource
## 마계 적. data/csv/enemies.csv 한 행 = 이 리소스 하나. 전투는 동료 요괴가 자동 수행한다 (docs/01 2.1).
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var name_ko: String = ""
## normal / boss(미니보스)
@export var tier: String = "normal"
@export var hp: int = 1
@export var attack: int = 1
@export var speed_px: float = 30.0
## 이 반경 안의 플레이어·동료에게 달려든다
@export var aggro_radius_px: int = 64
## 쓰러뜨리면 떨어지는 재료 (materials.csv). 비어 있으면 없음
@export var drop_material: String = ""
@export var drop_chance: float = 0.0
## 16 / 32
@export var sprite_size: int = 32
