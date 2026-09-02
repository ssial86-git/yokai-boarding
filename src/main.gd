extends Node2D
## 메인 씬 루트. 씬 트리는 여기서 코드로 조립한다 (CLAUDE.md 5.2 — .tscn 은 이 루트 하나뿐).
##
## Main
##  ├ HouseController        규칙 적용 + 돈 + Events
##  ├ World (Node2D)
##  │   ├ HouseView          단면 렌더링 (RoomGrid 구독)
##  │   ├ Lighting           CanvasModulate 페이즈 색조
##  │   └ Camera             줌·드래그·클릭 판정
##  └ UI (CanvasLayer)
##      ├ DebugHud
##      └ BuildMenu

var house_controller: HouseController
var house_view: HouseView
var camera: HouseCamera
var build_menu: BuildMenu


func _ready() -> void:
	GameState.reset_new_game()

	house_controller = HouseController.new()
	house_controller.name = "HouseController"
	add_child(house_controller)

	var world := Node2D.new()
	world.name = "World"
	add_child(world)

	house_view = HouseView.new()
	house_view.name = "HouseView"
	world.add_child(house_view)

	var lighting := DayNightLighting.new()
	lighting.name = "Lighting"
	world.add_child(lighting)

	camera = HouseCamera.new()
	camera.name = "Camera"
	var margin := float(DataRegistry.tuning.get_int("camera_bounds_margin_px"))
	camera.bounds = house_view.house_bounds().grow(margin)
	camera.position = house_view.house_bounds().get_center()
	world.add_child(camera)
	camera.clamp_to_bounds()

	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	var hud := DebugHud.new()
	hud.name = "DebugHud"
	ui.add_child(hud)

	build_menu = BuildMenu.new()
	build_menu.name = "BuildMenu"
	build_menu.controller = house_controller
	ui.add_child(build_menu)

	camera.clicked.connect(_on_world_clicked)
	camera.hovered.connect(house_view.set_hover)

	Clock.start_day()
	Events.game_started.emit()


func _on_world_clicked(world_pos: Vector2) -> void:
	var coords := house_view.world_to_cell(world_pos)
	if house_view.grid().is_in_bounds(coords):
		build_menu.open_for_cell(coords, get_viewport().get_mouse_position())
