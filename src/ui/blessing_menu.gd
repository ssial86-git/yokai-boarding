class_name BlessingMenu
extends ListMenu
## 가호 접붙이기 메뉴 (P2-S3): 하숙생 앞에서 E. 창고의 씨앗·요리·부적마다 효과 미리보기(시너지·간섭 설명 포함)와 '부여'.
## 규칙·부여는 BlessingSystem.

var blessing_system: BlessingSystem
var _yokai_id: String = ""


func _ready() -> void:
	super()
	Events.item_added.connect(func(_id: String, _count: int) -> void: _refresh_if_open())
	Events.item_removed.connect(func(_id: String, _count: int) -> void: _refresh_if_open())
	Events.blessing_granted.connect(func(_yokai: String, _item: String) -> void: _refresh_if_open())


func open_for(yokai_id: String) -> void:
	_yokai_id = yokai_id
	open_with_title(DataRegistry.text("ui_blessing_title", {
		"name": DataRegistry.yokai_name(yokai_id),
		"left": blessing_system.remaining(yokai_id) if blessing_system != null else 0,
		"max": blessing_system.per_day() if blessing_system != null else 0}))
	refresh()


func refresh() -> void:
	clear_rows()
	if blessing_system == null:
		return
	var blessing := blessing_system.blessing_for(_yokai_id)
	if blessing == null:
		add_header(DataRegistry.text("ui_blessing_none"))
		return
	add_header(blessing.flavor_ko)
	var affinity := int(GameState.affinity.get(_yokai_id, 0))
	if affinity < blessing.affinity_min:
		add_header(DataRegistry.text("ui_blessing_locked", {"affinity": affinity, "min": blessing.affinity_min}))
		return
	if blessing_system.remaining(_yokai_id) <= 0:
		add_header(DataRegistry.text("ui_blessing_done_today"))
	var items := blessing_system.eligible_items()
	if items.is_empty():
		add_header(DataRegistry.text("ui_blessing_none"))
		return
	for item_id in items:
		var kind := blessing_system.target_kind_of(item_id)
		var effect := DataRegistry.text("ui_blessing_effect_%s" % kind, {"bonus": blessing_system.preview_bonus(_yokai_id, item_id)})
		for note in blessing_system.preview_notes(_yokai_id, item_id):
			effect += DataRegistry.text("ui_blessing_synergy", {"note": note})
		var id := item_id
		add_row(DataRegistry.text("ui_blessing_row", {
			"name": DataRegistry.item_name(item_id), "count": GameState.inventory.get_count(item_id), "effect": effect}),
			DataRegistry.text("ui_blessing_grant"), func() -> void: blessing_system.grant(_yokai_id, id),
			blessing_system.can_grant_any(_yokai_id))


func _refresh_if_open() -> void:
	if visible:
		refresh()
