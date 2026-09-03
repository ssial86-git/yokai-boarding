class_name TalismanProjectile
extends Node2D
## 투척 부적 (docs/01 v3 2.1: 플레이어의 유일한 공격 개입). 던진 방향으로 날아가 첫 적을 맞히고 사라진다.
## 피해·사거리는 TalismanData(power/range_px), 속도·명중 반경은 tuning. 그림은 코드 자리표시.

signal hit(enemy: EnemyActor, damage: int)

var direction: int = 1
var damage: int = 1
var range_px: float = 96.0
var speed: float = 220.0
var hit_radius: float = 12.0

var _travelled: float = 0.0


func setup(from: Vector2, facing: int, talisman: TalismanData) -> void:
	global_position = from
	direction = 1 if facing >= 0 else -1
	damage = talisman.power
	range_px = float(talisman.range_px)
	var tuning := DataRegistry.tuning
	speed = tuning.get_float("talisman_throw_speed_px", speed)
	hit_radius = tuning.get_float("talisman_hit_radius_px", hit_radius)
	name = "Talisman"
	# 구역 뷰의 자식이라 플레이어보다 뒤에 그려지므로 절대 z 로 앞에 띄운다 — 던진 것이 보여야 개입감이 산다
	z_as_relative = false
	z_index = 5


## 날아간다. 맞혔거나 사거리를 다 갔으면 true (호출자가 지운다).
func tick(delta: float, enemies: Array[EnemyActor]) -> bool:
	var step := speed * delta
	global_position.x += float(direction) * step
	_travelled += step
	queue_redraw()
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var enemy_center := enemy.global_position + Vector2(0, -float(enemy.enemy.sprite_size) * 0.5)
		if global_position.distance_to(enemy_center) <= hit_radius + float(enemy.enemy.sprite_size) * 0.4:
			enemy.take_damage(damage, global_position.x - float(direction) * 8.0)
			hit.emit(enemy, damage)
			return true
	return _travelled >= range_px


func _draw() -> void:
	var color := Color.html("f2a65a")
	draw_colored_polygon(PackedVector2Array([Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)]), color)
	draw_line(Vector2(-float(direction) * 10.0, 0), Vector2(-float(direction) * 4.0, 0), Color(color, 0.5), 1.0)
