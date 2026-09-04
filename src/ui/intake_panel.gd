class_name IntakePanel
extends Control
## 저녁 심사 카드 (문돌이의 의인화). 방문자 스프라이트·첫마디·액운 냄새를 보여주고 받기/거절을 받는다.
## 빈 카드(말소 미수)는 이름·얼굴 없이 표시된다.

const GUEST_SPRITE_PATH := "res://assets/art_generated/guest_%s.png"
const PANEL_WIDTH_RATIO := 0.6

var intake: IntakeSystem

var _backdrop: Control
var _panel: PanelContainer
var _title: Label
var _intro: Label
var _icon: TextureRect
var _card: Label
var _accept: Button
var _decline: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_backdrop = Control.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_panel = PanelContainer.new()
	UiStyles.apply_panel(_panel)
	add_child(_panel)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	_title = Label.new()
	column.add_child(_title)
	_intro = Label.new()
	_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_intro)
	var row := HBoxContainer.new()
	column.add_child(row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(32, 32)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(_icon)
	_card = Label.new()
	_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_card)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_accept = Button.new()
	_accept.pressed.connect(func() -> void: intake.decide(Intake.Decision.ACCEPT))
	buttons.add_child(_accept)
	_decline = Button.new()
	_decline.text = DataRegistry.text("ui_intake_decline")
	_decline.pressed.connect(func() -> void: intake.decide(Intake.Decision.DECLINE))
	buttons.add_child(_decline)

	var view_size := get_viewport_rect().size
	_panel.custom_minimum_size = Vector2(view_size.x * PANEL_WIDTH_RATIO, 0)
	_panel.position = Vector2(view_size.x * (1.0 - PANEL_WIDTH_RATIO) * 0.5, view_size.y * 0.25).round()

	Events.visitor_knocked.connect(_on_visitor_knocked)
	Events.intake_decided.connect(_on_intake_decided)


func _on_visitor_knocked(visitor: Dictionary) -> void:
	if visitor.is_empty():
		return
	var data := VisitorRoll.Visitor.from_dict(visitor)
	var visitor_type := DataRegistry.get_visitor(data.visitor_id)
	_title.text = DataRegistry.text("ui_intake_title")
	_intro.text = visitor_type.intro_ko if visitor_type != null else ""
	if data.kind == "erased":
		_icon.texture = null
		_card.text = DataRegistry.text("ui_intake_card_empty")
	else:
		var species := DataRegistry.get_guest_species(data.species_id)
		_icon.texture = ArtLibrary.icon("guest.%s" % data.species_id)
		# 장기 계약(P2-S4)은 액운 대신 "받으면 하숙생" 안내
		var card_key := "ui_intake_card_promotion" if data.kind == Intake.KIND_PROMOTION else "ui_intake_card"
		_card.text = DataRegistry.text(card_key, {
			"name": species.name_ko if species != null else data.species_id,
			"first_words": species.first_words_ko if species != null else "",
			"omen": data.omen,
		})
	_refresh_accept()
	visible = true


func _refresh_accept() -> void:
	var beds := intake.free_beds()
	_accept.disabled = beds <= 0
	_accept.text = DataRegistry.text("ui_intake_accept" if beds > 0 else "ui_intake_no_bed")


func _on_intake_decided(_visitor: Dictionary, outcome: int) -> void:
	if outcome == Intake.Outcome.NO_BED:
		_refresh_accept()
		return
	visible = false
