class_name HouseBackdrop
extends Node2D
## 하숙집 씬의 배경(하늘·원경·바닥, region.r_house.*)과 집 뼈대(지붕·기둥·주춧돌, prop.house_*)를 아트 매니페스트 키로 그린다.
## 키가 없으면 아무것도 그리지 않아 이전 화면(민 배경)과 같다. 월드 좌표는 HouseView 와 같다: 1층 바닥 y=0.

const REGION_ID := "r_house"
const KEY_ROOF := "prop.house_roof"
const KEY_PILLAR := "prop.house_pillar"
const KEY_BASE := "prop.house_base"
## 카메라가 집 경계 밖(camera_bounds_margin_px + 뷰포트 절반)까지 보므로 뷰포트 너비만큼 양옆을 채운다
const EDGE_FILL_PX := 640.0
const SKY_HEIGHT := 400.0
const GROUND_BELOW_PX := 240.0
const DIRT_DARKEN := 0.6
## 방 스프라이트(z -1) 뒤
const BACKDROP_Z := -2

var columns: int = 4
var cell_size: Vector2i = Vector2i(64, 48)


func _ready() -> void:
	z_index = BACKDROP_Z
	Events.game_loaded.connect(func(_slot: int) -> void: queue_redraw())


func _draw() -> void:
	var width := float(columns * cell_size.x)
	var area := Rect2(-EDGE_FILL_PX, -SKY_HEIGHT, width + EDGE_FILL_PX * 2.0, SKY_HEIGHT)
	var sky_key := "region.%s.sky" % REGION_ID
	if ArtLibrary.has(sky_key):
		draw_texture_rect(ArtLibrary.texture(sky_key), area, false)
	var far_key := "region.%s.far" % REGION_ID
	if ArtLibrary.has(far_key):
		var far_tex := ArtLibrary.texture(far_key)
		var x := area.position.x
		while x < area.end.x:
			draw_texture(far_tex, Vector2(x, -float(far_tex.get_height())))
			x += float(far_tex.get_width())
	var ground_key := "region.%s.ground" % REGION_ID
	if ArtLibrary.has(ground_key):
		var tile := ArtLibrary.texture(ground_key)
		var ground_color := Color.html(DataRegistry.tuning.get_string("region_ground_color"))
		draw_rect(Rect2(area.position.x, 0.0, area.size.x, GROUND_BELOW_PX), ground_color.darkened(DIRT_DARKEN))
		var x := area.position.x
		while x < area.end.x:
			draw_texture(tile, Vector2(x, -float(tile.get_height()) * 0.5))
			x += float(tile.get_width())


## 집 뼈대. HouseView._draw 가 호출해 방 스프라이트 위에 그린다 — 기둥이 방 경계를, 지붕이 지어진 맨 위층을 덮는다.
static func draw_frame(canvas: CanvasItem, column_count: int, built_floors: int, cell: Vector2i) -> void:
	if ArtLibrary.has(KEY_BASE):
		var base := ArtLibrary.texture(KEY_BASE)
		for c in column_count:
			canvas.draw_texture(base, Vector2(c * cell.x, 0.0))
	if ArtLibrary.has(KEY_PILLAR):
		var pillar := ArtLibrary.texture(KEY_PILLAR)
		for f in built_floors:
			for c in column_count + 1:
				canvas.draw_texture(pillar, Vector2(c * cell.x - pillar.get_width() * 0.5, -float(f + 1) * cell.y))
	if ArtLibrary.has(KEY_ROOF):
		var roof := ArtLibrary.texture(KEY_ROOF)
		for c in column_count:
			canvas.draw_texture(roof, Vector2(c * cell.x, -float(built_floors) * cell.y - roof.get_height()))
