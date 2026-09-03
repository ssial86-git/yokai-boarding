class_name GatherSystem
extends Node
## 채집의 노드 측: 구역별 포인트 재료 추첨(하루 리스폰), 도구 조건 안내, 채집 반영(인벤토리·스태미너·지표).
## 포인트 상태는 GameState.region_states 에만 있고, 여기서는 GatherPoints 객체를 캐시한다. 순수 계산은 GatherPoints.

const TOOL_NONE := GatherPoints.TOOL_NONE
## 재료 자리표시 색: 팔레트 뒤쪽을 id 해시로 고른다
const PLACEHOLDER_COLORS: Array[String] = ["6b8e5a", "9bb572", "c7d48f", "7a5c8f", "a883b0", "d4a5c4", "4f7f8f", "7fb2a6", "b0d8c4", "e6b8b0", "d9b384", "b58a5e"]

var _cache: Dictionary = {}  # region_id -> GatherPoints
var _stamina_cost: float = 5.0
## 채집 부적 효과: 남은 초와 추가 개수 (P1-S4)
var _bonus_remaining: float = 0.0
var _bonus_amount: int = 0


func _ready() -> void:
	_stamina_cost = DataRegistry.tuning.get_float("stamina_gather_cost", _stamina_cost)
	Events.day_started.connect(func(day: int) -> void:
		if day > 1 or _cache.is_empty():
			respawn_all())
	Events.game_loaded.connect(func(_slot: int) -> void: _cache.clear())


func _process(delta: float) -> void:
	if _bonus_remaining > 0.0 and not Clock.is_held():
		_bonus_remaining = maxf(_bonus_remaining - delta, 0.0)


func bonus_active() -> bool:
	return _bonus_remaining > 0.0 and _bonus_amount > 0


## 채집 부적: seconds 동안 채집마다 amount 개를 더 준다.
func apply_bonus(amount: int, seconds: float) -> void:
	_bonus_amount = maxi(amount, 0)
	_bonus_remaining = maxf(seconds, 0.0)


func points_for(region_id: String) -> GatherPoints:
	if _cache.has(region_id):
		return _cache[region_id]
	var region := DataRegistry.get_region(region_id)
	if region == null:
		return GatherPoints.new()
	var state := GameState.region_state(region_id)
	var points: GatherPoints
	if (state["gather_materials"] as Array).is_empty() and region.gather_point_count > 0:
		points = _roll(region)
	else:
		points = GatherPoints.from_state(region_id, state["gather_materials"], state["gather_taken"])
	_cache[region_id] = points
	return points


## 모든 채집 구역의 재료를 다시 뽑고 포인트를 채운다 (일일 리스폰).
func respawn_all() -> void:
	_cache.clear()
	for region: RegionData in DataRegistry.regions.values():
		if region.gather_point_count <= 0 or region.gather_pool.is_empty():
			continue
		_cache[region.id] = _roll(region)
		Events.gather_point_changed.emit(region.id, -1)


func prompt_for(region_id: String, index: int) -> String:
	var points := points_for(region_id)
	var material := DataRegistry.get_material(points.material_at(index))
	if material == null:
		return ""
	match points.check(index, DataRegistry.materials, GameState.tools):
		GatherPoints.Outcome.TAKEN:
			return DataRegistry.text("prompt_taken")
		GatherPoints.Outcome.NEED_TOOL:
			return DataRegistry.text("prompt_need_tool", {"name": material.name_ko, "tool": _tool_name(material.tool_kind)})
		GatherPoints.Outcome.TOOL_TOO_WEAK:
			return DataRegistry.text("prompt_tool_weak", {
				"name": material.name_ko, "tool": _tool_name(material.tool_kind), "level": material.min_tool_level})
		GatherPoints.Outcome.OK:
			var key := "prompt_gather"
			if material.source == "chop":
				key = "prompt_chop"
			elif material.source == "mine":
				key = "prompt_mine"
			return DataRegistry.text(key, {"name": material.name_ko})
	return ""


func can_gather(region_id: String, index: int) -> bool:
	return points_for(region_id).check(index, DataRegistry.materials, GameState.tools) == GatherPoints.Outcome.OK


## 채집. 성공하면 재료가 인벤토리에 들어가고 true.
func gather(region_id: String, index: int) -> bool:
	if not can_gather(region_id, index):
		return false
	var points := points_for(region_id)
	var material_id := points.take(index)
	if material_id.is_empty():
		return false
	GameState.region_state(region_id)["gather_taken"] = points.taken_indices()
	var count := 1 + (_bonus_amount if bonus_active() else 0)  # 채집 부적
	GameState.inventory.add(material_id, count)
	GameState.stamina.spend(_stamina_cost)
	var material := DataRegistry.get_material(material_id)
	var tool_kind := material.tool_kind if material != null else TOOL_NONE
	Events.item_added.emit(material_id, count)
	Events.message_posted.emit(DataRegistry.text("msg_gathered", {"name": DataRegistry.item_name(material_id), "count": count}))
	Metrics.record("gather", {"material": material_id, "region": region_id, "tool": tool_kind})
	Events.gather_point_changed.emit(region_id, index)
	return true


func material_color(material_id: String) -> Color:
	var index := absi(material_id.hash()) % PLACEHOLDER_COLORS.size()
	return Color.html(PLACEHOLDER_COLORS[index])


## 하루 재료 추첨은 방문자 RNG 를 소모하지 않도록 시드+날짜에서 파생한 RNG 를 쓴다 (시드 고정 테스트 보호).
func _roll(region: RegionData) -> GatherPoints:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%s" % [GameState.rng.seed, GameState.day, region.id])
	var points := GatherPoints.roll(region, DataRegistry.materials, rng)
	var state := GameState.region_state(region.id)
	state["gather_materials"] = Array(points.material_ids)
	state["gather_taken"] = []
	return points


func _tool_name(kind: String) -> String:
	return DataRegistry.text("tool_%s" % kind)
