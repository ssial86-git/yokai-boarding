class_name UnlockSystem
extends Node
## unlocks.csv 케이던스의 런타임 측 (docs/08 재미 원칙 6): 상태가 바뀔 때마다 UnlockRules 로 새로 열린 항목을 찾아
## GameState.unlocked 에 적고, 도구·텃밭 확장 같은 즉시 효과를 적용하고, 성주 영감 문구로 알린다.
## 30분 규칙 시뮬레이터(tools/sim)는 P1-S4.

## 열릴 때 안내 문구를 띄우는 타입. 사연·입주는 다른 시스템이 연출하므로 조용히 기록만 한다.
const HINTED_TYPES: Array[String] = ["region", "tool", "talisman", "enemy", "crop", "material", "fish", "verb", "feature"]
const TYPE_REGION := "region"
const TYPE_TOOL := "tool"


func _ready() -> void:
	Events.day_started.connect(func(_day: int) -> void: evaluate())
	Events.timeband_changed.connect(func(_band: int, _day: int) -> void: evaluate())
	Events.affinity_changed.connect(func(_id: String, _value: int) -> void: evaluate())
	Events.item_added.connect(func(_id: String, _count: int) -> void: evaluate())
	Events.yokai_arrived.connect(func(_id: String) -> void: evaluate())
	Events.game_loaded.connect(func(_slot: int) -> void: evaluate())


func is_unlocked(unlock_id: String) -> bool:
	return GameState.unlocked.has(unlock_id)


## 해금 행이 하나도 가리키지 않는 구역은 늘 열려 있다. 가리키는 행이 있으면 그중 하나라도 열려야 한다.
func is_region_open(region_id: String) -> bool:
	return is_target_open(TYPE_REGION, region_id)


func is_feature_open(feature_id: String) -> bool:
	return is_target_open("feature", feature_id)


func build_context() -> UnlockRules.Context:
	var ctx := UnlockRules.Context.new()
	ctx.day = GameState.day
	ctx.timeband = Clock.band_name()
	ctx.flags = GameState.flags
	ctx.affinity = GameState.affinity
	ctx.residents = GameState.residents
	ctx.inventory = GameState.inventory
	ctx.unlocked = GameState.unlocked
	return ctx


## 새로 열린 항목을 적용하고 id 목록을 돌려준다.
func evaluate() -> Array[String]:
	var opened: Array[String] = []
	for unlock in UnlockRules.newly_satisfied(DataRegistry.unlocks, build_context()):
		_apply(unlock)
		opened.append(unlock.id)
	return opened


func _apply(unlock: UnlockData) -> void:
	GameState.unlocked[unlock.id] = GameState.day
	if unlock.unlock_type == TYPE_TOOL:
		var tool := DataRegistry.get_tool(unlock.unlock_id)
		if tool != null and GameState.set_tool_level(tool.kind, tool.level):
			Events.message_posted.emit(DataRegistry.text("msg_tool_got", {
				"tool": DataRegistry.text("tool_%s" % tool.kind), "level": tool.level}))
	Events.unlocked.emit(unlock.id)
	Metrics.record("unlock", {"unlock_id": unlock.id})
	if HINTED_TYPES.has(unlock.unlock_type) and not unlock.hint_ko.is_empty():
		Events.message_posted.emit(DataRegistry.text("msg_unlocked", {"hint": unlock.hint_ko}))


func is_target_open(unlock_type: String, target_id: String) -> bool:
	var gated := false
	for unlock: UnlockData in DataRegistry.unlocks.values():
		if unlock.unlock_type != unlock_type or unlock.unlock_id != target_id:
			continue
		gated = true
		if GameState.unlocked.has(unlock.id):
			return true
	return not gated
