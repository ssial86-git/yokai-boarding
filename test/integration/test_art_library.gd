class_name TestArtLibrary
extends GdUnitTestSuite
## 아트 매니페스트(art_assets.csv) → ArtLibrary: 키가 자리표시 파일로 풀리고, 시트 규격·애니메이션 구간이 SpriteFrames 가 되며,
## 행이 없거나 파일이 없는 키는 폴백/null 로 게임이 멈추지 않는다. 렌더러는 이 경로만 쓴다.


func before_test() -> void:
	ArtLibrary.clear_cache()


func test_manifest_rows_resolve_to_placeholders() -> void:
	assert_int(DataRegistry.art_assets.size()).is_greater_equal(100)
	var row := DataRegistry.get_art_asset("char.y01_ttukttagi")
	assert_that(row).is_not_null()
	assert_str(row.track).is_equal("pixel")
	assert_bool(ArtLibrary.has("char.y01_ttukttagi")).is_true()
	assert_that(ArtLibrary.frame_size("char.y01_ttukttagi")).is_equal(Vector2i(32, 32))
	assert_that(ArtLibrary.icon("char.y01_ttukttagi")).is_not_null()
	assert_that(ArtLibrary.texture("illust.y01_ttukttagi")).is_not_null()
	assert_that(ArtLibrary.texture("room.kitchen")).is_not_null()
	assert_that(ArtLibrary.texture("char.player")).is_not_null()
	# CC0 팩 충전(import_free_packs.py) 뒤에는 적·소품·배경·UI 키도 실재 파일로 풀린다
	assert_bool(ArtLibrary.has("enemy.e_ash_wisp")).is_true()
	assert_bool(ArtLibrary.has("prop.door")).is_true()
	assert_bool(ArtLibrary.has("region.r_yard.sky")).is_true()
	assert_that(ArtLibrary.frame_size("enemy.e_ash_wisp")).is_equal(Vector2i(16, 16))
	assert_bool(ArtLibrary.has_anim("char.y01_ttukttagi", "walk")).is_true()
	assert_int(ArtLibrary.frames("char.y01_ttukttagi").get_frame_count("idle")).is_equal(4)
	# 매니페스트에 없는 키는 has() 가 false, texture/make_sprite 가 null — 렌더러가 코드 자리표시를 그린다
	assert_bool(ArtLibrary.has("enemy.e_not_in_manifest")).is_false()
	assert_that(ArtLibrary.texture("enemy.e_not_in_manifest")).is_null()
	assert_that(ArtLibrary.make_sprite("enemy.e_not_in_manifest")).is_null()


func test_frames_default_idle_and_sprite_feet_at_origin() -> void:
	# anims 가 빈 행(prop.merchant, 32x32 한 장): idle 1프레임 기본, walk 없음, 발이 원점
	var frames := ArtLibrary.frames("prop.merchant")
	assert_that(frames).is_not_null()
	assert_bool(frames.has_animation("idle")).is_true()
	assert_int(frames.get_frame_count("idle")).is_equal(1)
	assert_bool(ArtLibrary.has_anim("prop.merchant", "walk")).is_false()
	var sprite: AnimatedSprite2D = auto_free(ArtLibrary.make_sprite("prop.merchant"))
	assert_that(sprite).is_not_null()
	assert_float(sprite.offset.y).is_equal(-16.0)
	ArtLibrary.play(sprite, "walk")  # walk 가 없으면 idle 유지
	assert_str(sprite.animation).is_equal("idle")


func test_sheet_spec_builds_animations_from_generated_texture() -> void:
	# 매니페스트 행을 런타임에 흉내 내 시트 규격·구간 파싱을 검증한다 (32x32 프레임 6칸 가로 시트)
	var image := Image.create(192, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(image)
	var row := ArtAssetData.new()
	row.id = "char.test_sheet"
	row.file = "res://assets/art_generated/yokai_y01_ttukttagi.png"  # 실재 파일이어야 has() 가 참
	row.frame_w = 32
	row.frame_h = 32
	row.anims = "idle:0-3:6;walk:4-5:10"
	DataRegistry.art_assets["char.test_sheet"] = row
	ArtLibrary.clear_cache()
	ArtLibrary._textures["char.test_sheet"] = tex  # 파일 대신 생성 텍스처
	var frames := ArtLibrary.frames("char.test_sheet")
	assert_bool(frames.has_animation("idle")).is_true()
	assert_int(frames.get_frame_count("idle")).is_equal(4)
	assert_int(frames.get_frame_count("walk")).is_equal(2)
	assert_float(frames.get_animation_speed("walk")).is_equal(10.0)
	assert_bool(ArtLibrary.has_anim("char.test_sheet", "walk")).is_true()
	var atlas := frames.get_frame_texture("walk", 1) as AtlasTexture
	assert_that(atlas).is_not_null()
	assert_that(atlas.region.position).is_equal(Vector2(160.0, 0.0))
	DataRegistry.art_assets.erase("char.test_sheet")
	ArtLibrary.clear_cache()
