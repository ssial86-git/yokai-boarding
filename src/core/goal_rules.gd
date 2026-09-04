class_name GoalRules
extends RefCounted
## goals.csv 조건 평가 (P2-S2 목표 층위 3). 문법(세미콜론 AND), build_resources.py 가 검증한다:
##   item:<id>>=n / count:<key>>=n / ledger>=n / species>=n / residents>=n / rooms:<room>>=n / floors>=n / beds>=n / money>=n / reputation>=n
##   affinity:<yokai>>=n / festival:<id>>=n / resident:<yokai> / unlock:<id> / flag:<name>
## 순수 로직 — 완료 기록·보상·알림은 GoalSystem 이 한다.

const SEPARATOR := ";"
const GE := ">="
const TIER_TODAY := "today"
const TIER_SEASON := "season"
const TIER_LONG := "long"
const TIERS: Array[String] = [TIER_TODAY, TIER_SEASON, TIER_LONG]
const NO_EXPIRY := 0
## 정량 절이 아닌 절(resident/unlock/flag)의 목표값
const BOOL_TARGET := 1


class Context:
	extends RefCounted
	var day: int = 1
	var inventory: Inventory = Inventory.new()
	## 활동 카운터: "gather" / "cook.r_patjuk" 같은 키 -> 누계 (GameState.counters)
	var counters: Dictionary = {}
	## species_id -> 방문 횟수
	var ledger: Dictionary = {}
	var room_grid: RoomGrid = null
	var beds: int = 0
	var affinity: Dictionary = {}
	var residents: Array[String] = []
	var unlocked: Dictionary = {}
	var flags: Dictionary = {}
	var money: int = 0
	var reputation: int = 0
	## festival_id -> 점수
	var festival_results: Dictionary = {}


class Clause:
	extends RefCounted
	var name: String = ""
	var target: String = ""
	var amount: int = BOOL_TARGET
	var quantitative: bool = false


## "count:gather>=5" / "ledger>=5" / "resident:y01" 을 절로 나눈다.
static func parse_clause(text: String) -> Clause:
	var clause := Clause.new()
	var trimmed := text.strip_edges()
	var ge_index := trimmed.find(GE)
	var colon := trimmed.find(":")
	var rest := ""
	if colon >= 0 and (ge_index < 0 or colon < ge_index):
		clause.name = trimmed.substr(0, colon)
		rest = trimmed.substr(colon + 1)
	else:
		clause.name = trimmed.substr(0, ge_index) if ge_index >= 0 else trimmed
		rest = trimmed.substr(ge_index) if ge_index >= 0 else ""
	if rest.contains(GE):
		clause.target = rest.get_slice(GE, 0)
		clause.amount = int(rest.get_slice(GE, 1))
		clause.quantitative = true
	else:
		clause.target = rest
	return clause


## 절의 현재 값. 불리언 절은 1/0.
static func current_value(clause: Clause, ctx: Context) -> int:
	match clause.name:
		"item":
			return ctx.inventory.get_count(clause.target)
		"count":
			return int(ctx.counters.get(clause.target, 0))
		"ledger":
			var total := 0
			for species_id: Variant in ctx.ledger:
				total += int(ctx.ledger[species_id])
			return total
		"species":
			return ctx.ledger.size()
		"residents":
			return ctx.residents.size()
		"rooms":
			return ctx.room_grid.count_rooms(clause.target) if ctx.room_grid != null else 0
		"floors":
			return ctx.room_grid.built_floors if ctx.room_grid != null else 0
		"beds":
			return ctx.beds
		"money":
			return ctx.money
		"reputation":
			return ctx.reputation
		"affinity":
			return int(ctx.affinity.get(clause.target, 0))
		"festival":
			return int(ctx.festival_results.get(clause.target, 0))
		"resident":
			return 1 if ctx.residents.has(clause.target) else 0
		"unlock":
			return 1 if ctx.unlocked.has(clause.target) else 0
		"flag":
			return 1 if ctx.flags.has(clause.target) else 0
	return 0


static func clause_holds(clause: Clause, ctx: Context) -> bool:
	return current_value(clause, ctx) >= clause.amount


static func condition_holds(condition: String, ctx: Context) -> bool:
	for part in condition.split(SEPARATOR, false):
		if part.strip_edges().is_empty():
			continue
		if not clause_holds(parse_clause(part), ctx):
			return false
	return true


## 진행도 (현재, 목표): 첫 정량 절의 값·목표. 정량 절이 없으면 (충족 절 수, 절 수).
static func progress(condition: String, ctx: Context) -> Vector2i:
	var clauses: Array[Clause] = []
	for part in condition.split(SEPARATOR, false):
		if not part.strip_edges().is_empty():
			clauses.append(parse_clause(part))
	for clause in clauses:
		if clause.quantitative:
			return Vector2i(mini(current_value(clause, ctx), clause.amount), clause.amount)
	var met := 0
	for clause in clauses:
		if clause_holds(clause, ctx):
			met += 1
	return Vector2i(met, clauses.size())


static func in_window(goal: GoalData, day: int) -> bool:
	return day >= goal.day_min and (goal.day_max == NO_EXPIRY or day <= goal.day_max)


## 아직 완료되지 않았고 오늘 창 안에 있는가.
static func is_active(goal: GoalData, day: int, done: Dictionary) -> bool:
	return not done.has(goal.id) and in_window(goal, day)


## 지금 새로 완료되는 목표 (tier 순 → id 순). done 은 goal_id -> 완료한 날.
static func newly_completed(goals: Dictionary, ctx: Context, done: Dictionary) -> Array[GoalData]:
	var result: Array[GoalData] = []
	for goal in sorted(goals):
		if is_active(goal, ctx.day, done) and condition_holds(goal.condition, ctx):
			result.append(goal)
	return result


## 오늘 창 안의 목표 (완료 포함), 주어진 층위만. 표시용.
static func visible(goals: Dictionary, day: int, tiers: Array[String]) -> Array[GoalData]:
	var result: Array[GoalData] = []
	for goal in sorted(goals):
		if tiers.has(goal.tier) and in_window(goal, day):
			result.append(goal)
	return result


static func sorted(goals: Dictionary) -> Array[GoalData]:
	var result: Array[GoalData] = []
	for goal: GoalData in goals.values():
		result.append(goal)
	result.sort_custom(func(a: GoalData, b: GoalData) -> bool:
		var tier_a := TIERS.find(a.tier)
		var tier_b := TIERS.find(b.tier)
		if tier_a != tier_b:
			return tier_a < tier_b
		if a.day_min != b.day_min:
			return a.day_min < b.day_min
		return a.id < b.id)
	return result
