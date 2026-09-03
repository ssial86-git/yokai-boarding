class_name BlessingRules
extends RefCounted
## 가호 접붙이기 순수 로직 (P2-S3). 가호가 붙은 아이템은 인벤토리에서 "<item_id>@<blessing_id>" 합성 id 로 산다 —
## 기본 아이템 데이터는 base_id 로 찾고, 효과는 가호 + 시너지/간섭(synergies.csv)으로 계산한다. 노드·씬 의존 없음.

const SEPARATOR := "@"
const KIND_SEED := "seed"
const KIND_DISH := "dish"
const KIND_TALISMAN := "talisman"
const KINDS: Array[String] = [KIND_SEED, KIND_DISH, KIND_TALISMAN]
## 시너지 문맥 키
const CTX_YOKAI := "yokai"
const CTX_TALISMAN_EFFECT := "talisman_effect"
const CTX_CROP_REALM := "crop_realm"
const CTX_RECIPE_STAT := "recipe_stat"
## items.kind 값
const ITEM_KIND_SEED := "seed"
const ITEM_KIND_FOOD := "food"
const ITEM_KIND_TALISMAN := "talisman"


static func compose(item_id: String, blessing_id: String) -> String:
	return item_id + SEPARATOR + blessing_id


static func is_blessed(item_id: String) -> bool:
	return item_id.contains(SEPARATOR)


static func base_id(item_id: String) -> String:
	return item_id.get_slice(SEPARATOR, 0)


## 가호 id. 없으면 빈 문자열.
static func blessing_of(item_id: String) -> String:
	return item_id.get_slice(SEPARATOR, 1) if is_blessed(item_id) else ""


## 아이템이 가호 대상인가 → 대상 종류(seed/dish/talisman) 또는 빈 문자열. 요리는 레시피가 있는 음식만.
static func target_kind(item: ItemData, has_recipe: bool) -> String:
	if item == null:
		return ""
	match item.kind:
		ITEM_KIND_SEED:
			return KIND_SEED
		ITEM_KIND_FOOD:
			return KIND_DISH if has_recipe else ""
		ITEM_KIND_TALISMAN:
			return KIND_TALISMAN
	return ""


static func base_bonus(blessing: BlessingData, kind: String) -> int:
	if blessing == null:
		return 0
	match kind:
		KIND_SEED:
			return blessing.seed_yield_bonus
		KIND_DISH:
			return blessing.dish_buff_bonus
		KIND_TALISMAN:
			return blessing.talisman_power_bonus
	return 0


## 문맥에 맞는 시너지·간섭 행 (id 순). context 는 {context_kind: context_id}.
static func matching_synergies(blessing_id: String, synergies: Dictionary, context: Dictionary) -> Array[SynergyData]:
	var result: Array[SynergyData] = []
	for synergy: SynergyData in synergies.values():
		if synergy.blessing_id == blessing_id and str(context.get(synergy.context_kind, "")) == synergy.context_id:
			result.append(synergy)
	result.sort_custom(func(a: SynergyData, b: SynergyData) -> bool: return a.id < b.id)
	return result


## 최종 효과 = 기본 + 시너지 합, 0 미만이면 0.
static func bonus(blessing: BlessingData, kind: String, synergies: Dictionary, context: Dictionary) -> int:
	if blessing == null:
		return 0
	var total := base_bonus(blessing, kind)
	for synergy in matching_synergies(blessing.id, synergies, context):
		total += synergy.delta
	return maxi(total, 0)


static func can_grant(affinity: int, blessing: BlessingData, granted_today: int, per_day: int) -> bool:
	return blessing != null and affinity >= blessing.affinity_min and granted_today < per_day


## 기본 아이템 하나를 가호 아이템으로 바꾼다. 이미 가호가 붙었거나 없으면 false.
static func grant(inventory: Inventory, item_id: String, blessing_id: String) -> bool:
	if is_blessed(item_id) or blessing_id.is_empty() or not inventory.remove(item_id, 1):
		return false
	inventory.add(compose(item_id, blessing_id), 1)
	return true


## 인벤토리에서 base 가 base_item_id 인 아이템 id 들 (가호 붙은 것 먼저, 이름 순).
static func variants_in(inventory: Inventory, base_item_id: String) -> Array[String]:
	var result: Array[String] = []
	for item_id: String in inventory.items():
		if base_id(item_id) == base_item_id:
			result.append(item_id)
	result.sort_custom(func(a: String, b: String) -> bool:
		if is_blessed(a) != is_blessed(b):
			return is_blessed(a)
		return a < b)
	return result


## base 가 같은 아이템의 총 개수 (가호 포함).
static func count_variants(inventory: Inventory, base_item_id: String) -> int:
	var total := 0
	for item_id in variants_in(inventory, base_item_id):
		total += inventory.get_count(item_id)
	return total
