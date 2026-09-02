class_name TestCameraBounds
extends GdUnitTestSuite

const VIEW := Vector2(640, 360)


func test_small_bounds_center_on_both_axes() -> void:
	var bounds := Rect2(0, -144, 256, 144)
	var result := CameraBounds.clamp_center(Vector2(999, 999), bounds, VIEW, 1.0)
	assert_vector(result).is_equal(Vector2(128, -72))


func test_large_bounds_clamped_to_edges() -> void:
	var bounds := Rect2(0, 0, 2000, 1000)
	assert_vector(CameraBounds.clamp_center(Vector2(-500, -500), bounds, VIEW, 1.0)).is_equal(Vector2(320, 180))
	assert_vector(CameraBounds.clamp_center(Vector2(5000, 5000), bounds, VIEW, 1.0)).is_equal(Vector2(1680, 820))
	assert_vector(CameraBounds.clamp_center(Vector2(1000, 500), bounds, VIEW, 1.0)).is_equal(Vector2(1000, 500))


func test_zoom_shrinks_visible_area() -> void:
	var bounds := Rect2(0, 0, 400, 300)
	# zoom 1: 화면(640x360)이 경계보다 크므로 중앙 고정
	assert_vector(CameraBounds.clamp_center(Vector2.ZERO, bounds, VIEW, 1.0)).is_equal(Vector2(200, 150))
	# zoom 2: 보이는 영역 320x180 -> 가장자리까지 이동 가능
	assert_vector(CameraBounds.clamp_center(Vector2.ZERO, bounds, VIEW, 2.0)).is_equal(Vector2(160, 90))
	assert_vector(CameraBounds.clamp_center(Vector2(999, 999), bounds, VIEW, 2.0)).is_equal(Vector2(240, 210))
