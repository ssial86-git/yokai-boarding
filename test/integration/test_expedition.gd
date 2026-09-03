class_name TestExpedition
extends GdUnitTestSuite
## P1-S4: 잿빛 들 — regions.csv 로 적 4·미니보스 배치, 동행 2명 자동 교전, 전리품·일일 리스폰·보스 재도전,
## 부적 Q(투척)/R(귀환)/G(채집), 스태미너 0 이면 우물로 후퇴를 메인 씬에서 확인한다.

const MAIN_SCENE := "res://scenes/main.tscn"
const SEED := 20260903


func _drain(story: StorySystem, intake: IntakeSystem) -> void:
	for i in 100:
		if story.is_busy():
			var node := story.current_node()
			if node != null and node.has_options():
				story.choose(0)
			else:
				story.advance()
		elif intake.has_pending():
			intake.decide(Intake.Decision.DECLINE)
		else:
			return


func _open_ash_field() -> void:
	for unlock_id in ["u_well", "u_ash_field", "u_ash_field_deep", "u_party"]:
		GameState.unlocked[unlock_id] = GameState.day


func _run_until(expedition: ExpeditionSystem, max_ticks: int, done: Callable) -> int:
	var ticks := 0
	while ticks < max_ticks and not bool(done.call()):
		expedition.tick(0.1)
		ticks += 1
	return ticks


func test_party_fights_loots_and_boss_rematch() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var region_manager: RegionManager = main.get("region_manager")
	var expedition: ExpeditionSystem = main.get("expedition_system")
	var assign: AssignmentController = main.get("assignment_controller")
	var story: StorySystem = main.get("story_system")
	var intake: IntakeSystem = main.get("intake_system")
	var player: PlayerController = main.get("player")
	_drain(story, intake)
	GameState.rng.seed = SEED
	_open_ash_field()

	# 동행 편성은 아침 배치, 정원 2
	GameState.add_resident("y03_dalgael")
	assert_int(assign.try_assign("y01_ttukttagi", Assignment.PARTY)).is_equal(AssignmentController.Outcome.OK)
	assert_int(assign.try_assign("y02_eoduki", Assignment.PARTY)).is_equal(AssignmentController.Outcome.OK)
	assert_int(assign.try_assign("y03_dalgael", Assignment.PARTY)).is_equal(AssignmentController.Outcome.FULL)

	var stamina_before := GameState.stamina.value
	var enters_before := Metrics.count("explore_enter")
	var exits_before := Metrics.count("explore_exit")
	assert_bool(region_manager.travel("r_well")).is_true()
	assert_bool(region_manager.travel("r_ash_field")).is_true()
	var region := DataRegistry.get_region("r_ash_field")
	# 진입 비용은 즉시 빠진다 (프레임이 흐르면 회복이 섞이므로 그 전에 본다)
	assert_float(GameState.stamina.value).is_equal_approx(stamina_before - region.stamina_enter_cost, 0.001)
	await runner.simulate_frames(2)
	assert_bool(expedition.is_active()).is_true()
	assert_int(expedition.enemies.size()).is_equal(region.enemy_count)
	assert_int(expedition.companions.size()).is_equal(2)
	assert_int(Metrics.count("explore_enter")).is_equal(enters_before + 1)

	# 플레이어가 적 곁으로 가면 동료가 알아서 싸운다
	var first := expedition.enemies[0]
	player.global_position = first.global_position + Vector2(-40.0, 0.0)
	var state := GameState.region_state("r_ash_field")
	_run_until(expedition, 1200, func() -> bool: return (state["enemies_defeated"] as Array).size() >= 1)
	assert_int((state["enemies_defeated"] as Array).size()).is_greater_equal(1)
	assert_int(Metrics.count("combat_hit")).is_greater(0)
	assert_int(Metrics.count("enemy_defeated")).is_greater_equal(1)
	# 나머지도 처치 (전리품 → 제작·요리 사슬 재료)
	for enemy in expedition.enemies.duplicate():
		player.global_position = enemy.global_position + Vector2(-40.0, 0.0)
		_run_until(expedition, 1200, func() -> bool: return not is_instance_valid(enemy) or not enemy.is_alive())
	var defeated_today := (state["enemies_defeated"] as Array).size()
	assert_int(defeated_today).is_equal(region.enemy_count)
	assert_int(GameState.inventory.get_count("m_ash_grass") + GameState.inventory.get_count("m_ember_stone")).is_greater(0)

	# 같은 날 다시 들어오면 처치한 적은 없다
	assert_bool(region_manager.travel("r_well")).is_true()
	assert_int(Metrics.count("explore_exit")).is_equal(exits_before + 1)
	assert_bool(region_manager.travel("r_ash_field")).is_true()
	await runner.simulate_frames(1)
	assert_int(expedition.enemies.size()).is_equal(0)

	# 심부의 미니보스: 처치하면 boss_defeated, 전리품 그늘이끼(확률 1.0)
	assert_bool(region_manager.travel("r_ash_field_deep")).is_true()
	await runner.simulate_frames(1)
	var boss: EnemyActor = null
	for enemy in expedition.enemies:
		if enemy.spawn_id == ExpeditionSystem.BOSS_SPAWN_ID:
			boss = enemy
	assert_object(boss).is_not_null()
	assert_int(boss.max_hp).is_equal(DataRegistry.get_enemy("e_ash_warden").hp)
	var moss_before := GameState.inventory.get_count("m_shadow_moss")
	boss.take_damage(boss.hp, boss.global_position.x - 10.0)
	assert_bool(GameState.region_state("r_ash_field_deep")["boss_defeated"]).is_true()
	assert_int(GameState.inventory.get_count("m_shadow_moss")).is_equal(moss_before + 1)

	# 재도전이 안 열렸으면 보스는 다시 나오지 않고, 열리면 다음 날 더 강해져 나온다
	assert_bool(region_manager.travel("r_well")).is_true()
	Clock.sleep()
	_drain(story, intake)
	assert_bool(region_manager.travel("r_ash_field_deep")).is_true()
	await runner.simulate_frames(1)
	var has_boss := false
	for enemy in expedition.enemies:
		has_boss = has_boss or enemy.spawn_id == ExpeditionSystem.BOSS_SPAWN_ID
	assert_bool(has_boss).is_false()
	GameState.unlocked["u_warden_rematch"] = GameState.day
	assert_bool(region_manager.travel("r_well")).is_true()
	assert_bool(region_manager.travel("r_ash_field_deep")).is_true()
	await runner.simulate_frames(1)
	var rematch: EnemyActor = null
	for enemy in expedition.enemies:
		if enemy.spawn_id == ExpeditionSystem.BOSS_SPAWN_ID:
			rematch = enemy
	assert_object(rematch).is_not_null()
	var multiplier := DataRegistry.tuning.get_float("boss_rematch_multiplier")
	assert_int(rematch.max_hp).is_equal(int(ceil(DataRegistry.get_enemy("e_ash_warden").hp * multiplier)))
	assert_bool(region_manager.travel("r_house")).is_true()


func test_talismans_and_exhaustion_retreat() -> void:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(1)
	var main: Node = runner.scene()
	var region_manager: RegionManager = main.get("region_manager")
	var expedition: ExpeditionSystem = main.get("expedition_system")
	var gather_system: GatherSystem = main.get("gather_system")
	var player: PlayerController = main.get("player")
	_drain(main.get("story_system"), main.get("intake_system"))
	GameState.rng.seed = SEED
	_open_ash_field()
	# Metrics 는 세션 누적이므로 이 테스트 안의 증가량으로 본다
	var exits_before := Metrics.count("explore_exit")
	var talismans_before := Metrics.count("talisman_used")
	assert_bool(region_manager.travel("r_ash_field")).is_true()  # 동행 없이
	await runner.simulate_frames(1)
	assert_int(expedition.companions.size()).is_equal(0)

	# Q 투척: 부적이 없으면 실패, 있으면 날아가 적을 맞힌다. 쿨다운 뒤에야 다시
	assert_bool(expedition.throw_talisman()).is_false()
	GameState.inventory.add("t_throw", 2)
	var target := expedition.enemies[0]
	player.global_position = target.global_position + Vector2(-40.0, 0.0)
	player.facing = 1
	var hp_before := target.hp
	assert_bool(expedition.throw_talisman()).is_true()
	assert_int(expedition.projectiles.size()).is_equal(1)
	_run_until(expedition, 100, func() -> bool: return expedition.projectiles.is_empty())
	assert_int(target.hp).is_equal(hp_before - DataRegistry.get_talisman("t_throw").power)
	assert_bool(expedition.throw_talisman()).is_false()  # 쿨다운
	expedition.tick(DataRegistry.get_talisman("t_throw").cooldown_seconds + 0.1)
	player.global_position = Vector2(60.0, 0.0)  # 적에게 맞지 않게 떨어져서
	assert_bool(expedition.throw_talisman()).is_true()
	assert_int(GameState.inventory.get_count("t_throw")).is_equal(0)
	assert_int(Metrics.count("talisman_used")).is_equal(talismans_before + 2)

	# G 채집 부적: 채집량 보너스
	GameState.inventory.add("t_gather", 1)
	assert_bool(expedition.use_gather_talisman()).is_true()
	assert_bool(gather_system.bonus_active()).is_true()

	# R 귀환 부적: 집으로
	assert_bool(expedition.use_return_talisman()).is_false()  # 없음
	GameState.inventory.add("t_return", 1)
	assert_bool(expedition.use_return_talisman()).is_true()
	assert_str(GameState.player_region).is_equal(HouseRegion.REGION_ID)
	assert_bool(expedition.is_active()).is_false()
	assert_int(Metrics.count("explore_exit")).is_equal(exits_before + 1)

	# 스태미너 0 → 우물로 후퇴 (강제 기절 없음)
	assert_bool(region_manager.travel("r_ash_field")).is_true()
	await runner.simulate_frames(1)
	GameState.stamina.value = 1.0
	var enemy := expedition.enemies[0]
	player.global_position = enemy.global_position + Vector2(8.0, 0.0)
	_run_until(expedition, 50, func() -> bool: return GameState.player_region != "r_ash_field")
	assert_str(GameState.player_region).is_equal(DataRegistry.tuning.get_string("expedition_retreat_region"))
	assert_bool(GameState.stamina.is_exhausted()).is_true()
	assert_int(Metrics.count("explore_exit")).is_equal(exits_before + 2)
