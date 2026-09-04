class_name DialogueBox
extends Control
## 대화창: 일러스트(자리표시) + 화자 + 대사 + 다음/선택지 버튼. StorySystem 의 노드를 받아 표시한다.
## 열려 있는 동안 배경이 다른 입력을 막는다. 일러스트 노드만 Linear 필터 예외 (CLAUDE.md 5.6).

const PORTRAIT_PATH := "res://assets/art_generated/illust_%s.png"
const PANEL_WIDTH_RATIO := 0.8

var story: StorySystem

var _backdrop: Control
var _panel: PanelContainer
var _portrait: TextureRect
var _speaker: Label
var _text: Label
var _buttons: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var tuning := DataRegistry.tuning
	var portrait_size := tuning.get_int("portrait_size_px")

	_backdrop = Control.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_panel = PanelContainer.new()
	UiStyles.apply_panel(_panel)
	add_child(_panel)
	var row := HBoxContainer.new()
	_panel.add_child(row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(portrait_size, portrait_size)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_SCALE
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	row.add_child(_portrait)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_speaker = Label.new()
	column.add_child(_speaker)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_text)
	_buttons = HBoxContainer.new()
	column.add_child(_buttons)

	var view_size := get_viewport_rect().size
	_panel.custom_minimum_size = Vector2(view_size.x * PANEL_WIDTH_RATIO, tuning.get_int("dialogue_box_height_px"))
	_panel.position = Vector2(view_size.x * (1.0 - PANEL_WIDTH_RATIO) * 0.5, view_size.y * 0.5 - _panel.custom_minimum_size.y * 0.5).round()

	story.node_entered.connect(_on_node_entered)
	story.ended.connect(func(_event: EventData) -> void: visible = false)


func _on_node_entered(node: DialogueGraph.DialogueNode, _event: EventData) -> void:
	visible = true
	_speaker.text = DataRegistry.speaker_name(node.speaker)
	_text.text = node.text
	_portrait.texture = ArtLibrary.texture("illust.%s" % node.portrait) if not node.portrait.is_empty() else null
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	if node.has_options():
		for i in node.options.size():
			_add_button(str(node.options[i]["text"]), story.choose.bind(i))
	else:
		_add_button(DataRegistry.text("ui_dialogue_next"), story.advance)


func _add_button(text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	_buttons.add_child(button)
