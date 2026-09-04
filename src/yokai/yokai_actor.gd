class_name YokaiActor
extends Node2D
## 요괴 한 명의 화면 표현과 상태머신(이동 → 일 → 휴식). 규칙은 갖지 않는다.
## 이동은 YokaiManager 가 넘겨준 칸 경로를 따라 직선으로 걷는다 (내비메시 없음).

enum State { IDLE, WALKING, WORKING, RESTING }

signal arrived(yokai_id: String, cell: Vector2i)

var yokai_id: String = ""
var current_cell: Vector2i = Vector2i.ZERO
var target_cell: Vector2i = Vector2i.ZERO
var slot_index: int = 0
var state: State = State.IDLE

## (cell: Vector2i, slot: int) -> Vector2 발 위치(월드). YokaiManager 가 넣는다.
var anchor_for: Callable

## 아트 매니페스트 키(char.<id> / guest.<species>)로 만든 애니메이션 스프라이트. 그림이 없으면 null (보이지 않지만 규칙은 돈다)
var _sprite: AnimatedSprite2D
var _art_key: String = ""
var _frame_h: float = 32.0
## 실수 위치. position 은 픽셀 스냅을 위해 여기서 반올림한 값만 받는다 (프레임당 이동량이 1px 미만이어도 누적되게).
var _exact_position: Vector2 = Vector2.ZERO
var _path: Array[Vector2i] = []
var _state_after_arrival: State = State.IDLE
var _walk_speed: float = 40.0
var _bob_px: float = 2.0
var _bob_seconds: float = 0.5
var _time: float = 0.0


## art_key: ArtLibrary 키 (char.<yokai_id> / guest.<species_id>). 시트에 idle/walk/work 가 있으면 상태에 따라 재생한다.
func setup(id: String, art_key: String, walk_speed: float, bob_px: float, bob_seconds: float) -> void:
	yokai_id = id
	name = "Yokai_%s" % id
	_walk_speed = walk_speed
	_bob_px = bob_px
	_bob_seconds = bob_seconds
	_art_key = art_key
	_sprite = ArtLibrary.make_sprite(art_key)
	if _sprite != null:
		_frame_h = float(ArtLibrary.frame_size(art_key).y)
		add_child(_sprite)


## '또렷함' (어둑이): 스프라이트 투명도.
func set_clarity(alpha: float) -> void:
	if _sprite != null:
		_sprite.modulate.a = clampf(alpha, 0.0, 1.0)


func get_clarity() -> float:
	return _sprite.modulate.a if _sprite != null else 1.0


## 밤 등불지기 연출: 요괴 주변 빛. energy 0 이면 끈다.
func set_glow(energy: float, radius_px: int, color: Color, texture: Texture2D) -> void:
	var light := get_node_or_null("Glow") as PointLight2D
	if energy <= 0.0:
		if light != null:
			light.queue_free()
		return
	if light == null:
		light = PointLight2D.new()
		light.name = "Glow"
		light.texture = texture
		light.blend_mode = Light2D.BLEND_MODE_ADD
		add_child(light)
	light.energy = energy
	light.color = color
	light.texture_scale = float(radius_px * 2) / float(texture.get_width()) if texture != null else 1.0
	light.position = Vector2(0, -(_frame_h * 0.5 if _sprite != null else 0.0))


func place_at(cell: Vector2i, slot: int, then_state: State) -> void:
	current_cell = cell
	target_cell = cell
	slot_index = slot
	_path.clear()
	_exact_position = _anchor(cell)
	position = _exact_position
	_set_state(then_state)


## path 는 현재 칸을 포함한 칸 목록. 비어 있거나 한 칸이면 즉시 도착 처리.
func walk_to(path: Array[Vector2i], slot: int, then_state: State) -> void:
	slot_index = slot
	_state_after_arrival = then_state
	if path.size() <= 1:
		var cell := path[0] if path.size() == 1 else current_cell
		place_at(cell, slot, then_state)
		arrived.emit(yokai_id, cell)
		return
	target_cell = path[path.size() - 1]
	_path = path.duplicate()
	_path.pop_front()  # 첫 칸은 지금 서 있는 칸
	_set_state(State.WALKING)


func _process(delta: float) -> void:
	_time += delta
	match state:
		State.WALKING:
			_step(delta)
		State.WORKING:
			# 시트에 work 애니메이션이 없으면(자리표시) 들썩임으로 대신한다
			if _sprite != null and _bob_seconds > 0.0 and not ArtLibrary.has_anim(_art_key, ArtLibrary.ANIM_WORK):
				var bob := absf(sin(_time * PI / _bob_seconds)) * _bob_px
				_sprite.offset.y = -_frame_h * 0.5 - bob
		_:
			pass


func _step(delta: float) -> void:
	if _path.is_empty():
		_finish_walk()
		return
	var next_cell: Vector2i = _path[0]
	var goal := _anchor(next_cell)
	var to_goal := goal - _exact_position
	var step := _walk_speed * delta
	if _sprite != null and absf(to_goal.x) > 0.5:
		_sprite.flip_h = to_goal.x < 0.0
	if to_goal.length() <= step:
		_exact_position = goal
		current_cell = next_cell
		_path.pop_front()
		if _path.is_empty():
			_finish_walk()
	else:
		_exact_position += to_goal.normalized() * step
	position = _exact_position.round()


func _finish_walk() -> void:
	current_cell = target_cell
	_exact_position = _anchor(target_cell)
	position = _exact_position
	_set_state(_state_after_arrival)
	arrived.emit(yokai_id, current_cell)


func _set_state(new_state: State) -> void:
	state = new_state
	_time = 0.0
	if _sprite != null:
		_sprite.offset.y = -_frame_h * 0.5
		match new_state:
			State.WALKING:
				ArtLibrary.play(_sprite, ArtLibrary.ANIM_WALK)
			State.WORKING:
				ArtLibrary.play(_sprite, ArtLibrary.ANIM_WORK)
			_:
				ArtLibrary.play(_sprite, ArtLibrary.ANIM_IDLE)


func _anchor(cell: Vector2i) -> Vector2:
	if anchor_for.is_valid():
		return (anchor_for.call(cell, slot_index) as Vector2).round()
	return position
