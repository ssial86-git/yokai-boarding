class_name BlessingSystem
extends Node
## 가호 접붙이기의 런타임 측 (P2-S3): 해금·호감도·하루 한도 판정, 대상 아이템 목록, 부여(인벤토리 합성 id), 효과 미리보기.
## 다른 시스템(텃밭·배식·부적)은 static 효과 계산만 부른다. 순수 규칙은 BlessingRules.

const FEATURE_BLESSINGS := "blessings"

var unlock_system: UnlockSystem
var _per_day: int = 1


func _ready() -> void:
	_per_day = DataRegistry.tuning.get_int("blessing_per_day", _per_day)


func is_open() -> bool:
	return unlock_system == null or unlock_system.is_feature_open(FEATURE_BLESSINGS)


func per_day() -> int:
	return _per_day


func blessing_for(yokai_id: String) -> BlessingData:
	return DataRegistry.blessing_of_yokai(yokai_id)


func remaining(yokai_id: String) -> int:
	return maxi(_per_day - int(GameState.blessings_today.get(yokai_id, 0)), 0)


## 호감도가 되고 오늘 한도가 남았는가.
func can_grant_any(yokai_id: String) -> bool:
	return BlessingRules.can_grant(
		int(GameState.affinity.get(yokai_id, 0)), blessing_for(yokai_id), int(GameState.blessings_today.get(yokai_id, 0)), _per_day)


func target_kind_of(item_id: String) -> String:
	return BlessingRules.target_kind(DataRegistry.get_item(item_id), DataRegistry.recipe_for_dish(item_id) != null)


## 창고에서 가호를 붙일 수 있는 아이템 (가호가 안 붙은 씨앗·요리·부적), id 순.
func eligible_items() -> Array[String]:
	var result: Array[String] = []
	for item_id: String in GameState.inventory.items():
		if not BlessingRules.is_blessed(item_id) and not target_kind_of(item_id).is_empty():
			result.append(item_id)
	result.sort()
	return result


func preview_bonus(yokai_id: String, item_id: String) -> int:
	var kind := target_kind_of(item_id)
	return BlessingRules.bonus(blessing_for(yokai_id), kind, DataRegistry.synergies, _context_for(item_id, kind))


## 미리보기에 붙는 시너지·간섭 설명.
func preview_notes(yokai_id: String, item_id: String) -> Array[String]:
	var blessing := blessing_for(yokai_id)
	var notes: Array[String] = []
	if blessing == null:
		return notes
	var kind := target_kind_of(item_id)
	for synergy in BlessingRules.matching_synergies(blessing.id, DataRegistry.synergies, _context_for(item_id, kind)):
		notes.append(synergy.note_ko)
	return notes


## 가호 부여. 성공하면 true.
func grant(yokai_id: String, item_id: String) -> bool:
	var blessing := blessing_for(yokai_id)
	if not is_open() or blessing == null or not can_grant_any(yokai_id):
		return false
	var kind := target_kind_of(item_id)
	if kind.is_empty() or not BlessingRules.grant(GameState.inventory, item_id, blessing.id):
		return false
	var blessed_id := BlessingRules.compose(item_id, blessing.id)
	GameState.blessings_today[yokai_id] = int(GameState.blessings_today.get(yokai_id, 0)) + 1
	GameState.blessing_log[blessing.id] = int(GameState.blessing_log.get(blessing.id, 0)) + 1
	Events.item_removed.emit(item_id, 1)
	Events.item_added.emit(blessed_id, 1)
	Events.message_posted.emit(DataRegistry.text("msg_blessing_granted", {
		"yokai": DataRegistry.yokai_name(yokai_id), "item": DataRegistry.item_name(blessed_id)}))
	Metrics.record("blessing_granted", {"blessing": blessing.id, "item": item_id, "kind": kind})
	Events.blessing_granted.emit(yokai_id, blessed_id)
	Events.activity_done.emit("bless", blessing.id, 1)
	return true


## 시너지 문맥: 씨앗은 작물 갈래, 요리는 버프 능력치, 부적은 갈래. 먹는 하숙생은 배식 때 더해진다.
func _context_for(item_id: String, kind: String) -> Dictionary:
	var base := BlessingRules.base_id(item_id)
	match kind:
		BlessingRules.KIND_SEED:
			for crop: CropData in DataRegistry.crops.values():
				if crop.seed_item == base:
					return {BlessingRules.CTX_CROP_REALM: crop.realm}
		BlessingRules.KIND_DISH:
			var recipe := DataRegistry.recipe_for_dish(base)
			if recipe != null:
				return {BlessingRules.CTX_RECIPE_STAT: recipe.buff_stat}
		BlessingRules.KIND_TALISMAN:
			var talisman := DataRegistry.get_talisman(base)
			if talisman != null:
				return {BlessingRules.CTX_TALISMAN_EFFECT: talisman.effect}
	return {}


# --- 다른 시스템이 쓰는 효과 계산 ---

## 씨앗 가호의 수확 보너스 (문맥: 작물 갈래).
static func seed_bonus(blessing_id: String, crop: CropData) -> int:
	if blessing_id.is_empty() or crop == null:
		return 0
	return BlessingRules.bonus(DataRegistry.get_blessing(blessing_id), BlessingRules.KIND_SEED, DataRegistry.synergies,
		{BlessingRules.CTX_CROP_REALM: crop.realm})


## 요리 가호의 배식 버프 보너스 (문맥: 먹는 하숙생 + 버프 능력치).
static func dish_bonus(blessing_id: String, recipe: RecipeData, yokai_id: String) -> int:
	if blessing_id.is_empty() or recipe == null:
		return 0
	return BlessingRules.bonus(DataRegistry.get_blessing(blessing_id), BlessingRules.KIND_DISH, DataRegistry.synergies,
		{BlessingRules.CTX_YOKAI: yokai_id, BlessingRules.CTX_RECIPE_STAT: recipe.buff_stat})


## 부적 가호의 위력 보너스 (문맥: 부적 갈래).
static func talisman_bonus(blessing_id: String, talisman: TalismanData) -> int:
	if blessing_id.is_empty() or talisman == null:
		return 0
	return BlessingRules.bonus(DataRegistry.get_blessing(blessing_id), BlessingRules.KIND_TALISMAN, DataRegistry.synergies,
		{BlessingRules.CTX_TALISMAN_EFFECT: talisman.effect})
