class_name TestDataBuild
extends GdUnitTestSuite
## build_resources.py 생성물이 DataRegistry 를 통해 로드되는지 확인한다 (CSV 빌드 성공의 런타임 측 검증).


func test_registry_loaded_sample_rows() -> void:
	# 하숙생은 슬라이스 3명 + 파이프라인 검증용 데이터만 있는 행(Y04~)이 늘 수 있으므로 슬라이스 수만 고정한다
	assert_int(DataRegistry.yokai.size()).is_greater_equal(3)
	assert_int(DataRegistry.slice_yokai_ids().size()).is_equal(4)  # P2-S4: 승격 하숙생 금줄이(intake)
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


## P2-S1 절기·날씨 스키마: 4절기 순환, 날씨 4종의 음기 범위, 소절기 이벤트 2개, 손님 갈래.
func test_p2_season_tables_loaded_and_typed() -> void:
	assert_int(DataRegistry.seasons.size()).is_equal(4)
	var spring := DataRegistry.get_season("spring")
	assert_str(spring.name_ko).is_equal("봄")
	assert_int(spring.length_days).is_equal(28)
	assert_str(spring.next_id).is_equal("summer")
	assert_str(DataRegistry.get_season("winter").next_id).is_equal("spring")
	assert_int(DataRegistry.weather.size()).is_equal(10)  # 봄 4 + 여름·가을·겨울 6 (P3-S1)
	var haze := DataRegistry.get_weather("moon_haze")
	assert_int(haze.yin_min).is_equal(3)
	assert_float(haze.demon_guest_multiplier).is_equal(2.0)
	assert_float(DataRegistry.get_weather("rain").crop_water_bonus).is_equal(1.0)
	assert_int(DataRegistry.season_events.size()).is_equal(8)  # 소절기 8 (P3-S1 로 완성)
	var monsoon := DataRegistry.get_season_event("se_rain_start")
	assert_str(monsoon.weather_override).is_equal("rain")
	assert_int(monsoon.day_of_season).is_equal(10)
	assert_int(monsoon.duration_days).is_equal(2)
	assert_str(DataRegistry.get_guest_species("g_geumjuri").realm).is_equal("demon")
	assert_str(DataRegistry.get_guest_species("g_mongdanggwi").realm).is_equal("mortal")
	assert_str(DataRegistry.tuning.get_string("season_start_id")).is_equal("spring")


## P2-S2 목표·명절 스키마: 목표 3층위, 동지(봄 28일) 준비 목표 3·팥죽·희귀 손님, 티어 3 레시피·잉어.
func test_p2_goal_and_festival_tables_loaded_and_typed() -> void:
	assert_int(DataRegistry.goals.size()).is_greater_equal(20)
	var tiers := {}
	for goal: GoalData in DataRegistry.goals.values():
		tiers[goal.tier] = true
	assert_bool(tiers.has("today") and tiers.has("season") and tiers.has("long")).is_true()
	var patjuk_goal := DataRegistry.get_goal("g_s_patjuk")
	assert_str(patjuk_goal.condition).is_equal("item:dish_patjuk>=3")
	assert_str(patjuk_goal.festival_id).is_equal("f_dongji")
	assert_int(DataRegistry.festivals.size()).is_equal(3)  # 동지 + 단오·백중 (P3-S1)
	var dongji := DataRegistry.get_festival("f_dongji")
	assert_str(dongji.season).is_equal("spring")
	assert_int(dongji.day_of_season).is_equal(28)
	assert_array(dongji.goal_ids).contains_exactly(["g_s_patjuk", "g_s_guests", "g_s_rooms"])
	assert_str(dongji.dish_recipe).is_equal("r_patjuk")
	assert_str(dongji.rare_guest_species).is_equal("g_geumjuri")
	assert_int(FestivalRules.max_score(dongji)).is_equal(11)
	assert_int(DataRegistry.get_recipe("r_patjuk").tier).is_equal(3)
	assert_int(DataRegistry.get_fish("f_carp").min_rod_level).is_equal(2)
	assert_int(DataRegistry.get_unlock("u_festival_dongji").expected_day).is_equal(28)


## P2-S3 가호·시너지·시세 스키마, 회색 시장 구역, 우물 어종(손님 낚임 포함), NPC 대화.
func test_p2_blessing_market_tables_loaded_and_typed() -> void:
	assert_int(DataRegistry.blessings.size()).is_equal(3)
	var ttuk := DataRegistry.blessing_of_yokai("y01_ttukttagi")
	assert_str(ttuk.id).is_equal("b_ttukttagi")
	assert_int(ttuk.talisman_power_bonus).is_equal(2)
	assert_int(DataRegistry.synergies.size()).is_equal(10)
	var positive := 0
	var negative := 0
	for synergy: SynergyData in DataRegistry.synergies.values():
		if synergy.delta > 0:
			positive += 1
		else:
			negative += 1
	assert_int(positive).is_equal(6)  # 시너지 6쌍
	assert_int(negative).is_equal(4)  # 간섭 4쌍
	assert_int(DataRegistry.market_prices.size()).is_greater_equal(10)
	assert_float(DataRegistry.get_market_price("seed_cabbage").buy_mult).is_equal(2.0)
	assert_int(DataRegistry.get_market_price("seed_cabbage").stock).is_equal(3)
	var market := DataRegistry.get_region("r_gray_market")
	assert_str(market.kind).is_equal("market")
	assert_int(market.merchant_x).is_greater(0)
	assert_int(DataRegistry.get_region("r_well").fishing_x).is_greater(0)
	assert_str(DataRegistry.get_fish("f_wet_visitor").visitor_species).is_equal("g_usanson")
	assert_str(DataRegistry.get_fish("f_carp").visitor_species).is_equal("")
	assert_str(DataRegistry.get_event("ev_merchant_greet").kind).is_equal("npc")
	assert_str(DataRegistry.item_name("seed_radish@b_ttukttagi")).is_equal("[뚝] 무 씨앗")
	assert_str(DataRegistry.get_item("seed_radish@b_ttukttagi").kind).is_equal("seed")


## P3-S1 4절기 콘텍츠: 절기별 날씨·소절기 8·명절 3, 절기 작물 3·재료 4·어종 2, 도구 Lv3.
func test_p3_season_content_tables() -> void:
	for season_id in ["summer", "autumn", "winter"]:
		assert_int(WeatherRoll.eligible(DataRegistry.weather, season_id).size()).is_greater_equal(4)
		var events := Calendar.start(DataRegistry.seasons, season_id).events_in_season(DataRegistry.season_events)
		assert_int(events.size()).is_equal(2)
	assert_str(DataRegistry.get_festival("f_dano").season).is_equal("summer")
	assert_int(DataRegistry.get_festival("f_dano").day_of_season).is_equal(5)
	assert_str(DataRegistry.get_festival("f_baekjung").season).is_equal("autumn")
	assert_str(DataRegistry.get_crop("c_cucumber").season).is_equal("summer")
	assert_str(DataRegistry.get_crop("c_buckwheat").season).is_equal("autumn")
	assert_str(DataRegistry.get_material("m_chestnut").season).is_equal("autumn")
	assert_str(DataRegistry.get_fish("f_eel").season).is_equal("summer")
	assert_str(DataRegistry.get_fish("f_minnow").season).is_equal("any")
	assert_int(DataRegistry.get_tool("axe_3").level).is_equal(3)
	assert_int(DataRegistry.get_unlock("u_year_end").expected_day).is_equal(112)


## P2-S4 챕터·승격·밤 변형 데이터: 챕터 1 게이트 4 중 2, 금줄이 승격 행, 뒷산 밤 변형 파생 리소스, 챕터 대화 8 + 금줄이 1막.
func test_p2_chapter_promotion_night_tables() -> void:
	assert_int(DataRegistry.chapters.size()).is_equal(2)
	var c1 := DataRegistry.get_chapter("c1")
	assert_str(c1.name_ko).is_equal("폭군의 장부")
	assert_int(c1.gate_goals.size()).is_equal(4)
	assert_int(c1.gate_required).is_equal(2)
	assert_str(c1.next_id).is_equal("c2")
	assert_str(ChapterRules.first(DataRegistry.chapters).id).is_equal("c1")
	assert_str(DataRegistry.get_guest_species("g_geumjuri").promotes_to).is_equal("y05_geumjuri")
	assert_str(DataRegistry.get_yokai("y05_geumjuri").join_mode).is_equal("intake")
	assert_str(DataRegistry.get_visitor("v_promotion").kind).is_equal("promotion")
	var chapter_events := 0
	for event: EventData in DataRegistry.events.values():
		if event.kind == "chapter":
			chapter_events += 1
	assert_int(chapter_events).is_equal(8)
	assert_array(DataRegistry.story_event_ids("y05_geumjuri")).contains_exactly(["y05_act1"])
	# 밤 변형: 기본 뒷산은 wild, 밤 뒷산은 expedition(도깨비불 2) + 달빛 이슬 풀
	var hill := DataRegistry.get_region("r_back_hill")
	assert_bool(DataRegistry.has_night_variant(hill)).is_true()
	var night := DataRegistry.get_region("r_back_hill@night")
	assert_that(night).is_not_null()
	assert_str(night.kind).is_equal("expedition")
	assert_int(night.enemy_count).is_equal(2)
	assert_bool(night.gather_pool.has("m_moon_dew")).is_true()
	assert_str(night.name_ko).is_equal("뒷산 (밤)")
	assert_str(night.sky_color).is_equal("2b3f55")
	assert_int(night.doors.size()).is_equal(hill.doors.size())
	assert_that(DataRegistry.get_region("r_yard@night")).is_null()  # 변형 없는 구역
	assert_str(DataRegistry.base_region_id("r_back_hill@night")).is_equal("r_back_hill")


## P1 신설 스키마 10종이 로드되고 타입이 맞는지 (행 수는 콘텐츠 수를 고정하지 않도록 최소치만 본다).
func test_p1_tables_loaded_and_typed() -> void:
	assert_int(DataRegistry.talismans.size()).is_equal(3)
	assert_int(DataRegistry.tools.size()).is_equal(12)  # 4갈래 × Lv1~3 (P3-S1 에서 Lv3 추가)
	assert_int(DataRegistry.regions.size()).is_greater_equal(6)
	assert_int(DataRegistry.enemies.size()).is_greater_equal(3)
	assert_int(DataRegistry.unlocks.size()).is_greater_equal(20)
	assert_int(DataRegistry.metrics_events.size()).is_greater_equal(20)
	# 헤더만 있는 표는 비어 있어도 로드 자체는 되어야 한다 (S2~S3 에서 채운다)
	assert_bool(DataRegistry.materials.is_empty() or DataRegistry.get_material(DataRegistry.materials.keys()[0]) != null).is_true()

	var throw := DataRegistry.get_talisman("t_throw")
	assert_object(throw).is_not_null()
	assert_str(throw.effect).is_equal("throw")
	assert_array(throw.craft_cost).contains_exactly(["cloth:1", "m_ember_stone:1"])  # 전리품 → 제작 사슬 (S4)
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
