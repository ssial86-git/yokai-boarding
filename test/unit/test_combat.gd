class_name TestCombat
extends GdUnitTestSuite
## 자동 전투 계산: 능력치 → 체력·피해·간격, 적 → 스태미너 피해, 미니보스 재도전, 전리품, 스폰 자리.


func _params() -> Combat.Params:
	var params := Combat.Params.new()
	params.companion_hp_base = 20
	params.companion_hp_per_courage = 4
	params.companion_damage_base = 1
	params.companion_attack_interval = 1.0
	params.companion_skill_interval_bonus = 0.1
	params.enemy_hit_stamina_per_attack = 6.0
	params.boss_rematch_multiplier = 1.5
	return params


func _enemy(id: String, tier: String, hp: int, attack: int, drop: String, chance: float) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.id = id
	enemy.tier = tier
	enemy.hp = hp
	enemy.attack = attack
	enemy.drop_material = drop
	enemy.drop_chance = chance
	return enemy


func test_companion_stats() -> void:
	var params := _params()
	assert_int(Combat.companion_hp(3, params)).is_equal(32)
	assert_int(Combat.companion_hp(-99, params)).is_equal(1)
	assert_int(Combat.companion_damage(4, params)).is_equal(5)
	assert_int(Combat.companion_damage(-5, params)).is_equal(1)
	assert_float(Combat.companion_attack_interval(3, params)).is_equal_approx(0.7, 0.0001)
	assert_float(Combat.companion_attack_interval(50, params)).is_equal(0.2)


func test_enemy_damage_hp_and_boss_rematch() -> void:
	var params := _params()
	var hound := _enemy("e_hound", "normal", 12, 2, "m_ember_stone", 0.6)
	var boss := _enemy("e_boss", "boss", 60, 4, "m_shadow_moss", 1.0)
	assert_float(Combat.enemy_stamina_damage(hound, params)).is_equal(12.0)
	assert_int(Combat.enemy_hp(hound, true, params)).is_equal(12)  # 일반 적은 재도전 배율 없음
	assert_int(Combat.enemy_hp(boss, false, params)).is_equal(60)
	assert_int(Combat.enemy_hp(boss, true, params)).is_equal(90)


func test_drop_roll_and_spawn_positions() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var always := _enemy("a", "normal", 1, 1, "m_shadow_moss", 1.0)
	var never := _enemy("b", "normal", 1, 1, "m_ash_grass", 0.0)
	var none := _enemy("c", "normal", 1, 1, "", 1.0)
	assert_str(Combat.roll_drop(always, rng)).is_equal("m_shadow_moss")
	assert_str(Combat.roll_drop(never, rng)).is_equal("")
	assert_str(Combat.roll_drop(none, rng)).is_equal("")
	var sometimes := _enemy("d", "normal", 1, 1, "m_ash_grass", 0.5)
	var hits := 0
	for i in 200:
		if not Combat.roll_drop(sometimes, rng).is_empty():
			hits += 1
	assert_int(hits).is_between(60, 140)
	assert_array(Combat.spawn_positions(1000.0, 4, 0.2, 1.0)).contains_exactly([300.0, 500.0, 700.0, 900.0])
	assert_array(Combat.spawn_positions(1000.0, 0, 0.2, 1.0)).is_empty()
