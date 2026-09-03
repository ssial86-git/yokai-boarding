class_name FestivalData
extends Resource
## 명절. data/csv/festivals.csv 한 행 = 이 리소스 하나 (P2-S2 동지). 준비 목표·당일 채점·보상이 전부 데이터.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var name_ko: String = ""
## 절기 id 와 절기 안 날짜
@export var season: String = "spring"
@export var day_of_season: int = 28
## 당일 저녁에 나누는 요리(recipes.csv)와 나눌 그릇 수 상한
@export var dish_recipe: String = ""
@export var dish_target: int = 0
## 채점에 세는 손님 수 상한
@export var guest_target: int = 0
## 준비 목표(goals.csv id 목록)
@export var goal_ids: Array[String] = []
@export var score_per_goal: int = 1
@export var score_per_guest: int = 1
@export var score_per_dish: int = 1
@export var reward_money: int = 0
@export var reward_reputation: int = 0
## 만점이면 추가 평판과 그날 밤 찾아오는 희귀 손님 종족
@export var perfect_reward_reputation: int = 0
@export var rare_guest_species: String = ""
## 이 목표가 충족돼 있으면 당일 집에 장식이 걸린다 (goals.csv id)
@export var decor_goal: String = ""
@export var hint_ko: String = ""
