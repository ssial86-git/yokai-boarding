class_name EventScheduler
extends RefCounted
## events.csv 조건(페이즈·날짜·입주·호감도·소지품·플래그·1회) 을 평가해 지금 띄울 이벤트를 고른다.

const PHASE_ANY := "any"


class Context:
	extends RefCounted
	var day: int = 1
	var phase_name: String = "night"
	var residents: Array[String] = []
	var affinity: Dictionary = {}
	var flags: Dictionary = {}
	var seen: Array[String] = []
	var inventory: Inventory = Inventory.new()


static func is_eligible(event: EventData, ctx: Context) -> bool:
	if event.phase != PHASE_ANY and event.phase != ctx.phase_name:
		return false
	if ctx.day < event.day_min:
		return false
	if event.day_max > 0 and ctx.day > event.day_max:
		return false
	if not event.yokai_id.is_empty():
		if not ctx.residents.has(event.yokai_id):
			return false
		if int(ctx.affinity.get(event.yokai_id, 0)) < event.min_affinity:
			return false
	if not event.requires_item.is_empty() and not ctx.inventory.has(event.requires_item):
		return false
	if not event.requires_flag.is_empty() and not ctx.flags.has(event.requires_flag):
		return false
	if event.once and ctx.seen.has(event.id):
		return false
	return true


## 조건에 맞는 이벤트를 priority 내림차순으로. 같으면 호감도가 낮은(관심을 덜 받은) 하숙생의 사연을 먼저,
## 그래도 같으면 id 순 — 한 밤에 하나만 띄우므로 특정 하숙생이 굶지 않게 돌아가며 나온다.
static func eligible(events: Dictionary, ctx: Context) -> Array[EventData]:
	var result: Array[EventData] = []
	for event: EventData in events.values():
		if is_eligible(event, ctx):
			result.append(event)
	result.sort_custom(func(a: EventData, b: EventData) -> bool:
		if a.priority != b.priority:
			return a.priority > b.priority
		var affinity_a := int(ctx.affinity.get(a.yokai_id, 0))
		var affinity_b := int(ctx.affinity.get(b.yokai_id, 0))
		if affinity_a != affinity_b:
			return affinity_a < affinity_b
		return a.id < b.id)
	return result


static func pick(events: Dictionary, ctx: Context) -> EventData:
	var candidates := eligible(events, ctx)
	return candidates[0] if not candidates.is_empty() else null
