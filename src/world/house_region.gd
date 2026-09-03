class_name HouseRegion
extends Node2D
## '걸어다니는 집' (docs/01 v3 2.2): 기존 HouseView(단면 렌더)·YokaiManager 를 감싸고, 플레이어가 걸을 층 바닥·계단(사다리)·
## 방 앞 상호작용(짓기·개조)·대문(마당으로) 을 방 그리드에서 조립한다. 그리드 로직은 그대로다.

const REGION_ID := "r_house"
const YARD_REGION_ID := "r_yard"
const FLOOR_THICKNESS := 4.0
const WALL_HEIGHT_EXTRA := 64.0
const DOOR_WIDTH := 20.0

var house_view: HouseView
var yokai_manager: YokaiManager
## (coords: Vector2i) -> void. 방 앞에서 E: 건설 메뉴. main.gd 가 넣는다.
var open_build_menu: Callable
## (region_id: String) -> void. RegionManager 가 넣는다.
var travel: Callable

var _stair_column: int = 0
var _floors_body: StaticBody2D
var _ladder: Area2D
var _room_nodes: Dictionary = {}  # Vector2i -> Interactable
var _door: Interactable


func _ready() -> void:
	_stair_column = DataRegistry.tuning.get_int("stair_column")
	house_view = HouseView.new()
	house_view.name = "HouseView"
	add_child(house_view)
	yokai_manager = YokaiManager.new()
	yokai_manager.name = "YokaiManager"
	yokai_manager.house_view = house_view
	add_child(yokai_manager)
	_floors_body = StaticBody2D.new()
	_floors_body.name = "Floors"
	_floors_body.collision_layer = PlayerController.WORLD_LAYER_BIT
	_floors_body.collision_mask = 0
	add_child(_floors_body)
	rebuild_geometry()
	Events.room_changed.connect(func(_coords: Vector2i, _room_id: String) -> void: rebuild_geometry())
	Events.floor_added.connect(func(_floor: int) -> void: rebuild_geometry())
	Events.game_loaded.connect(func(_slot: int) -> void: rebuild_geometry())


func grid() -> RoomGrid:
	return GameState.room_grid


func bounds() -> Rect2:
	return house_view.house_bounds()


## 대문간 칸의 바닥 가운데. 대문이 없으면 (0,0) 칸.
func gate_cell() -> Vector2i:
	for cell in grid().get_built_cells():
		var room := grid().get_room(cell)
		if room != null and room.kind == "gate":
			return cell
	return Vector2i.ZERO


func spawn_position(_from_region_id: String) -> Vector2:
	var rect := house_view.cell_rect(gate_cell())
	return Vector2(rect.get_center().x, rect.end.y)


## 층 바닥(일방향)·양끝 벽·계단·방 앞 상호작용·대문을 그리드 상태에서 다시 만든다.
func rebuild_geometry() -> void:
	for child in _floors_body.get_children():
		child.queue_free()
	for node: Interactable in _room_nodes.values():
		node.queue_free()
	_room_nodes.clear()
	if _ladder != null:
		_ladder.queue_free()
		_ladder = null
	if _door != null:
		_door.queue_free()
		_door = null

	var g := grid()
	var width := float(g.columns * house_view.cell_size.x)
	var cell_h := float(house_view.cell_size.y)
	for floor in g.built_floors:
		var y := -float(floor) * cell_h
		var shape := RectangleShape2D.new()
		shape.size = Vector2(width, FLOOR_THICKNESS)
		var collider := CollisionShape2D.new()
		collider.shape = shape
		collider.position = Vector2(width * 0.5, y + FLOOR_THICKNESS * 0.5)
		collider.one_way_collision = floor > 0  # 위층 바닥은 계단으로 아래에서 올라올 수 있게
		_floors_body.add_child(collider)
	var total_height := float(g.built_floors) * cell_h + WALL_HEIGHT_EXTRA
	for x in [0.0, width]:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(8.0, total_height)
		var collider := CollisionShape2D.new()
		collider.shape = shape
		collider.position = Vector2(x + (-4.0 if x > 0.0 else 4.0), -total_height * 0.5 + FLOOR_THICKNESS)
		_floors_body.add_child(collider)

	if g.built_floors > 1:
		_ladder = Area2D.new()
		_ladder.name = "Stairs"
		_ladder.add_to_group(PlayerController.LADDER_GROUP)
		_ladder.collision_layer = PlayerController.LADDER_LAYER_BIT
		_ladder.collision_mask = 0
		var stair_x := house_view.cell_rect(Vector2i(_stair_column, 0)).get_center().x
		var top := -float(g.built_floors - 1) * cell_h
		var shape := RectangleShape2D.new()
		shape.size = Vector2(16.0, absf(top) + 4.0)
		var collider := CollisionShape2D.new()
		collider.shape = shape
		collider.position = Vector2(stair_x, top * 0.5 - 2.0)
		_ladder.add_child(collider)
		add_child(_ladder)

	for cell in g.get_built_cells():
		_add_room_node(cell)
	# 다음 층(잠긴 층)은 계단 칸 앞에서 증축 메뉴로 연다
	if g.built_floors < g.floors:
		_add_room_node(Vector2i(_stair_column, g.built_floors), Vector2i(_stair_column, g.built_floors - 1))
	_add_door()


## anchor_cell: 플레이어가 서 있을 칸 (잠긴 층 메뉴는 그 아래층 계단 칸에서 연다)
func _add_room_node(coords: Vector2i, anchor_cell: Vector2i = Vector2i(-1, -1)) -> void:
	var stand := coords if anchor_cell == Vector2i(-1, -1) else anchor_cell
	var rect := house_view.cell_rect(stand)
	var node := Interactable.new()
	node.name = "Room_%d_%d" % [coords.x, coords.y]
	node.position = Vector2(rect.get_center().x, rect.end.y)
	node.set_box(Vector2(rect.size.x * 0.6, rect.size.y * 0.8), Vector2(0, -rect.size.y * 0.4))
	node.prompt_provider = func() -> String:
		var g := grid()
		if not g.is_floor_built(coords.y) or g.is_empty(coords):
			return DataRegistry.text("prompt_build")
		return DataRegistry.text("prompt_room", {"room": DataRegistry.room_name(g.get_room_id(coords))})
	node.action = func(_player: Node) -> void:
		if open_build_menu.is_valid():
			open_build_menu.call(coords)
	add_child(node)
	_room_nodes[coords] = node


func _add_door() -> void:
	var rect := house_view.cell_rect(gate_cell())
	_door = Interactable.new()
	_door.name = "Door_yard"
	_door.position = Vector2(rect.position.x + DOOR_WIDTH * 0.5, rect.end.y)
	_door.set_box(Vector2(DOOR_WIDTH, rect.size.y * 0.8), Vector2(0, -rect.size.y * 0.4))
	_door.interact_priority = 2
	var yard := DataRegistry.get_region(YARD_REGION_ID)
	var yard_name := yard.name_ko if yard != null else YARD_REGION_ID
	_door.prompt_provider = func() -> String: return DataRegistry.text("prompt_door", {"name": yard_name})
	_door.action = func(_player: Node) -> void:
		if travel.is_valid():
			travel.call(YARD_REGION_ID)
	add_child(_door)
