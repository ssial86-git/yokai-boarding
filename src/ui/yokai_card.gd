class_name YokaiCard
extends PanelContainer
## 배치 패널의 카드. 하숙생 카드는 드래그 원본(_get_drag_data)이고, 손님 카드는 드래그할 수 없는 정보 표시다.
## 카드 위에 다른 카드를 놓으면 그 요괴는 휴식. 640x360 뷰포트에서 패널이 집을 가리지 않도록 납작하게 둔다.

signal rest_requested(yokai_id: String)

const DRAG_KEY := "yokai_id"

var yokai_id: String = ""
var guest: Dictionary = {}  # 비어 있지 않으면 손님 카드
var drag_enabled: bool = true

var _icon: TextureRect
var _name_label: Label
var _status_label: Label


func setup(id: String, texture: Texture2D, icon_size: int) -> void:
	yokai_id = id
	name = "Card_%s" % id
	_build(texture, icon_size)


func setup_guest(record: Dictionary, index: int, texture: Texture2D, icon_size: int) -> void:
	guest = record
	yokai_id = ""
	name = "GuestCard_%d" % index
	drag_enabled = false
	_build(texture, icon_size)


func is_guest() -> bool:
	return not guest.is_empty()


func refresh() -> void:
	if is_guest():
		_refresh_guest()
		return
	var yokai := DataRegistry.get_yokai(yokai_id)
	if yokai == null:
		return
	_name_label.text = yokai.name_ko
	var tuning := DataRegistry.tuning
	_icon.modulate.a = Clarity.alpha_for(yokai, int(GameState.affinity.get(yokai_id, 0)),
		tuning.get_float("clarity_alpha_min"), tuning.get_int("clarity_affinity_max"))
	var cell := GameState.assignment.get_cell(yokai_id)
	var place := DataRegistry.text("card_rest") if cell == Assignment.REST \
		else DataRegistry.room_name(GameState.room_grid.get_room_id(cell))
	_status_label.text = DataRegistry.text("card_status", {
		"place": place, "condition": GameState.get_condition(yokai_id)})
	tooltip_text = DataRegistry.text("card_tooltip", {
		"name": yokai.name_ko,
		"species": yokai.species_ko,
		"room": DataRegistry.room_name(yokai.preferred_room),
		"bonus": roundi(yokai.work_bonus * 100.0),
		"noise": yokai.noise,
		"condition": GameState.get_condition(yokai_id),
	})


func _refresh_guest() -> void:
	var species_id := str(guest.get("species_id", ""))
	var species := DataRegistry.get_guest_species(species_id)
	_name_label.text = DataRegistry.text("card_guest_name", {"name": DataRegistry.species_name(species_id)})
	var nights := maxi(0, int(guest.get("depart_day", GameState.day)) - GameState.day)
	_status_label.text = DataRegistry.text("card_guest_status", {"nights": nights})
	tooltip_text = DataRegistry.text("card_guest_tooltip", {
		"name": DataRegistry.species_name(species_id),
		"flavor": species.flavor_ko if species != null else "",
		"rent": species.rent_note_ko if species != null else "",
	})


func _build(texture: Texture2D, icon_size: int) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	add_child(row)
	_icon = TextureRect.new()
	_icon.texture = texture
	_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(_icon)
	var lines := VBoxContainer.new()
	row.add_child(lines)
	_name_label = Label.new()
	lines.add_child(_name_label)
	_status_label = Label.new()
	lines.add_child(_status_label)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not drag_enabled or is_guest():
		return null
	var preview := TextureRect.new()
	preview.texture = _icon.texture
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.modulate.a = 0.8
	set_drag_preview(preview)
	return {DRAG_KEY: yokai_id}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return drag_enabled and not is_guest() and data is Dictionary and (data as Dictionary).has(DRAG_KEY)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	rest_requested.emit(str((data as Dictionary)[DRAG_KEY]))
