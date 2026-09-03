class_name ExpeditionSystem
extends Node
## 탐험지(잿빛 들)의 노드 측 (P1-S4): 구역 진입 시 regions.csv 로 적·미니보스를 놓고 동행(Assignment.PARTY) 요괴를 소환한다.
## 매 프레임 적·동료·투척 부적을 굴리고, 적의 공격은 플레이어 스태미너로 받는다 (체력 없음 — 0 이면 우물로 물러난다).
## 부적 사용(Q 투척 · R 귀환 · G 채집)도 여기서 처리한다. 순수 계산은 Combat.

const KIND_EXPEDITION := "expedition"
const BOSS_SPAWN_ID := "boss"
const FEATURE_BOSS_REMATCH := "boss_rematch"
const TALISMAN_THROW := "t_throw"
const TALISMAN_RETURN := "t_return"
const TALISMAN_GATHER := "t_gather"
const SPRITE_PATH := "res://assets/art_generated/yokai_%s.png"
const HOME_REGION := HouseRegion.REGION_ID
const EXIT_NORMAL := "exit"
const EXIT_RETURN := "return_talisman"
const EXIT_DEFEAT := "defeat"

var region_manager: RegionManager
var unlock_system: UnlockSystem
var gather_system: GatherSystem

var enemies: Array[EnemyActor] = []
var companions: Array[CompanionActor] = []
var projectiles: Array[TalismanProjectile] = []

var _region: RegionData
var _params: Combat.Params
var _throw_cooldown: float = 0.0
var _invulnerable: float = 0.0
var _pending_exit_reason: String = ""


func _ready() -> void:
	_params = Combat.Params.from_tuning(DataRegistry.tuning)
	Events.region_entered.connect(_on_region_entered)
	Events.day_started.connect(func(_day: int) -> void: _respawn_all())


func _process(delta: float) -> void:
	if not is_active() or Clock.is_held():
		return
	tick(delta)


func is_active() -> bool:
	return _region != null


func region_id() -> String:
	return _region.id if _region != null else ""


func alive_enemies() -> int:
	var count := 0
	for enemy in enemies:
		if enemy.is_alive():
			count += 1
	return count


## 적·동료·투척 부적을 seconds 만큼 굴린다 (테스트·디버그도 이 함수를 부른다).
func tick(delta: float) -> void:
	var player := region_manager.player
	_throw_cooldown = maxf(_throw_cooldown - delta, 0.0)
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	var targets: Array[Node2D] = [player]
	for companion in companions:
		targets.append(companion)
	for enemy in enemies.duplicate():
		enemy.tick(delta, targets)
	for companion in companions.duplicate():
		companion.tick(delta, player, enemies)
	for projectile in projectiles.duplicate():
		if projectile.tick(delta, enemies):
			projectiles.erase(projectile)
			projectile.queue_free()


# --- 부적 ---

## Q: 투척 부적. 창고에서 하나 쓰고 바라보는 쪽으로 던진다.
func throw_talisman() -> bool:
	var talisman := DataRegistry.get_talisman(TALISMAN_THROW)
	if talisman == null or not is_active():
		return false
	if _throw_cooldown > 0.0:
		Events.message_posted.emit(DataRegistry.text("msg_talisman_cooldown"))
		return false
	if not _consume(talisman):
		return false
	var player := region_manager.player
	var projectile := TalismanProjectile.new()
	projectile.setup(player.global_position + Vector2(float(player.facing) * 14.0, -12.0), player.facing, talisman)
	projectile.hit.connect(func(enemy: EnemyActor, damage: int) -> void:
		Metrics.record("combat_hit", {"enemy": enemy.enemy.id, "source": "talisman", "damage": damage}))
	region_manager.current_view().add_child(projectile)
	projectiles.append(projectile)
	_throw_cooldown = talisman.cooldown_seconds
	Events.message_posted.emit(DataRegistry.text("msg_talisman_thrown"))
	return true


## R: 귀환 부적. 어디서든 집으로.
func use_return_talisman() -> bool:
	var talisman := DataRegistry.get_talisman(TALISMAN_RETURN)
	if talisman == null or not _consume(talisman):
		return false
	_pending_exit_reason = EXIT_RETURN
	Events.message_posted.emit(DataRegistry.text("msg_return_home"))
	region_manager.travel(HOME_REGION)
	return true


## G: 채집 부적. 잠시 채집량이 는다.
func use_gather_talisman() -> bool:
	var talisman := DataRegistry.get_talisman(TALISMAN_GATHER)
	if talisman == null or gather_system == null or not _consume(talisman):
		return false
	var seconds := DataRegistry.tuning.get_float("gather_talisman_duration_seconds", 60.0)
	gather_system.apply_bonus(talisman.power, seconds)
	Events.message_posted.emit(DataRegistry.text("msg_gather_buff", {"seconds": roundi(seconds), "bonus": talisman.power}))
	return true


func _consume(talisman: TalismanData) -> bool:
	if not GameState.inventory.remove(talisman.id, 1):
		Events.message_posted.emit(DataRegistry.text("msg_talisman_none", {"name": talisman.name_ko}))
		return false
	Events.item_removed.emit(talisman.id, 1)
	Metrics.record("talisman_used", {"talisman": talisman.id})
	return true


# --- 구역 진입·이탈 ---

func _on_region_entered(new_region_id: String) -> void:
	if is_active() and new_region_id != _region.id:
		Metrics.record("explore_exit", {"region": _region.id, "reason": _pending_exit_reason if not _pending_exit_reason.is_empty() else EXIT_NORMAL})
	_pending_exit_reason = ""
	_clear()
	var region := DataRegistry.get_region(new_region_id)
	if region == null or region.kind != KIND_EXPEDITION:
		_region = null
		return
	_region = region
	_spawn_enemies()
	_spawn_companions()
	if companions.is_empty():
		Events.message_posted.emit(DataRegistry.text("msg_expedition_alone"))
	else:
		Events.message_posted.emit(DataRegistry.text("msg_expedition_enter", {"name": region.name_ko, "count": companions.size()}))
	Events.message_posted.emit(DataRegistry.text("msg_expedition_controls"))


func _clear() -> void:
	enemies.clear()
	companions.clear()
	projectiles.clear()  # 액터 노드는 구역 뷰의 자식이라 뷰와 함께 사라진다


## 하루가 바뀌면 오늘 처치한 적 기록을 비운다 (일일 리스폰). 미니보스 처치 기록(boss_defeated)은 남는다.
func _respawn_all() -> void:
	for region: RegionData in DataRegistry.regions.values():
		if region.kind == KIND_EXPEDITION and GameState.region_states.has(region.id):
			GameState.region_state(region.id)["enemies_defeated"] = []


func _spawn_enemies() -> void:
	var view := region_manager.current_view() as RegionView
	if view == null:
		return
	var state := GameState.region_state(_region.id)
	var defeated: Array = state["enemies_defeated"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%s:enemies" % [GameState.rng.seed, GameState.day, _region.id])
	var tuning := DataRegistry.tuning
	var positions := Combat.spawn_positions(float(_region.width_px), _region.enemy_count,
		tuning.get_float("enemy_spawn_x_from", 0.35), tuning.get_float("enemy_spawn_x_to", 0.95))
	for k in positions.size():
		if _region.enemy_pool.is_empty():
			break
		var enemy_id := str(_region.enemy_pool[rng.randi_range(0, _region.enemy_pool.size() - 1)])
		var spawn_id := "%s_%d" % [enemy_id, k]
		if defeated.has(spawn_id):
			continue
		var data := DataRegistry.get_enemy(enemy_id)
		if data != null:
			_add_enemy(view, spawn_id, data, Combat.enemy_hp(data, false, _params), positions[k])
	if _region.boss_id.is_empty() or defeated.has(BOSS_SPAWN_ID):
		return
	var boss := DataRegistry.get_enemy(_region.boss_id)
	if boss == null:
		return
	var rematch_open := unlock_system == null or unlock_system.is_feature_open(FEATURE_BOSS_REMATCH)
	var beaten := bool(state["boss_defeated"])
	if beaten and not rematch_open:
		return
	_add_enemy(view, BOSS_SPAWN_ID, boss, Combat.enemy_hp(boss, beaten, _params),
		float(_region.width_px) * tuning.get_float("boss_spawn_x", 0.85))
	if beaten:
		Events.message_posted.emit(DataRegistry.text("msg_boss_rematch", {"name": boss.name_ko}))


func _add_enemy(view: RegionView, spawn_id: String, data: EnemyData, hp: int, x: float) -> void:
	var actor := EnemyActor.new()
	actor.setup(spawn_id, data, hp, view.ground_y_at)
	actor.global_position = Vector2(x, view.ground_y_at(x))
	actor.attacked.connect(_on_enemy_attacked)
	actor.defeated.connect(_on_enemy_defeated)
	view.add_child(actor)
	enemies.append(actor)


func _spawn_companions() -> void:
	var view := region_manager.current_view() as RegionView
	var player := region_manager.player
	if view == null or player == null:
		return
	var index := 0
	for yokai_id in GameState.assignment.workers_at(Assignment.PARTY):
		if not GameState.residents.has(yokai_id):
			continue
		var actor := CompanionActor.new()
		var path := SPRITE_PATH % yokai_id
		var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
		actor.setup(yokai_id, texture,
			Combat.companion_hp(GameState.stat_of(yokai_id, "courage"), _params),
			Combat.companion_damage(GameState.stat_of(yokai_id, "strength"), _params),
			Combat.companion_attack_interval(GameState.stat_of(yokai_id, "skill"), _params),
			index, view.ground_y_at)
		actor.global_position = player.global_position - Vector2(float(player.facing) * 24.0 * float(index + 1), 0.0)
		actor.hit.connect(func(enemy: EnemyActor, damage: int) -> void:
			Metrics.record("combat_hit", {"enemy": enemy.enemy.id, "source": "companion", "damage": damage}))
		actor.downed.connect(_on_companion_downed)
		view.add_child(actor)
		companions.append(actor)
		index += 1


func _on_enemy_attacked(target: Node2D, enemy: EnemyActor) -> void:
	if target is CompanionActor:
		(target as CompanionActor).take_damage(enemy.enemy.attack)
		return
	if not target is PlayerController or _invulnerable > 0.0:
		return
	var player := target as PlayerController
	var damage := Combat.enemy_stamina_damage(enemy.enemy, _params)
	GameState.stamina.spend(damage)
	player.global_position.x += signf(player.global_position.x - enemy.global_position.x) \
		* DataRegistry.tuning.get_float("enemy_knockback_px", 24.0)
	_invulnerable = DataRegistry.tuning.get_float("player_hurt_invulnerable_seconds", 0.6)
	Events.message_posted.emit(DataRegistry.text("msg_player_hit", {"name": enemy.enemy.name_ko, "amount": roundi(damage)}))
	if GameState.stamina.is_exhausted():
		_retreat()


func _on_enemy_defeated(enemy: EnemyActor) -> void:
	var state := GameState.region_state(_region.id)
	(state["enemies_defeated"] as Array).append(enemy.spawn_id)
	Events.message_posted.emit(DataRegistry.text("msg_enemy_defeated", {"name": enemy.enemy.name_ko}))
	if enemy.spawn_id == BOSS_SPAWN_ID:
		state["boss_defeated"] = true
		Events.message_posted.emit(DataRegistry.text("msg_boss_defeated", {"name": enemy.enemy.name_ko}))
	var drop := Combat.roll_drop(enemy.enemy, GameState.rng)
	if not drop.is_empty():
		GameState.inventory.add(drop, 1)
		Events.item_added.emit(drop, 1)
		Events.message_posted.emit(DataRegistry.text("msg_loot", {"name": DataRegistry.item_name(drop)}))
	Metrics.record("enemy_defeated", {"enemy": enemy.enemy.id, "region": _region.id})
	enemies.erase(enemy)
	enemy.queue_free()


func _on_companion_downed(actor: CompanionActor) -> void:
	Events.message_posted.emit(DataRegistry.text("msg_companion_down", {"name": DataRegistry.yokai_name(actor.yokai_id)}))
	companions.erase(actor)
	actor.queue_free()


## 스태미너 0: 우물로 물러난다 (강제 기절 없음 — 벌은 자리 이동뿐).
func _retreat() -> void:
	_pending_exit_reason = EXIT_DEFEAT
	Events.message_posted.emit(DataRegistry.text("msg_retreat_exhausted"))
	region_manager.travel(DataRegistry.tuning.get_string("expedition_retreat_region", "r_well"))
