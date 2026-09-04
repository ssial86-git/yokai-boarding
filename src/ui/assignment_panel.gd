class_name AssignmentPanel
extends PanelContainer
## 화면 아래 배치 패널: 하숙생 카드(드래그) + 체류 중 손님 카드(정보만) + 휴식 놓기 영역.
## 아침이 아니면 카드 드래그를 잠근다.

const SPRITE_PATH := "res://assets/art_generated/yokai_%s.png"
const GUEST_SPRITE_PATH := "res://assets/art_generated/guest_%s.png"

var controller: AssignmentController

var _title: Label
var _collapse_button: Button
var _body: VBoxContainer
## B 로 접으면 제목 줄만 남는다 (야외·낮에 화면을 비우기 위해)
var collapsed: bool = false
var _cards_box: HBoxContainer
var _cards_scroll: ScrollContainer
var _cards: Dictionary = {}  # yokai_id -> YokaiCard (하숙생)
var _guest_cards: Array[YokaiCard] = []
var _rest_zone: Label
var _field_zone: FieldZone
var _party_zone: FieldZone
var _delegation_row: HBoxContainer
var _delegation_zones: Dictionary = {}  # Vector2i -> FieldZone
## (cell: Vector2i) -> bool. 위임 슬롯이 해금됐는가. main.gd 가 넣는다 (없으면 전부 보임)
var delegation_open_check: Callable

## 위임 슬롯 -> 해금 feature id / 드롭존 문구 키 (P3-S4)
const DELEGATION_FEATURES: Dictionary = {
	Assignment.GATHER: "delegate_gather", Assignment.FISHING: "delegate_fishing", Assignment.MARKET: "delegate_market",
}
const DELEGATION_ZONE_KEYS: Dictionary = {
	Assignment.GATHER: "ui_gather_zone", Assignment.FISHING: "ui_fishing_zone", Assignment.MARKET: "ui_market_zone",
}
var _card_size: int = 40
## 카드 줄 높이 = 카드 아이콘 + 이름·상태 두 줄 여유
const CARD_ROW_EXTRA_PX := 40


## 텃밭 놓기 영역: 카드 드롭을 받아 FIELD 배치로 넘긴다.
class FieldZone:
	extends Label
	## (yokai_id: String) -> bool
	var can_accept: Callable
	## (yokai_id: String) -> void
	var on_drop: Callable

	func _init() -> void:
		# Label 기본값은 IGNORE 라 드롭이 이 컨트롤에 닿지 않고 패널 바닥(휴식)으로 떨어진다 — 사용자가 잡은 버그
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if not (data is Dictionary and (data as Dictionary).has(YokaiCard.DRAG_KEY)):
			return false
		return not can_accept.is_valid() or bool(can_accept.call(str((data as Dictionary)[YokaiCard.DRAG_KEY])))

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if on_drop.is_valid():
			on_drop.call(str((data as Dictionary)[YokaiCard.DRAG_KEY]))


func _ready() -> void:
	_card_size = DataRegistry.tuning.get_int("assignment_card_size_px")
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	UiStyles.apply_panel(self)

	var box := VBoxContainer.new()
	add_child(box)
	var title_row := HBoxContainer.new()
	box.add_child(title_row)
	_title = UiStyles.header("")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title)
	_collapse_button = UiStyles.key_button(title_row, DataRegistry.text("ui_panel_collapse"), DataRegistry.text("key_hint_panel"),
		toggle_collapsed)
	_body = VBoxContainer.new()
	box.add_child(_body)
	# 카드 줄은 가로 스크롤 — 하숙생·손님이 늘어도 아래 드롭존이 화면 밖으로 밀리지 않는다
	_cards_scroll = ScrollContainer.new()
	_cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_cards_scroll.custom_minimum_size = Vector2(0, _card_size + CARD_ROW_EXTRA_PX)
	_body.add_child(_cards_scroll)
	_cards_box = HBoxContainer.new()
	_cards_scroll.add_child(_cards_box)
	# 드롭존 줄: 휴식 · 텃밭 · 동행 — 셋이 폭을 나눠 쓴다
	var row := HBoxContainer.new()
	_body.add_child(row)
	_rest_zone = Label.new()
	_rest_zone.text = DataRegistry.text("ui_rest_zone")
	_rest_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rest_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rest_zone.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 카드가 늘어 자리가 좁아지면 글자를 줄바꿈해 화면 밖으로 잘리지 않게 한다
	_rest_zone.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rest_zone.custom_minimum_size = Vector2(DataRegistry.tuning.get_int("rest_zone_min_width_px"), 0)
	row.add_child(_rest_zone)
	# 텃밭 자동화 슬롯 (docs/01 v3 2.2): 카드를 여기 놓으면 요괴가 낮에 물을 준다
	_field_zone = FieldZone.new()
	_field_zone.text = DataRegistry.text("ui_field_zone")
	_field_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_field_zone.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_field_zone.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_field_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field_zone.custom_minimum_size = Vector2(DataRegistry.tuning.get_int("rest_zone_min_width_px"), 0)
	_field_zone.on_drop = func(yokai_id: String) -> void: controller.try_assign(yokai_id, Assignment.FIELD)
	_field_zone.can_accept = func(yokai_id: String) -> bool:
		return controller.can_assign(yokai_id, Assignment.FIELD) == AssignmentController.Outcome.OK
	row.add_child(_field_zone)
	# 탐험 동행 슬롯 (P1-S4): 여기 놓인 하숙생이 잿빛 들에 따라와 자동으로 싸운다
	_party_zone = FieldZone.new()
	_party_zone.text = DataRegistry.text("ui_party_zone")
	_party_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_party_zone.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_party_zone.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_party_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_zone.custom_minimum_size = Vector2(DataRegistry.tuning.get_int("rest_zone_min_width_px"), 0)
	_party_zone.on_drop = func(yokai_id: String) -> void: controller.try_assign(yokai_id, Assignment.PARTY)
	_party_zone.can_accept = func(yokai_id: String) -> bool:
		return controller.can_assign(yokai_id, Assignment.PARTY) == AssignmentController.Outcome.OK
	row.add_child(_party_zone)
	# 위임 줄 (P3-S4 자동화 전환): 채집 · 낚시 · 판매 — 해금(feature delegate_*)되면 보인다
	_delegation_row = HBoxContainer.new()
	_body.add_child(_delegation_row)
	for cell: Vector2i in DELEGATION_FEATURES:
		var zone := FieldZone.new()
		zone.text = DataRegistry.text(DELEGATION_ZONE_KEYS[cell])
		zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		zone.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		zone.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zone.custom_minimum_size = Vector2(DataRegistry.tuning.get_int("rest_zone_min_width_px"), 0)
		var target := cell
		zone.on_drop = func(yokai_id: String) -> void: controller.try_assign(yokai_id, target)
		zone.can_accept = func(yokai_id: String) -> bool:
			return controller.can_assign(yokai_id, target) == AssignmentController.Outcome.OK
		_delegation_row.add_child(zone)
		_delegation_zones[cell] = zone
	Events.unlocked.connect(func(_id: String) -> void: _refresh_delegation_row())
	# 배치 패널은 집 안에서만 (마당·뒷산에서는 화면을 비운다)
	Events.region_entered.connect(func(region_id: String) -> void: visible = region_id == HouseRegion.REGION_ID)

	Events.assignment_changed.connect(func(_id: String, _cell: Vector2i) -> void: refresh())
	Events.condition_changed.connect(func(_id: String, _value: int) -> void: refresh())
	Events.affinity_changed.connect(func(_id: String, _value: int) -> void: refresh())
	Events.timeband_changed.connect(func(_band: int, _day: int) -> void: refresh())
	Events.room_changed.connect(func(_coords: Vector2i, _room_id: String) -> void: refresh())
	Events.game_loaded.connect(func(_slot: int) -> void: rebuild())
	Events.yokai_arrived.connect(func(_id: String) -> void: rebuild())
	Events.guests_changed.connect(rebuild)
	Events.game_loaded.connect(func(_slot: int) -> void: _refresh_delegation_row())
	_refresh_delegation_row()
	rebuild()


## 하숙생 + 손님 카드를 전부 다시 만든다. 카드 수 = 입주자 수 + 체류 손님 수.
func rebuild() -> void:
	for card: YokaiCard in _cards.values():
		card.queue_free()
	for card: YokaiCard in _guest_cards:
		card.queue_free()
	_cards.clear()
	_guest_cards.clear()
	for yokai_id in GameState.residents:
		var card := YokaiCard.new()
		card.setup(yokai_id, _texture(SPRITE_PATH % yokai_id), _card_size)
		card.rest_requested.connect(_on_rest_requested)
		_cards_box.add_child(card)
		_cards[yokai_id] = card
	var index := 0
	for guest: Dictionary in GameState.guests:
		var card := YokaiCard.new()
		card.setup_guest(guest, index, _texture(GUEST_SPRITE_PATH % str(guest.get("species_id", ""))), _card_size)
		_cards_box.add_child(card)
		_guest_cards.append(card)
		index += 1
	refresh()
	_fit_cards_row.call_deferred()


## 카드 줄 높이를 카드의 실제 최소 높이에 맞춘다 (세로 스크롤을 끈 채 잘리지 않게).
func _fit_cards_row() -> void:
	if _cards_scroll == null or _cards_box == null:
		return
	var needed := _cards_box.get_combined_minimum_size().y
	if needed > 0.0:
		_cards_scroll.custom_minimum_size = Vector2(0, needed)


## B: 카드·드롭존을 접거나 펼친다. 접혀도 제목 줄은 남아 다시 펼 수 있다.
func toggle_collapsed() -> void:
	collapsed = not collapsed
	_body.visible = not collapsed
	_collapse_button.text = "%s  %s" % [
		DataRegistry.text("ui_panel_expand" if collapsed else "ui_panel_collapse"), DataRegistry.text("key_hint_panel")]


func refresh() -> void:
	var morning := Clock.band == Clock.Band.MORNING
	_title.text = DataRegistry.text("ui_assignment_title" if morning else "ui_assignment_locked")
	for card: YokaiCard in _cards.values():
		card.drag_enabled = morning
		card.refresh()
	for card: YokaiCard in _guest_cards:
		card.refresh()


## 해금된 위임 슬롯만 보인다. 하나도 없으면 줄 자체를 숨긴다.
func _refresh_delegation_row() -> void:
	var any_open := false
	for cell: Vector2i in _delegation_zones:
		var open := not delegation_open_check.is_valid() or bool(delegation_open_check.call(cell))
		(_delegation_zones[cell] as Control).visible = open
		any_open = any_open or open
	_delegation_row.visible = any_open


## 보이는 위임 슬롯 수 (검증용).
func open_delegation_zones() -> int:
	var count := 0
	for cell: Vector2i in _delegation_zones:
		if (_delegation_zones[cell] as Control).visible:
			count += 1
	return count


func delegation_zone_rect(cell: Vector2i) -> Rect2:
	var zone := _delegation_zones.get(cell) as Control
	return zone.get_global_rect() if zone != null else Rect2()


## 드롭존 화면 사각형 (검증용 — 실제 마우스 드래그를 재현할 때 목적지로 쓴다).
func party_zone_rect() -> Rect2:
	return _party_zone.get_global_rect()


func field_zone_rect() -> Rect2:
	return _field_zone.get_global_rect()


## 드롭존 세 개가 전부 뷰포트 안에 있는지 (검증용 — 카드가 늘어도 조작이 막히지 않아야 한다).
func zones_on_screen() -> bool:
	var width := get_viewport_rect().size.x
	for zone: Control in [_rest_zone, _field_zone, _party_zone]:
		var rect := zone.get_global_rect()
		if rect.size.x <= 0.0 or rect.end.x > width + 0.5 or rect.position.x < -0.5:
			return false
	return true


func get_card(yokai_id: String) -> YokaiCard:
	return _cards.get(yokai_id) as YokaiCard


func card_count() -> int:
	return _cards.size() + _guest_cards.size()


func guest_card_count() -> int:
	return _guest_cards.size()


func _texture(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has(YokaiCard.DRAG_KEY)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_on_rest_requested(str((data as Dictionary)[YokaiCard.DRAG_KEY]))


func _on_rest_requested(yokai_id: String) -> void:
	controller.try_rest(yokai_id)
