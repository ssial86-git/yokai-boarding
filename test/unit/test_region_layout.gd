class_name TestRegionLayout
extends GdUnitTestSuite
## 지역 레이아웃: 바닥 구간·경사로 윤곽, 높이 보간, 문·채집·텃밭 자리.


func _region() -> RegionData:
	var region := RegionData.new()
	region.id = "r_test"
	region.width_px = 300
	region.ground = ["0:100:0", "100:200:-32", "200:300:-32"]
	region.doors = ["r_a:10", "r_b:290"]
	region.gather_span = "100:200"
	region.farm_x = 40
	return region


func test_profile_inserts_ramps_only_where_height_changes() -> void:
	var layout := RegionLayout.from_region(_region())
	var profile := layout.profile(20.0)
	# 구간 3개 → 점 6개. 0/100 사이만 높이가 달라 그곳에만 경사로(±10)
	assert_int(profile.size()).is_equal(6)
	assert_that(profile[0]).is_equal(Vector2(0, 0))
	assert_that(profile[1]).is_equal(Vector2(90, 0))
	assert_that(profile[2]).is_equal(Vector2(110, -32))
	assert_that(profile[3]).is_equal(Vector2(200, -32))
	assert_that(profile[5]).is_equal(Vector2(300, -32))


func test_ground_height_interpolates_on_ramp() -> void:
	var layout := RegionLayout.from_region(_region())
	assert_float(layout.ground_y_at(50.0, 20.0)).is_equal(0.0)
	assert_float(layout.ground_y_at(100.0, 20.0)).is_equal(-16.0)
	assert_float(layout.ground_y_at(250.0, 20.0)).is_equal(-32.0)
	assert_float(layout.ground_y_at(-5.0, 20.0)).is_equal(0.0)
	assert_float(layout.ground_y_at(999.0, 20.0)).is_equal(-32.0)


func test_doors_gather_and_farm_positions() -> void:
	var layout := RegionLayout.from_region(_region())
	assert_float(layout.door_x("r_b")).is_equal(290.0)
	assert_float(layout.door_x("r_none")).is_equal(-1.0)
	assert_float(layout.spawn_x_from("r_a")).is_equal(10.0)
	assert_float(layout.spawn_x_from("r_none")).is_equal(150.0)
	assert_array(layout.gather_positions(2)).contains_exactly([125.0, 175.0])
	assert_array(layout.gather_positions(0)).is_empty()
	assert_array(layout.farm_positions(3, 16.0)).contains_exactly([40.0, 56.0, 72.0])


func test_malformed_entries_are_skipped() -> void:
	assert_int(RegionLayout.parse_segments(["bad", "0:10:0"]).size()).is_equal(1)
	assert_int(RegionLayout.parse_doors(["r_a"]).size()).is_equal(0)
	assert_that(RegionLayout.parse_pair("")).is_equal(Vector2.ZERO)
