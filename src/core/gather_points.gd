class_name GatherPoints
extends RefCounted
## 한 구역의 채집 포인트 순수 로직: 재료 추첨(희귀도 가중), 도구 조건, 하루 리스폰.
## 포인트 상태는 GameState.region_states[region]["gather_materials" / "gather_taken"] 에 문자열로만 저장된다.

enum Outcome { OK, OUT_OF_RANGE, TAKEN, NEED_TOOL, TOOL_TOO_WEAK }

const RARITY_WEIGHTS: Dictionary = {"common": 3, "uncommon": 2, "rare": 1}
const TOOL_NONE := "none"
const YIN_HIGH := "high"
const YIN_LOW := "low"
const SEASON_ANY := "any"

var region_id: String = ""
var material_ids: Array[String] = []
var taken: Array[bool] = []


## 구역의 gather_pool 에서 포인트마다 재료를 뽑는다. 풀이 비면 포인트가 없다.
## yin_high: 음기 짙은 날 — yin_condition=high 재료는 이날만, low 재료는 이날 빼고 나온다 (P2-S1).
## season_id: 절기 재료(materials.season)는 그 절기에만 나온다 (P3-S1). 비우면 절기 제한 없음.
## 조건으로 풀이 다 빠지면 조건을 무시한다 (구역이 텅 비는 것보다 낫다).
static func roll(
	region: RegionData, material_catalog: Dictionary, rng: RandomNumberGenerator, yin_high: bool = false, season_id: String = ""
) -> GatherPoints:
	var points := GatherPoints.new()
	points.region_id = region.id
	var pool: Array[String] = []
	var weights: Array[int] = []
	var total := 0
	for material_id: Variant in _filter(region.gather_pool, material_catalog, yin_high, season_id):
		var material := material_catalog.get(str(material_id)) as MaterialData
		if material == null:
			continue
		pool.append(material.id)
		var weight := int(RARITY_WEIGHTS.get(material.rarity, 1))
		weights.append(weight)
		total += weight
	if pool.is_empty() or total <= 0:
		return points
	for i in region.gather_point_count:
		var pick := rng.randi_range(1, total)
		var chosen := pool[pool.size() - 1]
		for k in pool.size():
			pick -= weights[k]
			if pick <= 0:
				chosen = pool[k]
				break
		points.material_ids.append(chosen)
		points.taken.append(false)
	return points


static func _filter(ids: Array, material_catalog: Dictionary, yin_high: bool, season_id: String) -> Array:
	var result: Array = []
	for material_id: Variant in ids:
		var material := material_catalog.get(str(material_id)) as MaterialData
		if material == null:
			continue
		if material.yin_condition == YIN_HIGH and not yin_high:
			continue
		if material.yin_condition == YIN_LOW and yin_high:
			continue
		if not season_id.is_empty() and material.season != SEASON_ANY and material.season != season_id:
			continue
		result.append(str(material_id))
	return result if not result.is_empty() else Array(ids)


static func from_state(region_id_value: String, materials: Array, taken_indices: Array) -> GatherPoints:
	var points := GatherPoints.new()
	points.region_id = region_id_value
	for entry: Variant in materials:
		points.material_ids.append(str(entry))
		points.taken.append(false)
	for entry: Variant in taken_indices:
		var index := int(str(entry))
		if index >= 0 and index < points.taken.size():
			points.taken[index] = true
	return points


func size() -> int:
	return material_ids.size()


func material_at(index: int) -> String:
	return material_ids[index] if index >= 0 and index < material_ids.size() else ""


func is_taken(index: int) -> bool:
	return index >= 0 and index < taken.size() and taken[index]


## tools: 도구 갈래 -> 레벨 (GameState.tools).
func check(index: int, material_catalog: Dictionary, tools: Dictionary) -> Outcome:
	if index < 0 or index >= material_ids.size():
		return Outcome.OUT_OF_RANGE
	if taken[index]:
		return Outcome.TAKEN
	var material := material_catalog.get(material_ids[index]) as MaterialData
	if material != null and material.tool_kind != TOOL_NONE:
		if not tools.has(material.tool_kind):
			return Outcome.NEED_TOOL
		if int(tools[material.tool_kind]) < material.min_tool_level:
			return Outcome.TOOL_TOO_WEAK
	return Outcome.OK


## 채집. 재료 id 를 돌려주고 포인트를 비운다. 조건 검사는 check() 로 먼저.
func take(index: int) -> String:
	if index < 0 or index >= material_ids.size() or taken[index]:
		return ""
	taken[index] = true
	return material_ids[index]


func taken_indices() -> Array:
	var result: Array = []
	for index in taken.size():
		if taken[index]:
			result.append(str(index))
	return result


func remaining() -> int:
	var count := 0
	for flag in taken:
		if not flag:
			count += 1
	return count
