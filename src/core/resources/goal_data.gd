class_name GoalData
extends Resource
## 목표(할 일). data/csv/goals.csv 한 행 = 이 리소스 하나 (P2-S2 목표 층위 3: 오늘 / 이번 절기 / 장기).
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
## today / season / long
@export var tier: String = "today"
@export var name_ko: String = ""
## 조건식 (세미콜론 AND). 문법은 GoalRules 참조
@export var condition: String = ""
## 보이는 날 창. day_max 0 = 만료 없음
@export var day_min: int = 1
@export var day_max: int = 0
## 명절 준비 목표면 festivals.csv id
@export var festival_id: String = ""
@export var reward_money: int = 0
@export var reward_reputation: int = 0
@export var hint_ko: String = ""
