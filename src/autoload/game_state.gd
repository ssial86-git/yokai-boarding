extends Node
## 런타임 진행 상태의 단일 소유자. 규칙 계산은 src/core/ 순수 클래스가 하고
## 여기서는 상태를 들고 있다가 시그널로 알린다.

var day: int = 1
var money: int = 0
var reputation: int = 0
## yokai_id -> affinity 값
var affinity: Dictionary = {}
## 입주 중인 하숙생 id 목록
var residents: Array[String] = []


func reset_new_game() -> void:
	day = 1
	money = DataRegistry.tuning.get_int("start_money")
	reputation = 0
	affinity.clear()
	residents.clear()


func add_money(amount: int) -> void:
	money += amount
	Events.money_changed.emit(money)


func to_dict() -> Dictionary:
	return {
		"day": day,
		"money": money,
		"reputation": reputation,
		"affinity": affinity.duplicate(),
		"residents": residents.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	money = int(data.get("money", 0))
	reputation = int(data.get("reputation", 0))
	affinity = (data.get("affinity", {}) as Dictionary).duplicate()
	residents.clear()
	for entry: Variant in (data.get("residents", []) as Array):
		residents.append(str(entry))
