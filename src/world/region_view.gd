class_name RegionView
extends Node2D
## 야외 구역(마당·뒷산·개울·우물·마계) 씬을 regions.csv 레이아웃으로 조립한다 (CLAUDE.md 5.7 — 수제 씬 없음).
## 바닥(경사로 포함)·양끝 벽·문·채집 포인트·텃밭 칸. 그림은 코드 자리표시.

const WALL_HEIGHT := 240.0
const SKY_HEIGHT := 200.0
const DOOR_SIZE := Vector2(16.0, 32.0)
## 배경·바닥 그림을 벽 밖으로 늘리는 폭 (뷰포트 너비)
const EDGE_FILL_PX := 640.0
## 바닥 아래 카메라 여유 — 바닥선이 화면 아래에서 이만큼 위로 올라온다
const GROUND_BELOW_PX := 120.0

var region: RegionData
var layout: RegionLayout

var _ramp_px: float = 32.0
var _ground_thickness: float = 32.0
var _sky_color: Color = Color.SKY_BLUE
var _ground_color: Color = Color.DARK_GREEN
var _dirt_color: Color = Color.SADDLE_BROWN
var _door_color: Color = Color.TAN
var _door_locked_color: Color = Color.DIM_GRAY
var _doors: Array[Interactable] = []
## (region_id: String) -> bool. RegionManager 가 넣는다 (해금 여부).
var is_region_open: Callable
## 낚시 자리를 만들 때 필요. RegionManager 가 setup 전에 넣는다 (null 이면 낚시 자리 없음).
var fishing_system: FishingSystem
## (npc_id: String, shop_id: String) -> void. 상점 NPC 앞에서 E. RegionManager 가 넣는다.
var merchant_action: Callable

const REGION_KIND_MARKET := "market"
const REGION_KIND_VILLAGE := "village"
## 아트 매니페스트 소품 키
const PROP_DOOR := "prop.door"
const PROP_WATER := "prop.water"


## 낚시 자리 자리표시 (물 웅덩이).
class SpotMarker:
	extends Node2D
	var color: Color = Color.STEEL_BLUE

	func _draw() -> void:
		draw_rect(Rect2(Vector2(-20.0, -3.0), Vector2(40.0, 6.0)), color)
		draw_rect(Rect2(Vector2(-20.0, -3.0), Vector2(40.0, 6.0)), Color(0.1, 0.08, 0.12), false, 1.0)


## travel: (target_region_id: String) -> void
func setup(region_data: RegionData, travel: Callable, farm_system: FarmSystem, gather_system: GatherSystem) -> void:
	region = region_data
	layout = RegionLayout.from_region(region_data)
	var tuning := DataRegistry.tuning
	_ramp_px = tuning.get_float("ramp_width_px", _ramp_px)
	_ground_thickness = float(tuning.get_int("ground_thickness_px"))
	_sky_color = Color.html(region.sky_color)
	var demon := region.realm == "demon"
	_ground_color = Color.html(tuning.get_string("region_demon_ground_color" if demon else "region_ground_color"))
	_dirt_color = Color.html(tuning.get_string("region_demon_dirt_color" if demon else "region_dirt_color"))
	_door_color = Color.html(tuning.get_string("door_color"))
	_door_locked_color = Color.html(tuning.get_string("door_locked_color"))

	_build_ground()
	_build_walls()
	for door in layout.doors:
		_build_door(door, travel)
	if region.kind == "yard":
		_build_farm(farm_system)
	_build_gather_points(gather_system)
	if fishing_system != null and fishing_system.has_spot(region):
		_build_fishing_spot()
	for entry: Variant in region.npcs:
		_build_npc(str(entry))
	Events.farm_changed.connect(func(index: int) -> void:
		if index < 0 and region.kind == "yard":
			_build_farm(farm_system))


## 상점 NPC (P2-S3 회색 장꾼, P3-S2 마을 잡화상·약방 할미): "spirit_id:shop_id:x". E 로 첫 인사 대화 → 이후 거래 메뉴. 그림은 자리표시 사각.
func _build_npc(entry: String) -> void:
	var parts := entry.split(":")
	if parts.size() != 3:
		return
	var npc_id := parts[0]
	var shop_id := parts[1]
	var node := Interactable.new()
	node.name = "Npc_%s" % npc_id
	var x := float(parts[2])
	node.position = Vector2(x, ground_y_at(x))
	node.set_box(Vector2(40.0, 32.0), Vector2(0, -16.0))
	node.interact_priority = 1
	node.prompt_provider = func() -> String: return DataRegistry.text("prompt_npc", {"name": DataRegistry.speaker_name(npc_id)})
	node.action = func(_player: Node) -> void:
		if merchant_action.is_valid():
			merchant_action.call(npc_id, shop_id)
	add_child(node)
	# 아트 매니페스트 npc.<id> 가 있으면 시트(발이 바닥), 없으면 자리표시 사각
	var art_key := "npc.%s" % npc_id
	if ArtLibrary.has(art_key):
		node.add_child(ArtLibrary.make_sprite(art_key))
	else:
		var marker := SpotMarker.new()
		marker.color = Color.html(DataRegistry.tuning.get_string("merchant_color", "d4a5c4"))
		marker.position = Vector2(0, -12.0)
		node.add_child(marker)


## 낚시 자리 (P1-S3): E 로 찌 던지기, 던진 뒤 E 는 판정. 그림은 물 자리표시.
func _build_fishing_spot() -> void:
	var node := Interactable.new()
	node.name = "FishingSpot"
	var x := float(region.fishing_x)
	node.position = Vector2(x, ground_y_at(x))
	node.set_box(Vector2(40.0, 32.0), Vector2(0, -16.0))
	node.interact_priority = 1
	node.prompt_provider = func() -> String: return fishing_system.prompt_for(region.id)
	node.enabled_check = func() -> bool: return fishing_system.is_active() or fishing_system.can_start(region.id)
	node.action = func(_player: Node) -> void:
		if fishing_system.is_active():
			fishing_system.strike()
		else:
			fishing_system.start(region.id)
	add_child(node)
	# 아트 매니페스트 prop.water 가 있으면 시트, 없으면 물 자리표시 사각
	if ArtLibrary.has(PROP_WATER):
		node.add_child(ArtLibrary.make_sprite(PROP_WATER))
	else:
		var marker := SpotMarker.new()
		marker.color = Color.html(DataRegistry.tuning.get_string("region_water_color", "5f8090"))
		node.add_child(marker)


## 카메라 경계. 바닥 아래에 여유(GROUND_BELOW_PX)를 두어 바닥이 화면 맨 아래에 붙지 않게 한다 — 왼쪽 아래 로그가 배우를 가리지 않도록.
func bounds() -> Rect2:
	var top := 0.0
	for segment in layout.segments:
		top = minf(top, segment.y)
	return Rect2(0.0, top - SKY_HEIGHT, layout.width_px, SKY_HEIGHT + maxf(_ground_thickness, GROUND_BELOW_PX) - top)


func ground_y_at(x: float) -> float:
	return layout.ground_y_at(x, _ramp_px)


## from_region 에서 들어왔을 때 서는 발 위치.
func spawn_position(from_region_id: String) -> Vector2:
	var x := layout.spawn_x_from(from_region_id)
	return Vector2(x, ground_y_at(x))


func _draw() -> void:
	# 구역이 화면보다 좁아도 양옆이 비지 않도록 배경·바닥 그림은 벽 밖으로 넉넉히 늘린다 (충돌 벽은 그대로)
	var area := bounds().grow_individual(EDGE_FILL_PX, 0.0, EDGE_FILL_PX, 0.0)
	draw_rect(area, _sky_color)
	# 아트 매니페스트 배경 레이어 (region.<base>.sky/far/ground). 없으면 색·선 자리표시 그대로
	var art_base := DataRegistry.base_region_id(region.id)
	var sky_key := "region.%s.sky" % art_base
	if ArtLibrary.has(sky_key):
		draw_texture_rect(ArtLibrary.texture(sky_key), area, false)
	var profile := layout.profile(_ramp_px)
	if profile.size() < 2:
		return
	var far_key := "region.%s.far" % art_base
	if ArtLibrary.has(far_key):
		var far_tex := ArtLibrary.texture(far_key)
		var far_top := profile[0].y - float(far_tex.get_height())
		var x := area.position.x
		while x < area.end.x:
			draw_texture(far_tex, Vector2(x, far_top))
			x += float(far_tex.get_width())
	var bottom := area.end.y
	var extended := PackedVector2Array([Vector2(profile[0].x - EDGE_FILL_PX, profile[0].y)])
	extended.append_array(profile)
	extended.append(Vector2(profile[profile.size() - 1].x + EDGE_FILL_PX, profile[profile.size() - 1].y))
	var polygon := PackedVector2Array(extended)
	polygon.append(Vector2(extended[extended.size() - 1].x, bottom))
	polygon.append(Vector2(extended[0].x, bottom))
	draw_colored_polygon(polygon, _dirt_color)
	draw_polyline(extended, _ground_color, 4.0)
	# 바닥 띠 타일: 평평한 구간 위에 가로로 반복 (경사로는 자리표시 선 그대로)
	var ground_key := "region.%s.ground" % art_base
	if ArtLibrary.has(ground_key):
		var tile := ArtLibrary.texture(ground_key)
		var tile_w := float(tile.get_width())
		for i in range(1, extended.size()):
			var a := extended[i - 1]
			var b := extended[i]
			if not is_equal_approx(a.y, b.y):
				continue
			var x := a.x
			while x + tile_w <= b.x + 0.5:
				draw_texture(tile, Vector2(x, a.y - float(tile.get_height()) * 0.5))
				x += tile_w


func _build_ground() -> void:
	var body := StaticBody2D.new()
	body.name = "Ground"
	body.collision_layer = PlayerController.WORLD_LAYER_BIT
	body.collision_mask = 0
	add_child(body)
	var profile := layout.profile(_ramp_px)
	var bottom := bounds().end.y
	for i in range(1, profile.size()):
		var a := profile[i - 1]
		var b := profile[i]
		var collider := CollisionPolygon2D.new()
		collider.polygon = PackedVector2Array([a, b, Vector2(b.x, bottom), Vector2(a.x, bottom)])
		body.add_child(collider)


func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	body.collision_layer = PlayerController.WORLD_LAYER_BIT
	body.collision_mask = 0
	add_child(body)
	var top := bounds().position.y
	for x in [0.0, layout.width_px]:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(8.0, WALL_HEIGHT + absf(top))
		var collider := CollisionShape2D.new()
		collider.shape = shape
		collider.position = Vector2(x + (-4.0 if x > 0.0 else 4.0), top * 0.5)
		body.add_child(collider)


func _build_door(door: RegionLayout.Door, travel: Callable) -> void:
	var target := DataRegistry.get_region(door.region_id)
	var node := Interactable.new()
	node.name = "Door_%s" % door.region_id
	node.position = Vector2(door.x, ground_y_at(door.x))
	node.set_box(DOOR_SIZE + Vector2(8.0, 0.0), Vector2(0, -DOOR_SIZE.y * 0.5))
	node.interact_priority = 2
	var target_name := target.name_ko if target != null else door.region_id
	var locked_key := "prompt_door_locked"
	if target != null and target.kind == REGION_KIND_MARKET:
		locked_key = "prompt_market_closed"  # 회색 시장: 음기·밤 조건 (P2-S3)
	elif target != null and target.kind == REGION_KIND_VILLAGE:
		locked_key = "prompt_village_closed"  # 마을 상점가: 밤에 닫힘 (P3-S2)
	node.prompt_provider = func() -> String:
		var open := not is_region_open.is_valid() or bool(is_region_open.call(door.region_id))
		return DataRegistry.text("prompt_door" if open else locked_key, {"name": target_name})
	node.enabled_check = func() -> bool:
		return not is_region_open.is_valid() or bool(is_region_open.call(door.region_id))
	node.action = func(_player: Node) -> void: travel.call(door.region_id)
	add_child(node)
	_doors.append(node)
	if ArtLibrary.has(PROP_DOOR):
		# 시트 프레임 0 = 열림, 1 = 잠김. 해금될 때 다시 고른다
		var sprite := ArtLibrary.make_sprite(PROP_DOOR)
		sprite.stop()
		var pick_frame := func() -> void:
			var open := not node.enabled_check.is_valid() or bool(node.enabled_check.call())
			var count := sprite.sprite_frames.get_frame_count(sprite.animation)
			sprite.frame = 0 if open or count < 2 else 1
		pick_frame.call()
		# Events 는 autoload 라 구역이 사라진 뒤에도 연결이 남는다 — 스프라이트가 트리를 떠날 때 끊는다
		var on_unlocked := func(_id: String) -> void:
			if is_instance_valid(sprite) and is_instance_valid(node):
				pick_frame.call()
		Events.unlocked.connect(on_unlocked)
		sprite.tree_exiting.connect(func() -> void:
			if Events.unlocked.is_connected(on_unlocked):
				Events.unlocked.disconnect(on_unlocked))
		node.add_child(sprite)
	else:
		var marker := DoorMarker.new()
		marker.color_open = _door_color
		marker.color_locked = _door_locked_color
		marker.is_open = node.enabled_check
		node.add_child(marker)


func _build_farm(farm_system: FarmSystem) -> void:
	for child in get_children():
		if child is FarmPlotNode:
			child.queue_free()
	var width := float(DataRegistry.tuning.get_int("farm_plot_width_px"))
	var positions := layout.farm_positions(GameState.farm.size(), width)
	for index in positions.size():
		var plot := FarmPlotNode.new()
		plot.name = "Plot_%d" % index
		plot.position = Vector2(positions[index], ground_y_at(positions[index]))
		plot.setup(index, farm_system)
		add_child(plot)


func _build_gather_points(gather_system: GatherSystem) -> void:
	var points := gather_system.points_for(region.id)
	var positions := layout.gather_positions(points.size())
	for index in positions.size():
		var node := GatherPointNode.new()
		node.name = "Gather_%d" % index
		node.position = Vector2(positions[index], ground_y_at(positions[index]))
		node.setup(region.id, index, gather_system)
		add_child(node)


## 문 자리표시 (열림/잠김 색).
class DoorMarker:
	extends Node2D
	var color_open: Color = Color.TAN
	var color_locked: Color = Color.DIM_GRAY
	var is_open: Callable

	func _ready() -> void:
		Events.unlocked.connect(func(_id: String) -> void: queue_redraw())

	func _draw() -> void:
		var open := not is_open.is_valid() or bool(is_open.call())
		draw_rect(Rect2(Vector2(-DOOR_SIZE.x * 0.5, -DOOR_SIZE.y), DOOR_SIZE), color_open if open else color_locked)
		draw_rect(Rect2(Vector2(-DOOR_SIZE.x * 0.5, -DOOR_SIZE.y), DOOR_SIZE), Color(0.1, 0.08, 0.12), false, 1.0)
