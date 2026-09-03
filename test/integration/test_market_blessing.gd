class_name TestMarketBlessing
extends GdUnitTestSuite
## P2-S3 통합: 회색 시장 개장 규칙·사기(재고·돈)·팔기(시세), 가호 부여 → 씨앗(수확 +)·요리(배식 버프 +시너지)·부적(위력 +시너지),
## 하루 한도, 예약 손님 플래그(우물 낚시·명절)가 심사 카드로.

var _blessing_system: BlessingSystem
var _market_system: MarketSystem
var _farm_system: FarmSystem
var _station_system: StationSystem
var _intake_system: IntakeSystem


func before_test() -> void:
	GameState.reset_new_game()
	_blessing_system = auto_free(BlessingSystem.new())
	add_child(_blessing_system)
	_market_system = auto_free(MarketSystem.new())
	add_child(_market_system)
	_farm_system = auto_free(FarmSystem.new())
	add_child(_farm_system)
	_station_system = auto_free(StationSystem.new())
	add_child(_station_system)
	_intake_system = auto_free(IntakeSystem.new())
	add_child(_intake_system)


func after_test() -> void:
	Clock.running = false
	# 심사 카드가 열리면 Clock 이 hold 되는데(autoload), 다음 스위트의 메인 씬에서 플레이어가 멈춘다 — 반드시 풀어 준다
	Clock.release(Clock.HOLD_INTAKE)
	Clock.release(Clock.HOLD_DIALOGUE)
	GameState.pending_visitor = {}


func test_market_opens_on_high_yin_or_night_and_trades() -> void:
	GameState.yin = 0
	Clock.restore(Clock.timeline.seconds_for_band(Clock.Band.DAY))
	assert_bool(_market_system.is_open_now()).is_false()
	GameState.yin = 2
	assert_bool(_market_system.is_open_now()).is_true()
	GameState.yin = 0
	Clock.restore(Clock.timeline.seconds_for_band(Clock.Band.NIGHT))
	assert_bool(_market_system.is_open_now()).is_true()

	# 사기: 배추 씨앗 재고 3, 구매가 = base 4 × 2.0 × 흔들림(±20%) → 6~10
	GameState.money = 100
	var price := _market_system.buy_price("seed_cabbage")
	assert_int(price).is_between(6, 10)
	assert_int(_market_system.stock_left("seed_cabbage")).is_equal(3)
	assert_int(_market_system.buy("seed_cabbage")).is_equal(price)
	assert_int(GameState.money).is_equal(100 - price)
	assert_int(GameState.inventory.get_count("seed_cabbage")).is_equal(1)
	assert_int(_market_system.stock_left("seed_cabbage")).is_equal(2)
	_market_system.buy("seed_cabbage")
	_market_system.buy("seed_cabbage")
	assert_int(_market_system.buy("seed_cabbage")).is_equal(0)  # 재고 소진
	assert_int(GameState.inventory.get_count("seed_cabbage")).is_equal(3)
	GameState.money = 1
	assert_int(_market_system.buy("seed_moon_melon")).is_equal(0)  # 돈 부족
	# 다음 날 재고가 돌아온다
	GameState.advance_day()
	assert_int(_market_system.stock_left("seed_cabbage")).is_equal(3)

	# 팔기: 그늘이끼는 대문간(base 20)보다 비싸다 (×1.8, ±30% → 25~47)
	GameState.inventory.add("m_shadow_moss", 2)
	var sell := _market_system.sell_price("m_shadow_moss")
	assert_int(sell).is_greater(_market_system.gate_price("m_shadow_moss"))
	var money := GameState.money
	assert_int(_market_system.sell("m_shadow_moss", 2)).is_equal(sell * 2)
	assert_int(GameState.money).is_equal(money + sell * 2)
	assert_int(GameState.inventory.get_count("m_shadow_moss")).is_equal(0)
	assert_int(int(GameState.counters.get("sell", 0))).is_equal(0)  # GoalSystem 이 없으면 카운터는 쌓이지 않는다 (activity_done 만 쏜다)


func test_blessing_grant_limit_and_seed_dish_talisman_effects() -> void:
	GameState.affinity["y01_ttukttagi"] = 1
	GameState.tools["hoe"] = 1
	GameState.inventory.clear()
	GameState.inventory.add("seed_radish", 2)
	GameState.inventory.add("dish_perilla_wrap", 1)
	GameState.inventory.add("t_throw", 1)
	GameState.inventory.add("meal", 1)  # 레시피 없는 음식은 대상이 아니다
	assert_array(_blessing_system.eligible_items()).contains_exactly(["dish_perilla_wrap", "seed_radish", "t_throw"])
	assert_bool(_blessing_system.can_grant_any("y01_ttukttagi")).is_true()
	assert_bool(_blessing_system.can_grant_any("y02_eoduki")).is_false()  # 호감도 0
	# 미리보기: 무 씨앗(이승) +1, 깻잎쌈(힘) 1+1, 투척 부적 2+2
	assert_int(_blessing_system.preview_bonus("y01_ttukttagi", "seed_radish")).is_equal(1)
	assert_int(_blessing_system.preview_bonus("y01_ttukttagi", "dish_perilla_wrap")).is_equal(2)
	assert_int(_blessing_system.preview_bonus("y01_ttukttagi", "t_throw")).is_equal(4)
	assert_int(_blessing_system.preview_notes("y01_ttukttagi", "t_throw").size()).is_equal(1)

	assert_bool(_blessing_system.grant("y01_ttukttagi", "seed_radish")).is_true()
	assert_int(GameState.inventory.get_count("seed_radish")).is_equal(1)
	assert_int(GameState.inventory.get_count("seed_radish@b_ttukttagi")).is_equal(1)
	assert_int(_blessing_system.remaining("y01_ttukttagi")).is_equal(0)
	assert_bool(_blessing_system.grant("y01_ttukttagi", "t_throw")).is_false()  # 하루 한 번
	assert_int(int(GameState.blessing_log["b_ttukttagi"])).is_equal(1)
	GameState.advance_day()
	assert_int(_blessing_system.remaining("y01_ttukttagi")).is_equal(1)
	assert_bool(_blessing_system.grant("y01_ttukttagi", "dish_perilla_wrap")).is_true()
	GameState.advance_day()
	assert_bool(_blessing_system.grant("y01_ttukttagi", "t_throw")).is_true()

	# 씨앗: 가호 붙은 씨앗을 먼저 심고, 칸에 가호가 남아 수확이 +1
	assert_str(_farm_system.seed_item_for(DataRegistry.get_crop("c_radish"))).is_equal("seed_radish@b_ttukttagi")
	assert_bool(_farm_system.act(0)).is_true()  # 괭이질
	assert_bool(_farm_system.act(0)).is_true()  # 파종 (가호 씨앗)
	var plot := GameState.farm.get_plot(0)
	assert_str(plot.blessing_id).is_equal("b_ttukttagi")
	assert_int(GameState.inventory.get_count("seed_radish@b_ttukttagi")).is_equal(0)
	assert_int(GameState.inventory.get_count("seed_radish")).is_equal(1)
	for _i in 3:
		GameState.farm.water(0)
		GameState.farm.advance_day(DataRegistry.crops)
	assert_int(plot.state).is_equal(Farm.PlotState.READY)
	assert_bool(_farm_system.act(0)).is_true()  # 수확: 무 1~2 + 가호 1
	assert_int(GameState.inventory.get_count("radish")).is_between(2, 3)
	assert_str(plot.blessing_id).is_equal("")

	# 요리: 뚝딱이 가호 깻잎쌈(힘 +1)을 뚝딱이에게 → 기본 1 + 가호 1 + 힘 시너지 1 = 3
	assert_bool(_station_system.serve("dish_perilla_wrap@b_ttukttagi", "y01_ttukttagi")).is_true()
	assert_int(int((GameState.buffs["y01_ttukttagi"] as Dictionary)["strength"])).is_equal(3)
	# 부적: 투척 가호 위력 2 + 투척 시너지 2
	assert_int(BlessingSystem.talisman_bonus("b_ttukttagi", DataRegistry.get_talisman("t_throw"))).is_equal(4)
	assert_int(BlessingSystem.talisman_bonus("b_dalgael", DataRegistry.get_talisman("t_throw"))).is_equal(0)  # 0 - 1 → 0
	assert_int(BlessingSystem.seed_bonus("b_dalgael", DataRegistry.get_crop("c_moon_melon"))).is_equal(3)  # 2 + 마계 1
	assert_int(BlessingSystem.seed_bonus("b_ttukttagi", DataRegistry.get_crop("c_moon_melon"))).is_equal(0)  # 1 - 1
	assert_int(BlessingSystem.dish_bonus("b_eoduki", DataRegistry.get_recipe("r_radish_soup"), "y03_dalgael")).is_equal(0)  # 담력 간섭


func test_forced_visitor_flag_becomes_intake_card() -> void:
	GameState.flags[IntakeSystem.FLAG_FORCED_VISITOR] = "g_usanson"  # 우물에서 낚인 손님
	_intake_system.roll_visitor()
	assert_str(str(GameState.pending_visitor.get("species_id"))).is_equal("g_usanson")
	assert_str(str(GameState.pending_visitor.get("kind"))).is_equal("guest")
	assert_bool(GameState.flags.has(IntakeSystem.FLAG_FORCED_VISITOR)).is_false()
	assert_bool(Clock.is_held()).is_true()  # 카드가 열려 시간이 멈춘다
	_intake_system.decide(Intake.Decision.DECLINE)
	assert_bool(Clock.is_held()).is_false()
