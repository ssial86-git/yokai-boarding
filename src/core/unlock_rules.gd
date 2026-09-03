class_name UnlockRules
extends RefCounted
## unlocks.csv 조건 평가 (docs/08 재미 원칙 6). 조건식 문법은 build_resources.py 가 검증한다:
##   flag:<name> / affinity:<yokai>>=<n> / unlock:<id> / resident:<yokai> / item:<item>>=<n>  (세미콜론 AND)
## 순수 로직 — 열린 것을 GameState 에 쓰고 알리는 일은 UnlockSystem 이 한다.

const TIMEBAND_ANY := "any"
const SEPARATOR := ";"
const GE := ">="


class Context:
	extends RefCounted
	var day: int = 1
	var timeband: String = "morning"
	var flags: Dictionary = {}
	var affinity: Dictionary = {}
	var residents: Array[String] = []
	var inventory: Inventory = Inventory.new()
	## 이미 열린 unlock id -> 열린 날
	var unlocked: Dictionary = {}


static func condition_holds(condition: String, ctx: Context) -> bool:
	for part in condition.split(SEPARATOR, false):
		var clause := part.strip_edges()
		if clause.is_empty():
			continue
		var name := clause.get_slice(":", 0)
		var rest := clause.substr(name.length() + 1)
		var target := rest.get_slice(GE, 0)
		var amount := int(rest.get_slice(GE, 1)) if rest.contains(GE) else 0
		match name:
			"flag":
				if not ctx.flags.has(target):
					return false
			"affinity":
				if int(ctx.affinity.get(target, 0)) < amount:
					return false
			"unlock":
				if not ctx.unlocked.has(target):
					return false
			"resident":
				if not ctx.residents.has(target):
					return false
			"item":
				if ctx.inventory.get_count(target) < amount:
					return false
			_:
				return false
	return true


static func is_satisfied(unlock: UnlockData, ctx: Context) -> bool:
	if ctx.unlocked.has(unlock.id):
		return false
	if ctx.day < unlock.day_min:
		return false
	if unlock.timeband != TIMEBAND_ANY and unlock.timeband != ctx.timeband:
		return false
	return condition_holds(unlock.condition, ctx)


## 지금 새로 열리는 것들을 expected_day, day_min, id 순으로. 같은 평가 안에서 앞서 열린 것을 조건으로 거는 행도 이어서 열린다.
static func newly_satisfied(unlocks: Dictionary, ctx: Context) -> Array[UnlockData]:
	var ordered: Array[UnlockData] = []
	for unlock: UnlockData in unlocks.values():
		ordered.append(unlock)
	ordered.sort_custom(func(a: UnlockData, b: UnlockData) -> bool:
		if a.expected_day != b.expected_day:
			return a.expected_day < b.expected_day
		if a.day_min != b.day_min:
			return a.day_min < b.day_min
		return a.id < b.id)
	var result: Array[UnlockData] = []
	var opened := ctx.unlocked.duplicate()
	var progressed := true
	while progressed:
		progressed = false
		for unlock in ordered:
			if opened.has(unlock.id):
				continue
			var probe := ctx
			var saved := ctx.unlocked
			probe.unlocked = opened
			var ok := is_satisfied(unlock, probe)
			probe.unlocked = saved
			if ok:
				opened[unlock.id] = ctx.day
				result.append(unlock)
				progressed = true
	return result
