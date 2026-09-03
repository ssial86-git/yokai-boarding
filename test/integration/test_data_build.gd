class_name TestDataBuild
extends GdUnitTestSuite
## build_resources.py 생성물이 DataRegistry 를 통해 로드되는지 확인한다 (CSV 빌드 성공의 런타임 측 검증).


func test_registry_loaded_sample_rows() -> void:
	# 하숙생은 슬라이스 3명 + 파이프라인 검증용 데이터만 있는 행(Y04~)이 늘 수 있으므로 슬라이스 수만 고정한다
	assert_int(DataRegistry.yokai.size()).is_greater_equal(3)
	assert_int(DataRegistry.slice_yokai_ids().size()).is_equal(3)
	assert_int(DataRegistry.starting_yokai_ids().size()).is_equal(2)
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
	assert_float(DataRegistry.tuning.get_float("day_length_seconds")).is_equal(720.0)
	assert_int(DataRegistry.tuning.get_int("grid_floors")).is_equal(3)
	assert_int(DataRegistry.tuning.get_int("grid_columns")).is_equal(4)


## P1 신설 스키마 10종이 로드되고 타입이 맞는지 (행 수는 콘텐츠 수를 고정하지 않도록 최소치만 본다).
func test_p1_tables_loaded_and_typed() -> void:
	assert_int(DataRegistry.talismans.size()).is_equal(3)
	assert_int(DataRegistry.tools.size()).is_equal(8)
	assert_int(DataRegistry.regions.size()).is_greater_equal(6)
	assert_int(DataRegistry.enemies.size()).is_greater_equal(3)
	assert_int(DataRegistry.unlocks.size()).is_greater_equal(20)
	assert_int(DataRegistry.metrics_events.size()).is_greater_equal(20)
	# 헤더만 있는 표는 비어 있어도 로드 자체는 되어야 한다 (S2~S3 에서 채운다)
	assert_bool(DataRegistry.materials.is_empty() or DataRegistry.get_material(DataRegistry.materials.keys()[0]) != null).is_true()

	var throw := DataRegistry.get_talisman("t_throw")
	assert_object(throw).is_not_null()
	assert_str(throw.effect).is_equal("throw")
	assert_array(throw.craft_cost).contains_exactly(["cloth:1", "scrap:1"])
	assert_object(DataRegistry.get_item("t_throw")).is_not_null()  # 부적은 인벤토리 아이템이기도 하다

	var deep := DataRegistry.get_region("r_ash_field_deep")
	assert_str(deep.parent_id).is_equal("r_ash_field")
	assert_str(deep.boss_id).is_equal("e_ash_warden")
	assert_array(deep.enemy_pool).contains(["e_ash_wisp"])
	assert_str(DataRegistry.get_enemy("e_ash_warden").tier).is_equal("boss")
	assert_str(DataRegistry.get_tool("axe_2").upgrade_from).is_equal("axe_1")


## chains.csv: 부적 3종 전부 용도 3칸 (빌드가 이미 강제하지만, 런타임에서도 같은 데이터가 보이는지)
func test_chains_cover_every_talisman() -> void:
	for talisman_id: String in DataRegistry.talismans:
		var chain := DataRegistry.get_chain(talisman_id)
		assert_object(chain).override_failure_message("사슬 없음: %s" % talisman_id).is_not_null()
		assert_str(chain.content_type).is_equal("talisman")
		for use: String in [chain.use1, chain.use2, chain.use3]:
			assert_str(use).is_not_empty()


## unlocks.csv: docs/01 v3 4절 케이던스 — 1~14일 어느 날도 해금 없이 지나가지 않는다 (30분 규칙의 거친 근사).
func test_unlock_cadence_has_no_empty_day() -> void:
	var days: Dictionary = {}
	for unlock: UnlockData in DataRegistry.unlocks_sorted():
		days[unlock.expected_day] = true
	for day in range(1, 15):
		assert_bool(days.has(day)).override_failure_message("%d일차에 예정된 해금이 없다" % day).is_true()
	var first := DataRegistry.unlocks_sorted()[0]
	assert_int(first.expected_day).is_equal(1)
	assert_object(DataRegistry.get_metrics_event("verb_ended")).is_not_null()
