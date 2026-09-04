class_name CompanionActor
extends Node2D
## 동료 요괴의 탐험 표현과 최소 AI (docs/01 v3 6절): 플레이어 반경 안의 가장 가까운 적과 자동 교전, 적이 없으면 플레이어 뒤로 복귀.
## 피해·체력·간격은 Combat 계산(능력치 + 배식 버프). 쓰러지면 downed 를 쏘고 이번 탐험에서 빠진다.

signal hit(enemy: EnemyActor, damage: int)
signal downed(actor: CompanionActor)

const HP_BAR_WIDTH := 20.0

var yokai_id: String = ""
var hp: int = 1
var max_hp: int = 1
var damage: int = 1
var attack_interval: float = 1.0
## 플레이어 뒤에 서는 순번 (0, 1, …)
var slot_index: int = 0
## (x: float) -> float 바닥 y
var ground_y: Callable

var _sprite: AnimatedSprite2D
var _speed: float = 90.0
var _leash: float = 140.0
var _attack_range: float = 18.0
var _follow_offset: float = 24.0
var _cooldown: float = 0.0
var _size: float = 32.0


func setup(id: String, start_hp: int, attack_damage: int, interval: float, index: int, ground: Callable) -> void:
	yokai_id = id
	name = "Companion_%s" % id
	hp = start_hp
	max_hp = start_hp
	damage = attack_damage
	attack_interval = interval
	slot_index = index
	ground_y = ground
	var tuning := DataRegistry.tuning
	_speed = tuning.get_float("companion_speed_px", _speed)
	_leash = tuning.get_float("companion_leash_px", _leash)
	_attack_range = tuning.get_float("companion_attack_range_px", _attack_range)
	_follow_offset = tuning.get_float("companion_follow_offset_px", _follow_offset)
	# 아트 매니페스트 char.<yokai_id> — 집 안 액터와 같은 시트를 쓴다 (없으면 자리표시 폴백)
	var art_key := "char.%s" % id
	_sprite = ArtLibrary.make_sprite(art_key)
	if _sprite != null:
		_size = float(ArtLibrary.frame_size(art_key).y)
		add_child(_sprite)


func is_alive() -> bool:
	return hp > 0


## 플레이어 반경(leash) 안의 가장 가까운 살아 있는 적을 친다. 없으면 플레이어 뒤 자리로.
func tick(delta: float, player: Node2D, enemies: Array[EnemyActor]) -> void:
	if not is_alive() or player == null:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	var target := _nearest_enemy(player, enemies)
	var goal_x: float
	if target != null:
		var dx := target.global_position.x - global_position.x
		if absf(dx) <= _attack_range:
			if _cooldown <= 0.0:
				_cooldown = attack_interval
				target.take_damage(damage, global_position.x)
				hit.emit(target, damage)
			goal_x = global_position.x
		else:
			goal_x = target.global_position.x - signf(dx) * _attack_range * 0.8
	else:
		var player_facing := 1
		if player.get("facing") != null:
			player_facing = int(player.get("facing"))
		goal_x = player.global_position.x - float(player_facing) * _follow_offset * float(slot_index + 1)
	var step := _speed * delta
	var to_goal := goal_x - global_position.x
	if absf(to_goal) > 1.0:
		global_position.x += signf(to_goal) * minf(step, absf(to_goal))
		if _sprite != null:
			_sprite.flip_h = to_goal < 0.0
			ArtLibrary.play(_sprite, ArtLibrary.ANIM_WALK)
	elif _sprite != null:
		ArtLibrary.play(_sprite, ArtLibrary.ANIM_IDLE)
	if ground_y.is_valid():
		global_position.y = float(ground_y.call(global_position.x))
	queue_redraw()


## 맞았다. 쓰러졌으면 downed 를 쏘고 true.
func take_damage(amount: int) -> bool:
	if not is_alive():
		return false
	hp = maxi(hp - maxi(amount, 0), 0)
	queue_redraw()
	if hp <= 0:
		downed.emit(self)
		return true
	return false


func _nearest_enemy(player: Node2D, enemies: Array[EnemyActor]) -> EnemyActor:
	var best: EnemyActor = null
	var best_distance := INF
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		if enemy.global_position.distance_to(player.global_position) > _leash:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func _draw() -> void:
	var ratio := float(hp) / float(maxi(max_hp, 1))
	var bar := Rect2(Vector2(-HP_BAR_WIDTH * 0.5, -_size - 6.0), Vector2(HP_BAR_WIDTH, 3.0))
	draw_rect(bar, Color(0.1, 0.08, 0.12))
	draw_rect(Rect2(bar.position, Vector2(HP_BAR_WIDTH * ratio, 3.0)), Color(0.5, 0.7, 0.65))
