class_name AssignmentPanel
extends PanelContainer
## 화면 아래 배치 패널: 하숙생 카드(드래그) + 체류 중 손님 카드(정보만) + 휴식 놓기 영역.
## 아침이 아니면 카드 드래그를 잠근다.

const SPRITE_PATH := "res://assets/art_generated/yokai_%s.png"
const GUEST_SPRITE_PATH := "res://assets/art_generated/guest_%s.png"

var controller: AssignmentController

var _title: Label
var _cards_box: HBoxContainer
var _cards: Dictionary = {}  # yokai_id -> YokaiCard (하숙생)
var _guest_cards: Array[YokaiCard] = []
var _rest_zone: Label
var _card_size: int = 40


func _ready() -> void:
	_card_size = DataRegistry.tuning.get_int("assignment_card_size_px")
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	UiStyles.apply_panel(self)

	var box := VBoxContainer.new()
	add_child(box)
	_title = Label.new()
	box.add_child(_title)
	var row := HBoxContainer.new()
	box.add_child(row)
	_cards_box = HBoxContainer.new()
	row.add_child(_cards_box)
	_rest_zone = Label.new()
	_rest_zone.text = DataRegistry.text("ui_rest_zone")
	_rest_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rest_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rest_zone.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 카드가 늘어 자리가 좁아지면 글자를 줄바꿈해 화면 밖으로 잘리지 않게 한다
	_rest_zone.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rest_zone.custom_minimum_size = Vector2(DataRegistry.tuning.get_int("rest_zone_min_width_px"), 0)
	row.add_child(_rest_zone)

	Events.assignment_changed.connect(func(_id: String, _cell: Vector2i) -> void: refresh())
	Events.condition_changed.connect(func(_id: String, _value: int) -> void: refresh())
	Events.affinity_changed.connect(func(_id: String, _value: int) -> void: refresh())
	Events.timeband_changed.connect(func(_band: int, _day: int) -> void: refresh())
	Events.room_changed.connect(func(_coords: Vector2i, _room_id: String) -> void: refresh())
	Events.game_loaded.connect(func(_slot: int) -> void: rebuild())
	Events.yokai_arrived.connect(func(_id: String) -> void: rebuild())
	Events.guests_changed.connect(rebuild)
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


func refresh() -> void:
	var morning := Clock.band == Clock.Band.MORNING
	_title.text = DataRegistry.text("ui_assignment_title" if morning else "ui_assignment_locked")
	for card: YokaiCard in _cards.values():
		card.drag_enabled = morning
		card.refresh()
	for card: YokaiCard in _guest_cards:
		card.refresh()


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
