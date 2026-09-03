class_name PlayerController
extends CharacterBody2D
## 주인공 직접 조작 (docs/01 v3 2.1 걷기·달리기): 좌우 이동, 경사로(단차), 사다리·계단, 달리기(스태미너), E 상호작용.
## 정밀 플랫포밍 없음 — 점프가 없고 높이는 경사로와 사다리로만 바뀐다. 수치는 전부 tuning(player_*, stamina_*).
## 대화·심사(Clock hold)나 메뉴가 열려 있으면 움직이지 않는다.

signal interacted(target: Interactable)

const SPRITE_PATH := "res://assets/art_generated/player.png"
const LADDER_GROUP := &"ladder"
const LADDER_LAYER_BIT := 4
const WORLD_LAYER_BIT := 1
const ACTION_LEFT := &"move_left"
const ACTION_RIGHT := &"move_right"
const ACTION_UP := &"move_up"
const ACTION_DOWN := &"move_down"
const ACTION_RUN := &"run"
const ACTION_INTERACT := &"interact"

## () -> bool. 메뉴가 열려 있는 등 조작을 막아야 할 때 true. main.gd 가 넣는다.
var blocked_check: Callable
## () -> bool. 이동만 막고 E 는 듣는 상태 (낚시 중). main.gd 가 넣는다.
var movement_locked_check: Callable
var controls_enabled: bool = true
## 테스트·자동 플레이용 가상 입력 (-1 / 0 / 1). 실제 입력과 더해진다.
var virtual_axis: Vector2 = Vector2.ZERO
var virtual_run: bool = false

var facing: int = 1
var climbing: bool = false
var running: bool = false
var current_target: Interactable

var _walk_speed: float = 70.0
var _run_speed: float = 120.0
var _climb_speed: float = 55.0
var _gravity: float = 900.0
var _max_fall: float = 400.0
var _sprite: Sprite2D
var _sensor: Area2D
var _ladder_sensor: Area2D
var _ladders: int = 0
var _last_prompt: String = ""
var _was_exhausted: bool = false


func _ready() -> void:
	var tuning := DataRegistry.tuning
	_walk_speed = tuning.get_float("player_walk_speed_px", _walk_speed)
	_run_speed = tuning.get_float("player_run_speed_px", _run_speed)
	_climb_speed = tuning.get_float("player_climb_speed_px", _climb_speed)
	_gravity = tuning.get_float("player_gravity_px", _gravity)
	_max_fall = tuning.get_float("player_max_fall_speed_px", _max_fall)
	floor_max_angle = deg_to_rad(tuning.get_float("player_floor_max_angle_deg", 50.0))
	floor_snap_length = 8.0
	collision_layer = WORLD_LAYER_BIT
	collision_mask = WORLD_LAYER_BIT

	var body := RectangleShape2D.new()
	body.size = Vector2(tuning.get_int("player_body_width_px"), tuning.get_int("player_body_height_px"))
	var collider := CollisionShape2D.new()
	collider.shape = body
	collider.position = Vector2(0, -body.size.y * 0.5)  # 발이 position
	add_child(collider)

	_sprite = Sprite2D.new()
	if ResourceLoader.exists(SPRITE_PATH):
		_sprite.texture = load(SPRITE_PATH) as Texture2D
		_sprite.position = Vector2(0, -_sprite.texture.get_height() * 0.5)
	add_child(_sprite)

	_sensor = _make_sensor(Interactable.LAYER_BIT, tuning.get_float("player_interact_radius_px"), body.size.y * 0.5)
	_ladder_sensor = _make_sensor(LADDER_LAYER_BIT, body.size.x * 0.5, body.size.y * 0.5)
	_ladder_sensor.area_entered.connect(func(_area: Area2D) -> void: _ladders += 1)
	_ladder_sensor.area_exited.connect(func(_area: Area2D) -> void:
		_ladders = maxi(_ladders - 1, 0)
		if _ladders == 0:
			climbing = false)


func stamina() -> Stamina:
	return GameState.stamina


func is_controllable() -> bool:
	if not controls_enabled or Clock.is_held():
		return false
	if blocked_check.is_valid() and bool(blocked_check.call()):
		return false
	return true


func on_ladder() -> bool:
	return _ladders > 0


func _physics_process(delta: float) -> void:
	var axis := Vector2.ZERO
	var wants_run := false
	if is_controllable():
		axis = Vector2(
			Input.get_action_strength(ACTION_RIGHT) - Input.get_action_strength(ACTION_LEFT),
			Input.get_action_strength(ACTION_DOWN) - Input.get_action_strength(ACTION_UP),
		) + virtual_axis
		axis = axis.clamp(Vector2(-1, -1), Vector2(1, 1))
		wants_run = Input.is_action_pressed(ACTION_RUN) or virtual_run
		if movement_locked_check.is_valid() and bool(movement_locked_check.call()):
			axis = Vector2.ZERO
			wants_run = false

	if _ladders > 0 and axis.y != 0.0:
		climbing = true
	if climbing and _ladders == 0:
		climbing = false

	var stamina_state := stamina()
	running = wants_run and axis.x != 0.0 and not stamina_state.is_exhausted() and not climbing
	var speed := (_run_speed if running else _walk_speed) * stamina_state.speed_multiplier()
	if climbing:
		collision_mask = 0  # 사다리를 타는 동안 층 바닥을 통과한다
		velocity = Vector2(axis.x * _walk_speed * 0.5, axis.y * _climb_speed)
	else:
		collision_mask = WORLD_LAYER_BIT
		velocity.x = axis.x * speed
		if not is_on_floor():
			velocity.y = minf(velocity.y + _gravity * delta, _max_fall)
		elif velocity.y > 0.0:
			velocity.y = 0.0
	move_and_slide()

	if running:
		stamina_state.drain(delta)
	elif axis == Vector2.ZERO:
		stamina_state.regen(delta)
	Events.stamina_changed.emit(stamina_state.value, stamina_state.params.max_value)
	if stamina_state.is_exhausted() != _was_exhausted:
		_was_exhausted = stamina_state.is_exhausted()
		if _was_exhausted:
			Metrics.record("stamina", {"value": stamina_state.value})
			Events.message_posted.emit(DataRegistry.text("msg_stamina_out"))

	if axis.x != 0.0:
		facing = 1 if axis.x > 0.0 else -1
		if _sprite != null:
			_sprite.flip_h = facing < 0
	_refresh_target()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_INTERACT):
		if try_interact():
			get_viewport().set_input_as_handled()


## 지금 잡힌 대상과 상호작용. 테스트·자동 플레이도 이 함수를 부른다.
func try_interact() -> bool:
	if not is_controllable() or current_target == null or not current_target.can_interact():
		return false
	current_target.interact(self)
	interacted.emit(current_target)
	_refresh_target()
	return true


## 구역 이동 뒤 발 위치를 다시 잡는다.
func place(feet: Vector2) -> void:
	global_position = feet.round()
	velocity = Vector2.ZERO
	climbing = false
	_ladders = 0


## 가장 가까운(우선순위 높은) 상호작용 대상을 고르고 안내 문구를 알린다.
func _refresh_target() -> void:
	var best: Interactable = null
	var best_score := INF
	for area in _sensor.get_overlapping_areas():
		var target := area as Interactable
		if target == null or target.prompt().is_empty():
			continue
		var score := global_position.distance_to(target.global_position) - float(target.interact_priority) * 1000.0
		if score < best_score:
			best_score = score
			best = target
	current_target = best
	var prompt := best.prompt() if best != null else ""
	if prompt != _last_prompt:
		_last_prompt = prompt
		Events.prompt_changed.emit(prompt)


func _make_sensor(mask: int, radius: float, center_y: float) -> Area2D:
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = mask
	sensor.monitorable = false
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(0, -center_y)
	sensor.add_child(collider)
	add_child(sensor)
	return sensor
