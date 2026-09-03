class_name VisitorRoll
extends RefCounted
## 저녁 방문자 추첨 순수 로직. 고정 도착(yokai.join_mode=intake)이 최우선이고,
## 그다음 visitors.csv 가중치로 유형을, guest_species.csv 가중치로 종족을 뽑는다. RNG 는 호출자가 시드를 관리한다.


class Visitor:
	extends RefCounted
	var visitor_id: String = ""
	var kind: String = "guest"
	var species_id: String = ""
	var yokai_id: String = ""  # erased 방문자가 입주할 하숙생
	var omen: int = 0

	func to_dict() -> Dictionary:
		return {"visitor_id": visitor_id, "kind": kind, "species_id": species_id, "yokai_id": yokai_id, "omen": omen}

	static func from_dict(data: Dictionary) -> Visitor:
		var visitor := Visitor.new()
		visitor.visitor_id = str(data.get("visitor_id", ""))
		visitor.kind = str(data.get("kind", "guest"))
		visitor.species_id = str(data.get("species_id", ""))
		visitor.yokai_id = str(data.get("yokai_id", ""))
		visitor.omen = int(data.get("omen", 0))
		return visitor


## join_day == day 이고 아직 입주하지 않은 intake 하숙생이 있으면 '빈 카드' 방문자.
static func scripted(yokai_catalog: Dictionary, residents: Array[String], day: int, erased_visitor_id: String) -> Visitor:
	var ids: Array[String] = []
	for yokai: YokaiData in yokai_catalog.values():
		if yokai.join_mode == "intake" and yokai.join_day == day and not residents.has(yokai.id):
			ids.append(yokai.id)
	if ids.is_empty():
		return null
	ids.sort()
	var visitor := Visitor.new()
	visitor.visitor_id = erased_visitor_id
	visitor.kind = "erased"
	visitor.yokai_id = ids[0]
	return visitor


## chance 판정 후 유형·종족을 뽑는다. 아무도 안 오면 null.
## realm_multipliers 는 {realm: 배율} — 날씨 음기가 이승/마계 손님 가중치를 늘리고 줄인다 (P2-S1). 비우면 원래 가중치.
static func roll(
	visitors: Dictionary, species: Dictionary, rng: RandomNumberGenerator, chance: float, weather: String,
	realm_multipliers: Dictionary = {}
) -> Visitor:
	if rng.randf() >= chance:
		return null
	var visitor_data := _weighted(_sorted_values(visitors), rng) as VisitorData
	if visitor_data == null:
		return null
	var eligible: Array = []
	for candidate: GuestSpeciesData in _sorted_values(species):
		if candidate.appear_condition.is_empty() or candidate.appear_condition == weather:
			eligible.append(candidate)
	var species_data: GuestSpeciesData = null
	if realm_multipliers.is_empty():
		species_data = _weighted(eligible, rng) as GuestSpeciesData
	else:
		species_data = _weighted_by_realm(eligible, realm_multipliers, rng)
	if species_data == null:
		return null
	var visitor := Visitor.new()
	visitor.visitor_id = visitor_data.id
	visitor.kind = visitor_data.kind
	visitor.species_id = species_data.id
	visitor.omen = maxi(rng.randi_range(visitor_data.omen_min, visitor_data.omen_max), species_data.omen)
	return visitor


static func _sorted_values(catalog: Dictionary) -> Array:
	var keys := catalog.keys()
	keys.sort()
	var result: Array = []
	for key: Variant in keys:
		result.append(catalog[key])
	return result


## weight 가 0 이하인 항목은 제외. 전부 0 이면 null.
static func _weighted(entries: Array, rng: RandomNumberGenerator) -> Resource:
	var total := 0
	for entry: Resource in entries:
		total += maxi(0, int(entry.get("weight")))
	if total <= 0:
		return null
	var pick := rng.randi_range(1, total)
	for entry: Resource in entries:
		var weight := maxi(0, int(entry.get("weight")))
		if weight == 0:
			continue
		pick -= weight
		if pick <= 0:
			return entry
	return null


## 종족 가중치 × 갈래 배율(실수). 전부 0 이면 null.
static func _weighted_by_realm(entries: Array, multipliers: Dictionary, rng: RandomNumberGenerator) -> GuestSpeciesData:
	var weights: Array[float] = []
	var total := 0.0
	for entry: GuestSpeciesData in entries:
		var weight := maxf(0.0, float(entry.weight) * float(multipliers.get(entry.realm, 1.0)))
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return null
	var pick := rng.randf() * total
	for index in entries.size():
		if weights[index] <= 0.0:
			continue
		pick -= weights[index]
		if pick <= 0.0:
			return entries[index]
	for index in range(entries.size() - 1, -1, -1):
		if weights[index] > 0.0:
			return entries[index]
	return null
