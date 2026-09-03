class_name Market
extends RefCounted
## 판매 순수 로직 (요리 3중 용도의 '판매'). P1 은 대문간 행상 한 곳뿐이고 가격은 items.base_value × tuning sell_price_ratio.
## 회색 시장·시세 변동은 P2.

## 팔 수 없는 종류: 서사 열쇠, 씨앗(심으라고 준 것)
const UNSELLABLE_KINDS: Array[String] = ["key", "seed"]


static func is_sellable(item: ItemData) -> bool:
	return item != null and item.base_value > 0 and not UNSELLABLE_KINDS.has(item.kind)


static func unit_price(item: ItemData, ratio: float) -> int:
	if not is_sellable(item):
		return 0
	return maxi(int(floor(item.base_value * ratio + 0.5)), 1)


## 창고에서 팔 수 있는 아이템 id 를 이름 순으로.
static func sellable_ids(inventory: Inventory, items_catalog: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for item_id: String in inventory.items():
		if is_sellable(items_catalog.get(item_id) as ItemData):
			result.append(item_id)
	result.sort()
	return result


## count 개를 판다. 판 돈을 돌려주고 실패(없음·불가)면 0.
static func sell(inventory: Inventory, items_catalog: Dictionary, item_id: String, count: int, ratio: float) -> int:
	var item := items_catalog.get(item_id) as ItemData
	var price := unit_price(item, ratio)
	if price <= 0 or count <= 0 or not inventory.remove(item_id, count):
		return 0
	return price * count
