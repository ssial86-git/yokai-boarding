class_name HouseView
extends Node2D
## RoomGrid 상태를 구독해 단면을 그린다. 월드 좌표: 1층 바닥이 y=0, 위층으로 갈수록 y 감소.
## 입력 판정은 HouseCamera 가 하고, 여기서는 월드 좌표 -> 칸 변환과 호버·플래시 표시만 맡는다.

const ROOM_SPRITE_PATH := "res://assets/art_generated/room_%s.png"
const LOCKED_DASH_LENGTH := 4.0
const LOCKED_OUTLINE_ALPHA := 0.35
const PLUS_HALF_SIZE := 5.0
const FLASH_PEAK_ALPHA := 0.8

var cell_size: Vector2i = Vector2i(64, 48)

var _sprites: Dictionary = {}  # Vector2i -> Sprite2D
var _lanterns: Dictionary = {}  # Vector2i -> PointLight2D
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _flash: Dictionary = {}  # Vector2i -> 남은 초
var _hover_alpha: float = 0.25
var _flash_seconds: float = 0.35
var _lantern_energy: float = 1.0
var _lantern_color: Color = Color.WHITE
var _lantern_texture: GradientTexture2D
var _lantern_scale: float = 1.0
var _lantern_phases: Array[String] = []
var _lanterns_enabled: bool = false


func _ready() -> void:
	var tuning := DataRegistry.tuning
	cell_size = Vector2i(tuning.get_int("room_cell_width_px"), tuning.get_int("room_cell_height_px"))
	_hover_alpha = tuning.get_float("hover_highlight_alpha")
	_flash_seconds = tuning.get_float("build_flash_seconds")
	_lantern_energy = tuning.get_float("lantern_energy")
	_lantern_color = Color.html(tuning.get_string("lantern_color"))
	for part: String in tuning.get_string("lantern_phases").split(","):
		_lantern_phases.append(part.strip_edges())
	_lantern_texture = _make_lantern_texture()
	_lantern_scale = float(tuning.get_int("lantern_radius_px") * 2) / float(_lantern_texture.width)
	_lanterns_enabled = _is_lantern_phase(Clock.phase)

	Events.room_changed.connect(_on_room_changed)
	Events.floor_added.connect(func(_floor: int) -> void: rebuild())
	Events.game_loaded.connect(func(_slot: int) -> void: rebuild())
	Events.phase_changed.connect(_on_phase_changed)
	rebuild()


func grid() -> RoomGrid:
	return GameState.room_grid


# --- 좌표 ---

func cell_rect(coords: Vector2i) -> Rect2:
	return Rect2(Vector2(coords.x * cell_size.x, -(coords.y + 1) * cell_size.y), Vector2(cell_size))


## 잠긴 층까지 포함한 집 전체 영역 (카메라 경계용).
func house_bounds() -> Rect2:
	var g := grid()
	return Rect2(0, -g.floors * cell_size.y, g.columns * cell_size.x, g.floors * cell_size.y)


func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local := to_local(world_pos)
	return Vector2i(floori(local.x / cell_size.x), floori(-local.y / cell_size.y))


func get_cell_count() -> int:
	return _sprites.size()


# --- 갱신 ---

func rebuild() -> void:
	for sprite: Sprite2D in _sprites.values():
		sprite.queue_free()
	for lantern: PointLight2D in _lanterns.values():
		lantern.queue_free()
	_sprites.clear()
	_lanterns.clear()
	for coords in grid().get_built_cells():
		_set_cell(coords, grid().get_room_id(coords))
	queue_redraw()


func set_hover(world_pos: Vector2) -> void:
	var coords := world_to_cell(world_pos)
	if not grid().is_in_bounds(coords):
		coords = Vector2i(-1, -1)
	if coords != _hover_cell:
		_hover_cell = coords
		queue_redraw()


func _process(delta: float) -> void:
	if _flash.is_empty():
		return
	for coords: Vector2i in _flash.keys():
		_flash[coords] = float(_flash[coords]) - delta
		if float(_flash[coords]) <= 0.0:
			_flash.erase(coords)
	queue_redraw()


func _draw() -> void:
	var g := grid()
	var locked_color := Color(1, 1, 1, LOCKED_OUTLINE_ALPHA)
	for floor in range(g.built_floors, g.floors):
		for column in g.columns:
			var rect := cell_rect(Vector2i(column, floor))
			_draw_dashed_rect(rect, locked_color)
		# 다음 층에만 '+' 표시 — 그 위층은 아직 지을 수 없다
		if floor == g.built_floors:
			var center := cell_rect(Vector2i(0, floor)).get_center()
			center.x = house_bounds().get_center().x
			draw_line(center + Vector2(-PLUS_HALF_SIZE, 0), center + Vector2(PLUS_HALF_SIZE, 0), locked_color)
			draw_line(center + Vector2(0, -PLUS_HALF_SIZE), center + Vector2(0, PLUS_HALF_SIZE), locked_color)
	draw_line(Vector2(0, 0), Vector2(g.columns * cell_size.x, 0), Color(1, 1, 1, LOCKED_OUTLINE_ALPHA))
	if g.is_in_bounds(_hover_cell):
		draw_rect(cell_rect(_hover_cell), Color(1, 1, 1, _hover_alpha))
	for coords: Vector2i in _flash:
		var alpha := float(_flash[coords]) / _flash_seconds * FLASH_PEAK_ALPHA
		draw_rect(cell_rect(coords), Color(1, 1, 1, alpha))


# --- 내부 ---

func _set_cell(coords: Vector2i, room_id: String) -> void:
	var sprite: Sprite2D = _sprites.get(coords)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.position = cell_rect(coords).position
		add_child(sprite)
		_sprites[coords] = sprite
	var path := ROOM_SPRITE_PATH % room_id
	if ResourceLoader.exists(path):
		sprite.texture = load(path) as Texture2D
	else:
		sprite.texture = null
		push_warning("HouseView: 방 스프라이트 없음 %s" % path)

	var room := grid().get_room(coords)
	var wants_lantern := room != null and room.kind != RoomGrid.ROOM_KIND_EMPTY
	var lantern: PointLight2D = _lanterns.get(coords)
	if wants_lantern and lantern == null:
		lantern = PointLight2D.new()
		lantern.texture = _lantern_texture
		lantern.texture_scale = _lantern_scale
		lantern.color = _lantern_color
		lantern.energy = _lantern_energy
		lantern.blend_mode = Light2D.BLEND_MODE_ADD
		lantern.position = cell_rect(coords).get_center()
		lantern.enabled = _lanterns_enabled
		add_child(lantern)
		_lanterns[coords] = lantern
	elif not wants_lantern and lantern != null:
		lantern.queue_free()
		_lanterns.erase(coords)


func _on_room_changed(coords: Vector2i, room_id: String) -> void:
	_set_cell(coords, room_id)
	_flash[coords] = _flash_seconds
	queue_redraw()


func _on_phase_changed(phase: int, _day: int) -> void:
	_lanterns_enabled = _is_lantern_phase(phase)
	for lantern: PointLight2D in _lanterns.values():
		lantern.enabled = _lanterns_enabled


func _is_lantern_phase(phase: int) -> bool:
	var phase_name: String = Clock.Phase.keys()[phase].to_lower()
	return _lantern_phases.has(phase_name)


func _make_lantern_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	return texture


func _draw_dashed_rect(rect: Rect2, color: Color) -> void:
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in corners.size():
		draw_dashed_line(corners[i], corners[(i + 1) % corners.size()], color, 1.0, LOCKED_DASH_LENGTH)
