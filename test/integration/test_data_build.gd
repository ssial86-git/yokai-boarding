class_name TestDataBuild
extends GdUnitTestSuite
## build_resources.py 생성물이 DataRegistry 를 통해 로드되는지 확인한다 (CSV 빌드 성공의 런타임 측 검증).


func test_registry_loaded_sample_rows() -> void:
	assert_int(DataRegistry.yokai.size()).is_equal(3)
	assert_int(DataRegistry.guest_species.size()).is_equal(4)
	assert_int(DataRegistry.rooms.size()).is_equal(6)


func test_yokai_fields_typed() -> void:
	var ttukttagi: YokaiData = DataRegistry.get_yokai("y01_ttukttagi")
	assert_object(ttukttagi).is_not_null()
	assert_str(ttukttagi.name_ko).is_equal("뚝딱이")
	assert_str(ttukttagi.preferred_room).is_equal("workshop")
	assert_int(ttukttagi.stat_strength).is_equal(4)
	assert_int(ttukttagi.noise).is_equal(3)
	assert_bool(ttukttagi.in_slice).is_true()


func test_reference_integrity_room_exists() -> void:
	for yokai: YokaiData in DataRegistry.yokai.values():
		assert_object(DataRegistry.get_room(yokai.preferred_room)) \
			.override_failure_message("%s 의 preferred_room %s 없음" % [yokai.id, yokai.preferred_room]) \
			.is_not_null()


func test_tuning_values() -> void:
	assert_float(DataRegistry.tuning.get_float("phase_day_seconds")).is_equal(240.0)
	assert_int(DataRegistry.tuning.get_int("grid_floors")).is_equal(3)
	assert_int(DataRegistry.tuning.get_int("grid_columns")).is_equal(4)
