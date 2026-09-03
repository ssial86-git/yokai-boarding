class_name EventScheduler
extends RefCounted
## events.csv 조건(시간대·날짜·입주·호감도·소지품·플래그·1회) 을 평가해 지금 띄울 이벤트를 고른다.

const TIMEBAND_ANY := "any"
## 말을 걸 때만 뜨는 NPC 대화 (P2-S3)
const KIND_NPC := "npc"


class Context:
	extends RefCounted
	var day: int = 1
	var timeband: String = "night"
	var residents: Array[String] = []
	var affinity: Dictionary = {}
	var flags: Dictionary = {}
	var seen: Array[String] = []
	var inventory: Inventory = Inventory.new()


static func is_eligible(event: EventData, ctx: Context) -> bool:
	if event.timeband != TIMEBAND_ANY and event.timeband != ctx.timeband:
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
		# NPC 대화(kind npc)는 시간대 트리거로 뜨지 않는다 — 말을 걸 때만 (P2-S3 회색 장꾼)
		if event.kind == KIND_NPC:
			continue
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
