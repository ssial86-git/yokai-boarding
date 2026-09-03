class_name FishData
extends Resource
## 낚시 결과(어종·고물). data/csv/fish.csv 한 행 = 이 리소스 하나. id 는 items.csv 에도 있어야 한다.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var name_ko: String = ""
## fish / junk(고물)
@export var kind: String = "fish"
## 낚이는 지역 (regions.csv)
@export var region_id: String = ""
## 추첨 가중치
@export var weight: int = 1
## morning / day / evening / night / any
@export var timeband: String = "any"
@export var min_rod_level: int = 1
## 낚이면 아이템 대신 그날 밤 이 종족(guest_species.csv)이 문을 두드린다. 비우면 보통 어종 (P2-S3)
@export var visitor_species: String = ""
