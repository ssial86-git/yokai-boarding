class_name TutorialSystem
extends Node
## 성주 영감 안내: 플레이어의 첫 행동을 플래그로 기록하고, 상황에 맞는 hints.csv 문구를 hint_changed 로 내보낸다.
## 대화형 튜토리얼(events.csv tutorial) 과 짝을 이루는 '조용한' 안내 층.

const FLAG_FIRST_ASSIGNMENT := "first_assignment_done"
const FLAG_FIRST_DAY := "first_day_started"
const FLAG_FIRST_BUILD := "first_build_done"
const FLAG_FIRST_INTAKE := "first_intake_done"
const FLAG_EXTRA_BED := "first_extra_bed"

var current_hint: HintData


func _ready() -> void:
	Events.assignment_changed.connect(func(_id: String, cell: Vector2i) -> void:
		if cell != Assignment.REST:
			_set_flag(FLAG_FIRST_ASSIGNMENT))
	Events.timeband_changed.connect(func(band: int, _day: int) -> void:
		if band == Clock.Band.DAY:
			_set_flag(FLAG_FIRST_DAY)
		refresh())
	Events.room_changed.connect(func(_coords: Vector2i, room_id: String) -> void:
		var room := DataRegistry.get_room(room_id)
		if room != null and room.kind != RoomGrid.ROOM_KIND_EMPTY:
			_set_flag(FLAG_FIRST_BUILD)
		if room != null and room.kind == "lodging":
			_set_flag(FLAG_EXTRA_BED))
	Events.floor_added.connect(func(_floor: int) -> void: _set_flag(FLAG_FIRST_BUILD))
	Events.intake_decided.connect(func(_visitor: Dictionary, outcome: int) -> void:
		if outcome != Intake.Outcome.NO_BED:
			_set_flag(FLAG_FIRST_INTAKE))
	Events.day_started.connect(func(_day: int) -> void: refresh())
	Events.game_loaded.connect(func(_slot: int) -> void: refresh())
	refresh()


## force: 바뀌지 않았어도 다시 알린다 (HUD 가 나중에 만들어졌을 때 초기 문구를 받도록).
func refresh(force: bool = false) -> void:
	var hint := HintPicker.pick(DataRegistry.hints, Clock.band_name(), GameState.day, GameState.flags)
	if hint == current_hint and not force:
		return
	current_hint = hint
	Events.hint_changed.emit(hint.text_ko if hint != null else "")


func _set_flag(flag: String) -> void:
	if GameState.flags.has(flag):
		return
	GameState.flags[flag] = true
	refresh()
