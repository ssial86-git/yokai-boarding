class_name Rent
extends RefCounted
## 하숙비 정산 순수 로직. 하숙생은 rent_type 별로 제각각(돈·아이템·심부름) 내고,
## 뜨내기 손님은 체크아웃 날 기본 숙박비 + 특이 하숙비를 낸다. 반영·시그널은 DayCycle 이 한다.

const RANDOM_KIND_PREFIX := "kind:"


class Payment:
	extends RefCounted
	var payer_id: String = ""  # yokai id 또는 guest species id
	var is_guest: bool = false
	var rent_type: String = "none"
	var money: int = 0
	var item_id: String = ""
	var item_amount: int = 0
	var condition_bonus: int = 0
	var note: String = ""


class Result:
	extends RefCounted
	var money: int = 0
	var items: Dictionary = {}  # item_id -> amount
	var condition_bonus: int = 0
	var payments: Array[Payment] = []
	var mishap_money: int = 0
	var mishap_texts: Array[String] = []
	var departed: Array[Dictionary] = []  # 체크아웃한 손님

	func add(payment: Payment) -> void:
		payments.append(payment)
		money += payment.money
		condition_bonus += payment.condition_bonus
		if not payment.item_id.is_empty() and payment.item_amount > 0:
			items[payment.item_id] = int(items.get(payment.item_id, 0)) + payment.item_amount


## "kind:material" 이면 그 종류의 아이템 중 무작위, 아니면 그대로.
static func resolve_item(spec: String, items_catalog: Dictionary, rng: RandomNumberGenerator) -> String:
	if not spec.begins_with(RANDOM_KIND_PREFIX):
		return spec
	var kind := spec.trim_prefix(RANDOM_KIND_PREFIX)
	var candidates: Array[String] = []
	for item: ItemData in items_catalog.values():
		if item.kind == kind:
			candidates.append(item.id)
	candidates.sort()
	if candidates.is_empty():
		return ""
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func settle_residents(
	residents: Array[String], yokai_catalog: Dictionary, items_catalog: Dictionary, day: int, rng: RandomNumberGenerator
) -> Result:
	var result := Result.new()
	for yokai_id in residents:
		var yokai := yokai_catalog.get(yokai_id) as YokaiData
		if yokai == null or yokai.rent_type == "none":
			continue
		if yokai.rent_interval_days > 1 and day % yokai.rent_interval_days != 0:
			continue
		var payment := Payment.new()
		payment.payer_id = yokai_id
		payment.rent_type = yokai.rent_type
		payment.note = yokai.rent_note_ko
		match yokai.rent_type:
			"money":
				payment.money = yokai.rent_amount
			"items":
				payment.item_id = resolve_item(yokai.rent_item, items_catalog, rng)
				payment.item_amount = yokai.rent_amount if not payment.item_id.is_empty() else 0
			"errand", "buff":
				payment.condition_bonus = yokai.rent_amount
			_:
				pass
		result.add(payment)
	return result


## depart_day 가 지난 손님을 체크아웃시킨다. 사고뭉치는 mishap 을 남긴다.
static func settle_guests(
	guests: Array, species_catalog: Dictionary, visitors_catalog: Dictionary, day: int
) -> Result:
	var result := Result.new()
	for guest: Dictionary in guests:
		if int(guest.get("depart_day", 0)) > day:
			continue
		var species := species_catalog.get(str(guest.get("species_id", ""))) as GuestSpeciesData
		var visitor := visitors_catalog.get(str(guest.get("visitor_id", ""))) as VisitorData
		result.departed.append(guest)
		if species == null:
			continue
		var payment := Payment.new()
		payment.payer_id = species.id
		payment.is_guest = true
		payment.rent_type = species.rent_type
		payment.money = species.rent_money
		payment.note = species.rent_note_ko
		match species.rent_type:
			"money":
				payment.money += species.rent_amount
			"items":
				payment.item_id = species.rent_item
				payment.item_amount = species.rent_amount
			"buff":
				payment.condition_bonus = species.rent_amount
			_:
				pass
		result.add(payment)
		if visitor != null and visitor.kind == "troublemaker" and visitor.mishap_money > 0:
			result.mishap_money += visitor.mishap_money
			result.mishap_texts.append(visitor.mishap_text_ko.format({"name": species.name_ko}))
	return result
