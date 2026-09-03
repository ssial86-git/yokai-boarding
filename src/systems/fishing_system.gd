class_name FishingSystem
extends Node
## 낚시의 노드 측 (P1-S3): 찌 던지기 → 타이밍 바 진행 → E 로 판정 → 어종·고물 추첨 → 인벤토리.
## 대화·심사 중(Clock hold)에는 바가 멈춘다. 순수 계산은 Fishing.

const VERB_FISH := "fish"
const UNLOCK_TYPE_FISH := "fish"
const TOOL_ROD := "rod"

var unlock_system: UnlockSystem
var cast: Fishing.Cast
var region_id: String = ""

var _window_ratio: float = 0.35
var _cycles_per_second: float = 0.8
var _max_seconds: float = 6.0
var _stamina_cost: float = 3.0
var _junk_chance: float = 0.5


func _ready() -> void:
	var tuning := DataRegistry.tuning
	_window_ratio = tuning.get_float("fishing_window_ratio", _window_ratio)
	_cycles_per_second = tuning.get_float("fishing_bar_cycles_per_second", _cycles_per_second)
	_max_seconds = tuning.get_float("fishing_max_seconds", _max_seconds)
	_stamina_cost = tuning.get_float("fishing_stamina_cost", _stamina_cost)
	_junk_chance = tuning.get_float("fishing_miss_junk_chance", _junk_chance)
	Events.region_entered.connect(func(_id: String) -> void: cancel())


func _process(delta: float) -> void:
	if Clock.is_held():
		return
	tick(delta)


## 바를 흘린다. 제한 시간을 넘기면 놓친 것으로 끝난다 (테스트·디버그도 이 함수를 부른다).
func tick(delta: float) -> void:
	if cast == null:
		return
	cast.advance(delta)
	if cast.elapsed >= _max_seconds:
		_finish(false)


func is_active() -> bool:
	return cast != null


func is_verb_unlocked() -> bool:
	return unlock_system == null or unlock_system.is_target_open("verb", VERB_FISH)


func has_spot(region: RegionData) -> bool:
	return region != null and region.fishing_x > 0


## 낚시 자리에서 보이는 안내 문구.
func prompt_for(target_region_id: String) -> String:
	if is_active():
		return DataRegistry.text("prompt_fish_strike")
	if not is_verb_unlocked():
		return DataRegistry.text("prompt_fish_locked")
	if not GameState.has_tool(TOOL_ROD):
		return DataRegistry.text("prompt_fish_need_rod")
	return DataRegistry.text("prompt_fish")


func can_start(target_region_id: String) -> bool:
	return not is_active() and is_verb_unlocked() and GameState.has_tool(TOOL_ROD) \
		and has_spot(DataRegistry.get_region(target_region_id))


## 찌를 던진다. 조건이 안 되면 false.
func start(target_region_id: String) -> bool:
	if not can_start(target_region_id):
		return false
	region_id = target_region_id
	cast = Fishing.new_cast(GameState.rng, _window_ratio, _cycles_per_second)
	GameState.stamina.spend(_stamina_cost)
	Events.message_posted.emit(DataRegistry.text("msg_fishing_started"))
	Events.fishing_started.emit(region_id)
	return true


## E: 지금 마커 위치로 판정한다. 낚인 아이템 id (놓치면 "").
func strike() -> String:
	if cast == null:
		return ""
	return _finish(cast.is_hit())


func cancel() -> void:
	cast = null
	region_id = ""


func _finish(hit: bool) -> String:
	var finished_region := region_id
	var rod_level := int(GameState.tools.get(TOOL_ROD, 0))
	var pool := Fishing.candidates(DataRegistry.fish, finished_region, Clock.band_name(), rod_level)
	if unlock_system != null:
		# unlocks.csv 가 가리키는 어종(fish 타입)은 열려야 걸린다 (P2-S2 잉어)
		pool = pool.filter(func(fish: FishData) -> bool: return unlock_system.is_target_open(UNLOCK_TYPE_FISH, fish.id))
	var caught: FishData = null
	if hit:
		caught = Fishing.roll(pool, GameState.rng)
	elif GameState.rng.randf() < _junk_chance:
		caught = Fishing.roll(Fishing.junk_only(pool), GameState.rng)
	cancel()
	var item_id := caught.id if caught != null else ""
	if caught != null:
		GameState.inventory.add(item_id, 1)
		Events.item_added.emit(item_id, 1)
		var key := "msg_fish_caught" if caught.kind != Fishing.KIND_JUNK else "msg_fish_junk"
		Events.message_posted.emit(DataRegistry.text(key, {"name": caught.name_ko}))
		if caught.kind != Fishing.KIND_JUNK:
			Events.activity_done.emit("fish", item_id, 1)
	else:
		Events.message_posted.emit(DataRegistry.text("msg_fish_missed"))
	Metrics.record("fish", {"result": item_id if not item_id.is_empty() else "miss", "region": finished_region})
	Events.fishing_ended.emit(finished_region, item_id)
	return item_id
