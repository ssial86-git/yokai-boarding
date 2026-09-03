class_name SeasonData
extends Resource
## 절기. data/csv/seasons.csv 한 행 = 이 리소스 하나 (P2-S1). 4절기 × 28일이 기본이고 P2 는 봄 한 절기 순환까지.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var name_ko: String = ""
## 1(봄)~4(겨울). 시작 절기를 찾을 때 가장 작은 값을 쓴다
@export var order: int = 1
@export var length_days: int = 28
## 이 절기가 끝나면 이어지는 절기 id
@export var next_id: String = ""
