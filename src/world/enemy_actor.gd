class_name EnemyActor
extends Node2D
## 마계 적 하나의 화면 표현과 최소 AI: 감지 반경 안의 가장 가까운 대상(플레이어·동료)에게 가로로 다가가 간격마다 공격한다.
## 규칙 수치는 EnemyData·Combat.Params. 바닥 높이는 RegionView 가 준 Callable 로 맞춘다. 그림은 코드 자리표시.

signal attacked(target: Node2D, enemy: EnemyActor)
signal defeated(enemy: EnemyActor)

const HP_BAR_WIDTH := 20.0
const BOSS_COLOR := "c9503f"
const NORMAL_COLOR := "7a5c8f"

var spawn_id: String = ""
var enemy: EnemyData
var hp: int = 1
var max_hp: int = 1
## (x: float) -> float 바닥 y
var ground_y: Callable
var facing: int = -1

var _attack_range: float = 16.0
var _attack_interval: float = 1.2
var _cooldown: float = 0.0
var _knockback_px: float = 24.0
var _size: float = 32.0
var _color: Color = Color.PURPLE


func setup(id: String, data: EnemyData, start_hp: int, ground: Callable) -> void:
	spawn_id = id
	enemy = data
	hp = start_hp
	max_hp = start_hp
	ground_y = ground
	name = "Enemy_%s" % id
	var tuning := DataRegistry.tuning
	_attack_range = tuning.get_float("enemy_attack_range_px", _attack_range)
	_attack_interval = tuning.get_float("enemy_attack_interval_seconds", _attack_interval)
	_knockback_px = tuning.get_float("enemy_knockback_px", _knockback_px)
	_size = float(data.sprite_size)
	_color = Color.html(BOSS_COLOR if data.tier == "boss" else NORMAL_COLOR)


func is_alive() -> bool:
	return hp > 0


## targets: 플레이어와 동료들. 가장 가까운 대상이 감지 반경 안이면 쫓고, 사거리 안이면 간격마다 attacked 를 쏜다.
func tick(delta: float, targets: Array[Node2D]) -> void:
	if not is_alive():
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	var target := _nearest(targets)
	if target == null:
		_settle_y()
		return
	var dx := target.global_position.x - global_position.x
	if absf(dx) > _attack_range:
		facing = 1 if dx > 0.0 else -1
		var step := minf(enemy.speed_px * delta, absf(dx) - _attack_range)
		global_position.x += signf(dx) * step
	elif _cooldown <= 0.0:
		_cooldown = _attack_interval
		attacked.emit(target, self)
	_settle_y()
	queue_redraw()


## 맞았다. from_x 반대쪽으로 밀린다. 쓰러졌으면 true 와 함께 defeated 를 쏜다.
func take_damage(amount: int, from_x: float) -> bool:
	if not is_alive():
		return false
	hp = maxi(hp - maxi(amount, 0), 0)
	global_position.x += signf(global_position.x - from_x) * _knockback_px
	_settle_y()
	queue_redraw()
	if hp <= 0:
		defeated.emit(self)
		return true
	return false


func _nearest(targets: Array[Node2D]) -> Node2D:
	var best: Node2D = null
	var best_distance := float(enemy.aggro_radius_px)
	for target in targets:
		if target == null or not is_instance_valid(target):
			continue
		var distance := global_position.distance_to(target.global_position)
		if distance <= best_distance:
			best_distance = distance
			best = target
	return best


func _settle_y() -> void:
	if ground_y.is_valid():
		global_position.y = float(ground_y.call(global_position.x))


func _draw() -> void:
	var body := Rect2(Vector2(-_size * 0.4, -_size), Vector2(_size * 0.8, _size))
	draw_rect(body, _color)
	draw_rect(body, Color(0.1, 0.08, 0.12), false, 1.0)
	# 눈
	var eye_y := -_size * 0.7
	draw_rect(Rect2(Vector2(facing * _size * 0.15 - 1.0, eye_y), Vector2(2.0, 2.0)), Color(1, 0.9, 0.6))
	# 체력 바
	var ratio := float(hp) / float(maxi(max_hp, 1))
	var bar := Rect2(Vector2(-HP_BAR_WIDTH * 0.5, -_size - 6.0), Vector2(HP_BAR_WIDTH, 3.0))
	draw_rect(bar, Color(0.1, 0.08, 0.12))
	draw_rect(Rect2(bar.position, Vector2(HP_BAR_WIDTH * ratio, 3.0)), Color(0.86, 0.45, 0.3))
