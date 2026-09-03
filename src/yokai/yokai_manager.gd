class_name YokaiManager
extends Node2D
## 입주 하숙생마다 YokaiActor 를 만들고, 시간대에 따라 일터/휴식처로 보낸다.
## 낮(DAY)에는 배치된 칸으로 가서 일하고, 그 외 시간대에는 휴식처(첫 객실)로 돌아온다.

const SPRITE_PATH := "res://assets/art_generated/yokai_%s.png"
const GUEST_SPRITE_PATH := "res://assets/art_generated/guest_%s.png"

## 칸 좌표 → 월드 사각형을 아는 뷰. main.gd 가 넣는다.
var house_view: HouseView

var _actors: Dictionary = {}  # yokai_id -> YokaiActor
var _stair_column: int = 0
var _slot_spacing: int = 12
var _walk_speed: float = 40.0
var _bob_px: float = 2.0
var _bob_seconds: float = 0.5


func _ready() -> void:
	var tuning := DataRegistry.tuning
	_stair_column = tuning.get_int("stair_column")
	_slot_spacing = tuning.get_int("yokai_slot_spacing_px")
	_walk_speed = tuning.get_float("yokai_walk_speed_px")
	_bob_px = float(tuning.get_int("yokai_work_bob_px"))
	_bob_seconds = tuning.get_float("yokai_work_bob_seconds")
	Events.timeband_changed.connect(func(band: int, _day: int) -> void: dispatch_all(band))
	Events.game_loaded.connect(func(_slot: int) -> void: respawn())
	Events.yokai_arrived.connect(func(_id: String) -> void: respawn())
	Events.guests_changed.connect(respawn)
	Events.room_changed.connect(func(_coords: Vector2i, _room_id: String) -> void: dispatch_all(Clock.band))
	Events.floor_added.connect(func(_floor: int) -> void: dispatch_all(Clock.band))
	Events.affinity_changed.connect(func(yokai_id: String, _value: int) -> void: apply_presentation(yokai_id))
	respawn()


## 호감도에 따른 또렷함과 밤 등불지기 빛을 액터에 반영한다.
func apply_presentation(yokai_id: String) -> void:
	var actor := get_actor(yokai_id)
	var yokai := DataRegistry.get_yokai(yokai_id)
	if actor == null or yokai == null:
		return
	var tuning := DataRegistry.tuning
	actor.set_clarity(Clarity.alpha_for(
		yokai, int(GameState.affinity.get(yokai_id, 0)),
		tuning.get_float("clarity_alpha_min"), tuning.get_int("clarity_affinity_max")))
	var glow := 0.0
	if yokai.night_worker and Clock.band == Clock.Band.NIGHT:
		glow = tuning.get_float("night_worker_glow_energy")
	actor.set_glow(glow, tuning.get_int("night_worker_glow_radius_px"),
		Color.html(tuning.get_string("lantern_color")), house_view.lantern_texture())


func apply_presentation_all() -> void:
	for yokai_id in GameState.residents:
		apply_presentation(yokai_id)


func get_actor(yokai_id: String) -> YokaiActor:
	return _actors.get(yokai_id) as YokaiActor


func actor_count() -> int:
	return _actors.size()


func respawn() -> void:
	for actor: YokaiActor in _actors.values():
		actor.queue_free()
	_actors.clear()
	var home := DaySettlement.rest_cell(GameState.room_grid)
	var slot := 0
	for yokai_id in GameState.residents:
		var actor := YokaiActor.new()
		var path := SPRITE_PATH % yokai_id
		var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
		actor.setup(yokai_id, texture, _walk_speed, _bob_px, _bob_seconds)
		actor.anchor_for = _anchor_for
		add_child(actor)
		actor.place_at(home, slot, YokaiActor.State.RESTING)
		_actors[yokai_id] = actor
		slot += 1
	# 체류 중인 뜨내기 손님은 휴식처에 머무는 액터로만 보여준다 (배치·이동 없음)
	var guest_index := 0
	for guest: Dictionary in GameState.guests:
		var species_id := str(guest.get("species_id", ""))
		var actor := YokaiActor.new()
		var path := GUEST_SPRITE_PATH % species_id
		var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
		var actor_id := "guest_%d_%s" % [guest_index, species_id]
		actor.setup(actor_id, texture, _walk_speed, _bob_px, _bob_seconds)
		actor.anchor_for = _anchor_for
		add_child(actor)
		actor.place_at(home, slot, YokaiActor.State.RESTING)
		_actors[actor_id] = actor
		slot += 1
		guest_index += 1
	dispatch_all(Clock.band)
	apply_presentation_all()


## 시간대에 맞는 목적지로 전원 출발. 같은 칸을 향하는 요괴는 slot 으로 가로 위치를 나눈다.
func dispatch_all(band: int) -> void:
	apply_presentation_all()
	var grid := GameState.room_grid
	var home := DaySettlement.rest_cell(grid)
	var slots_used: Dictionary = {}  # cell -> count
	for yokai_id in GameState.residents:
		var actor := get_actor(yokai_id)
		if actor == null:
			continue
		var work_cell := GameState.assignment.get_cell(yokai_id)
		var goes_to_work := band == Clock.Band.DAY and work_cell != Assignment.REST \
			and grid.is_in_bounds(work_cell) and grid.is_floor_built(work_cell.y)
		var target := work_cell if goes_to_work else home
		var slot := int(slots_used.get(target, 0))
		slots_used[target] = slot + 1
		var then_state := YokaiActor.State.WORKING if goes_to_work else YokaiActor.State.RESTING
		if actor.current_cell == target and actor.state != YokaiActor.State.WALKING:
			actor.place_at(target, slot, then_state)
			continue
		var path := RoomGraph.find_path(grid, actor.current_cell, target, _stair_column)
		if path.is_empty():
			actor.place_at(target, slot, then_state)  # 닿을 수 없으면 순간이동 (그래프가 끊긴 비정상 상황)
		else:
			actor.walk_to(path, slot, then_state)


func _anchor_for(cell: Vector2i, slot: int) -> Vector2:
	var rect := house_view.cell_rect(cell)
	var x := rect.position.x + rect.size.x * 0.5 + float(slot - 1) * _slot_spacing
	return Vector2(x, rect.end.y)
