class_name AssignmentPanel
extends PanelContainer
## 화면 아래 배치 패널: 하숙생 카드 목록 + 휴식 놓기 영역. 카드를 방(DropLayer)이나 이 패널로 끌어 놓는다.
## 아침이 아니면 카드 드래그를 잠근다.

const SPRITE_PATH := "res://assets/art_generated/yokai_%s.png"

var controller: AssignmentController

var _title: Label
var _cards_box: HBoxContainer
var _cards: Dictionary = {}  # yokai_id -> YokaiCard
var _rest_zone: Label
var _card_size: int = 40


func _ready() -> void:
	_card_size = DataRegistry.tuning.get_int("assignment_card_size_px")
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP

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
	row.add_child(_rest_zone)

	Events.assignment_changed.connect(func(_id: String, _cell: Vector2i) -> void: refresh())
	Events.condition_changed.connect(func(_id: String, _value: int) -> void: refresh())
	Events.phase_changed.connect(func(_phase: int, _day: int) -> void: refresh())
	Events.room_changed.connect(func(_coords: Vector2i, _room_id: String) -> void: refresh())
	Events.game_loaded.connect(func(_slot: int) -> void: rebuild())
	rebuild()


func rebuild() -> void:
	for card: YokaiCard in _cards.values():
		card.queue_free()
	_cards.clear()
	for yokai_id in GameState.residents:
		var card := YokaiCard.new()
		var path := SPRITE_PATH % yokai_id
		var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
		card.setup(yokai_id, texture, _card_size)
		card.rest_requested.connect(_on_rest_requested)
		_cards_box.add_child(card)
		_cards[yokai_id] = card
	refresh()


func refresh() -> void:
	var morning := Clock.phase == Clock.Phase.MORNING
	_title.text = DataRegistry.text("ui_assignment_title" if morning else "ui_assignment_locked")
	for card: YokaiCard in _cards.values():
		card.drag_enabled = morning
		card.refresh()


func get_card(yokai_id: String) -> YokaiCard:
	return _cards.get(yokai_id) as YokaiCard


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has(YokaiCard.DRAG_KEY)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_on_rest_requested(str((data as Dictionary)[YokaiCard.DRAG_KEY]))


func _on_rest_requested(yokai_id: String) -> void:
	controller.try_rest(yokai_id)
